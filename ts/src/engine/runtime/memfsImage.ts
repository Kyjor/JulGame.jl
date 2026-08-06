/** Lazy-fetch UI images into Emscripten MEMFS (runtime-created paths miss scene preload). */

type EmFs = {
    mkdirTree: (p: string) => void;
    writeFile: (p: string, d: Uint8Array) => void;
    analyzePath?: (p: string) => { exists: boolean };
};

const pending = new Set<string>();
const failed = new Set<string>();

const retryWhenReady = new Set<string>();

function getFs(): EmFs | null {
    const jg = (globalThis as { JulGame?: { emscriptenModule?: { FS?: EmFs } } }).JulGame;
    return (
        jg?.emscriptenModule?.FS ??
        (globalThis as { Module?: { FS?: EmFs } }).Module?.FS ??
        null
    );
}

function assetFetchUrl(relPath: string): string | null {
    const base = memfsBaseUrl();
    if (!base) {
        return null;
    }
    return new URL(`assets/images/${relPath}`, base.endsWith("/") ? base : `${base}/`).href;
}

function memfsBaseUrl(): string {
    return String(
        (globalThis as { JulGame?: { memfsAssetBaseUrl?: string } }).JulGame?.memfsAssetBaseUrl ?? "",
    ).replace(/\/$/, "");
}

function writeMemfsFile(fs: EmFs, memPath: string, data: Uint8Array): void {
    const slash = memPath.lastIndexOf("/");
    if (slash > 0) {
        fs.mkdirTree(memPath.slice(0, slash));
    }
    fs.writeFile(memPath, data);
}

export function memfsImagePath(relPath: string): string {
    return `/game/assets/images/${relPath}`;
}

export function memfsImageExists(relPath: string): boolean {
    const fs = getFs();
    if (!fs?.analyzePath) {
        return false;
    }
    try {
        return fs.analyzePath(memfsImagePath(relPath)).exists;
    } catch {
        return false;
    }
}

/** Retry paths that were requested before MEMFS / base URL were ready. */
export function flushPendingImageFetches(): void {
    if (retryWhenReady.size === 0) {
        return;
    }
    for (const relPath of [...retryWhenReady]) {
        retryWhenReady.delete(relPath);
        scheduleImageFetch(relPath);
    }
}

/** Fetch `assets/images/<rel>` into MEMFS; no-op if already present or in flight. */
export function scheduleImageFetch(relPath: string): void {
    if (!relPath || pending.has(relPath) || failed.has(relPath) || memfsImageExists(relPath)) {
        return;
    }
    const fs = getFs();
    const url = assetFetchUrl(relPath);
    if (!fs || !url) {
        retryWhenReady.add(relPath);
        return;
    }
    pending.add(relPath);
    void (async () => {
        try {
            let res = await fetch(url);
            if (!res.ok && /\.png$/i.test(relPath)) {
                const jpgUrl = assetFetchUrl(relPath.replace(/\.png$/i, ".jpg"));
                if (jpgUrl) {
                    res = await fetch(jpgUrl);
                }
            }
            if (!res.ok) {
                throw new Error(String(res.status));
            }
            const data = new Uint8Array(await res.arrayBuffer());
            writeMemfsFile(fs, memfsImagePath(relPath), data);
            const api = (globalThis as { JulGameSdl?: { glue_SDL_DestroyTexture?: (t: number) => void } })
                .JulGameSdl;
            if (api) {
                void import("./textureCache").then(({ invalidateTextureCachesForImagePath }) => {
                    invalidateTextureCachesForImagePath(relPath, api as never);
                });
            }
        } catch {
            failed.add(relPath);
            console.warn(`memfsImage: missing ${url}`);
        } finally {
            pending.delete(relPath);
        }
    })();
}
