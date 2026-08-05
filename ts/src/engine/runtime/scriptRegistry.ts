/** Transpiled game scripts register here; bootstrap dispatches initialize/update by name. */

export type ScriptHooks = {
    create: () => unknown;
    initialize?: (script: unknown, ...args: unknown[]) => void;
    update?: (script: unknown, deltaTime: number) => void;
    onShutdown?: (script: unknown) => void;
};

const registry = new Map<string, ScriptHooks>();
const scriptSoundPaths = new Set<string>();
const SCRIPT_NAME_KEY = "__julgameScriptName";
/** Survives Vite minify: `new Piece()` still resolves to registry name "Piece". */
const constructorToName = new WeakMap<object, string>();

function getScriptName(script: unknown): string {
    if (script && typeof script === "object" && SCRIPT_NAME_KEY in script) {
        return (script as Record<string, string>)[SCRIPT_NAME_KEY];
    }
    const ctor = (script as { constructor?: object })?.constructor;
    if (ctor && constructorToName.has(ctor)) {
        return constructorToName.get(ctor)!;
    }
    return (ctor as { name?: string } | undefined)?.name ?? "";
}

export function registerScript(name: string, hooks: ScriptHooks): void {
    registry.set(name, hooks);
    try {
        const probe = hooks.create();
        const ctor = (probe as { constructor?: object } | null)?.constructor;
        if (ctor) {
            constructorToName.set(ctor, name);
        }
    } catch {
        /* create may require args; constructor mapping skipped */
    }
}

/** Register a Julia `Scripts.FooModule` namespace on `JulGame.Scripts` (support / dual modules). */
export function registerSupportModule(
    moduleName: string,
    exports: Record<string, unknown>,
): void {
    const root = globalThis as { JulGame?: { Scripts?: Record<string, Record<string, unknown>> } };
    const jg = (root.JulGame ??= {});
    const scripts = (jg.Scripts ??= {});
    scripts[moduleName] = { ...scripts[moduleName], ...exports };
}

/** Declared by transpiled game scripts (`tools/convert/script.jl` scans `scripts/*.jl`). */
export function registerScriptSounds(paths: string[]): void {
    for (const p of paths) {
        if (p) {
            scriptSoundPaths.add(p);
        }
    }
}

export function getScriptSoundPaths(): string[] {
    return [...scriptSoundPaths];
}

export function createScript(name: string): unknown {
    const hooks = registry.get(name);
    if (!hooks) {
        throw new Error(`scriptRegistry: unknown script "${name}"`);
    }
    const script = hooks.create();
    if (script && typeof script === "object") {
        Object.defineProperty(script, SCRIPT_NAME_KEY, {
            value: name,
            writable: false,
            enumerable: false,
            configurable: false,
        });
    }
    return script;
}

export function initializeScript(script: unknown, ...args: unknown[]): void {
    const hooks = registry.get(getScriptName(script));
    hooks?.initialize?.(script, ...args);
}

export function updateScript(script: unknown, deltaTime: number): void {
    const name = getScriptName(script);
    const hooks = registry.get(name);
    const result = hooks?.update?.(script, deltaTime);
    if (result instanceof Promise) {
        void result.catch((e) => console.error(`scriptRegistry: async update failed for ${name}`, e));
    }
}

export function shutdownScript(script: unknown): void {
    const hooks = registry.get(getScriptName(script));
    hooks?.onShutdown?.(script);
}

export function hasScript(name: string): boolean {
    return registry.has(name);
}
