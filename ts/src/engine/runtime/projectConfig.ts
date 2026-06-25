/** Parsed key/value pairs from a JulGame `config.julgame` file. */
export function parseJulgameConfig(text: string): Record<string, string> {
    const out: Record<string, string> = {};
    for (const line of text.split("\n")) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith("#")) {
            continue;
        }
        const eq = trimmed.indexOf("=");
        if (eq <= 0) {
            continue;
        }
        out[trimmed.slice(0, eq).trim()] = trimmed.slice(eq + 1).trim();
    }
    return out;
}

export type JulgameProjectConfig = {
    /** Default sprite pixels-per-unit when scene JSON uses `-1` or omits the field. */
    pixelsPerUnit: number;
};

const DEFAULT_PPU = 16;

/** Load `config.julgame` from the served project root (same file Julia `parse_config` reads). */
export async function loadProjectConfig(pageRoot: URL): Promise<JulgameProjectConfig> {
    try {
        const res = await fetch(new URL("config.julgame", pageRoot));
        if (!res.ok) {
            return { pixelsPerUnit: DEFAULT_PPU };
        }
        const map = parseJulgameConfig(await res.text());
        const raw = map.PixelsPerUnit ?? map.pixelsPerUnit ?? String(DEFAULT_PPU);
        const ppu = parseInt(raw, 10);
        return { pixelsPerUnit: Number.isFinite(ppu) && ppu > 0 ? ppu : DEFAULT_PPU };
    } catch {
        return { pixelsPerUnit: DEFAULT_PPU };
    }
}

/** Resolve scene sprite PPU: `0` = true pixel size, `>0` = explicit, else project default. */
export function resolveSpritePixelsPerUnit(
    raw: number | undefined,
    projectDefault = DEFAULT_PPU,
): number {
    if (raw === 0) {
        return 0;
    }
    if (typeof raw === "number" && raw > 0) {
        return raw;
    }
    return projectDefault;
}

/** Normalize Julia-style paths (`FiraCode//ttf//foo.ttf`) for HTTP/MEMFS. */
export function normalizeAssetPath(path: string): string {
    return path.replace(/\\/g, "/").replace(/\/+/g, "/");
}

export function commaSeparatedAssetPath(path: string): string {
    return normalizeAssetPath(path)
        .split("/")
        .filter(Boolean)
        .join(",");
}
