export type UiElementDrawRecord = {
    name: string;
    type: string;
    totalMs: number;
    steps: Record<string, number>;
};

/** Renderers stash sync-step timings; uiRender finishes with outer wall time (includes GPU flush). */
export type UiProfiledElement = {
    __uiProfileSteps?: Record<string, number>;
};

let frameSteps: Record<string, number> = {};
let framePhases: Record<string, number> = {};
let frameElements: UiElementDrawRecord[] = [];

export function isUiDrawProfilingEnabled(): boolean {
    return !!(globalThis as { __JULGAME_PROFILE_UI_DRAW?: boolean }).__JULGAME_PROFILE_UI_DRAW;
}

export function beginUiDrawProfileFrame(): void {
    if (!isUiDrawProfilingEnabled()) {
        return;
    }
    frameSteps = {};
    framePhases = {};
    frameElements = [];
}

export function recordUiFramePhase(label: string, ms: number): void {
    if (!isUiDrawProfilingEnabled()) {
        return;
    }
    framePhases[label] = (framePhases[label] ?? 0) + ms;
}

export function timeUiDrawStep<T>(label: string, fn: () => T): T {
    if (!isUiDrawProfilingEnabled()) {
        return fn();
    }
    const t0 = performance.now();
    const result = fn();
    const dt = performance.now() - t0;
    frameSteps[label] = (frameSteps[label] ?? 0) + dt;
    return result;
}

export function recordUiElementDraw(
    name: string,
    type: string,
    totalMs: number,
    steps: Record<string, number>,
): void {
    if (!isUiDrawProfilingEnabled()) {
        return;
    }
    frameElements.push({ name, type, totalMs, steps });
    for (const [key, ms] of Object.entries(steps)) {
        frameSteps[key] = (frameSteps[key] ?? 0) + ms;
    }
}

/** Outer timing from uiRender; merges renderer sync steps + deferred GPU work. */
export function finishUiElementDraw(
    el: UiProfiledElement,
    name: string,
    type: string,
    outerMs: number,
): void {
    if (!isUiDrawProfilingEnabled()) {
        delete el.__uiProfileSteps;
        return;
    }
    const steps = { ...(el.__uiProfileSteps ?? {}) };
    delete el.__uiProfileSteps;
    const sync = Object.values(steps).reduce((sum, ms) => sum + ms, 0);
    const deferred = outerMs - sync;
    if (deferred > 0.001) {
        steps.gpuDeferred = (steps.gpuDeferred ?? 0) + deferred;
    }
    recordUiElementDraw(name, type, outerMs, steps);
}

function fmtMs(ms: number): string {
    return ms < 0.1 ? ms.toFixed(3) : ms.toFixed(2);
}

export function flushUiDrawProfile(frameMs: number): void {
    if (!isUiDrawProfilingEnabled()) {
        return;
    }
    const phaseSummary = Object.entries(framePhases)
        .sort((a, b) => b[1] - a[1])
        .map(([k, v]) => `${k}:${fmtMs(v)}`)
        .join(" ");
    const sortedSteps = Object.entries(frameSteps).sort((a, b) => b[1] - a[1]);
    const stepSummary = sortedSteps.map(([k, v]) => `${k}:${fmtMs(v)}`).join(" ");
    const sortedEls = [...frameElements].sort((a, b) => b.totalMs - a.totalMs);
    const elSummary = sortedEls
        .slice(0, 8)
        .map((e) => {
            const top = Object.entries(e.steps).sort((a, b) => b[1] - a[1])[0];
            const topLabel = top ? ` ${top[0]}:${fmtMs(top[1])}` : "";
            return `${e.name}(${e.type})=${fmtMs(e.totalMs)}${topLabel}`;
        })
        .join(" | ");
    const phases = phaseSummary ? ` phases[${phaseSummary}]` : "";
    const steps = stepSummary ? ` steps[${stepSummary}]` : "";
    const elements = elSummary ? ` elements[${elSummary}]` : "";
    //console.log(`uiProfile ${frameMs.toFixed(2)}ms${phases}${steps}${elements}`);
}
