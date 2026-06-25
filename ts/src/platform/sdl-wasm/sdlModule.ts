export type EmscriptenFactory = (opts?: Record<string, unknown>) => Promise<Record<string, unknown>>;

/**
 * Load Emscripten MODULARIZE output co-located with this module (see wasm-src/build.sh).
 * Must live under src/ so Vite can resolve it — files in /public cannot be import()'d from TS.
 */
export async function loadSDLModule(
    canvas: HTMLCanvasElement,
    print: (text: string) => void,
    printErr: (text: string) => void,
): Promise<Record<string, unknown>> {
    const entryUrl = new URL("./julgame.js", import.meta.url).href;
    const factoryModule = (await import(/* @vite-ignore */ entryUrl)) as { default?: EmscriptenFactory };
    const factory = (factoryModule.default ?? factoryModule) as EmscriptenFactory;
    return factory({
        canvas,
        locateFile: (path: string) => new URL(path, import.meta.url).href,
        print,
        printErr,
    });
}
