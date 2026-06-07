/** Transpiled game scripts register here; bootstrap dispatches initialize/update by name. */

export type ScriptHooks = {
    create: () => unknown;
    initialize?: (script: unknown) => void;
    update?: (script: unknown, deltaTime: number) => void;
    onShutdown?: (script: unknown) => void;
};

const registry = new Map<string, ScriptHooks>();
const scriptSoundPaths = new Set<string>();

export function registerScript(name: string, hooks: ScriptHooks): void {
    registry.set(name, hooks);
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
    return hooks.create();
}

export function initializeScript(script: unknown): void {
    const name = script?.constructor?.name ?? "";
    const hooks = registry.get(name);
    hooks?.initialize?.(script);
}

export function updateScript(script: unknown, deltaTime: number): void {
    const name = script?.constructor?.name ?? "";
    const hooks = registry.get(name);
    const result = hooks?.update?.(script, deltaTime);
    if (result instanceof Promise) {
        void result.catch((e) => console.error(`scriptRegistry: async update failed for ${name}`, e));
    }
}

export function shutdownScript(script: unknown): void {
    const name = script?.constructor?.name ?? "";
    const hooks = registry.get(name);
    hooks?.onShutdown?.(script);
}

export function hasScript(name: string): boolean {
    return registry.has(name);
}
