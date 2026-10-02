/** Julia `JulGame.Rendering.queue_render_function` / `RENDER_FUNCTIONS`. Drained each frame. */
export type QueuedRender = { layer: number; isWorldEntity: boolean; fn: () => void };

let queued: QueuedRender[] = [];

export function queue_render_function(
    fn: () => void,
    opts: { layer?: number; isWorldEntity?: boolean } = {},
): void {
    queued.push({ fn, layer: opts.layer ?? 0, isWorldEntity: opts.isWorldEntity ?? true });
}

/** World renders draw with sprites; screen renders draw with UI. Returned in layer order. */
export function takeQueuedRenders(isWorldEntity: boolean): QueuedRender[] {
    const taken = queued.filter((r) => r.isWorldEntity === isWorldEntity);
    queued = queued.filter((r) => r.isWorldEntity !== isWorldEntity);
    return taken.sort((a, b) => a.layer - b.layer);
}

export function callQueuedRender(r: QueuedRender): void {
    try {
        r.fn();
    } catch (e) {
        console.error("queued render function failed", e);
    }
}
