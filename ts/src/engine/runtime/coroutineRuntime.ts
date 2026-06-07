/** Minimal Julia `Condition` / `@task` parity for transpiled game scripts. */

export class Condition {
    private done = false;

    wait(): Promise<void> {
        if (this.done) {
            return Promise.resolve();
        }
        return new Promise((resolve) => {
            this._resolve = resolve;
        });
    }

    private _resolve: (() => void) | null = null;

    notify(): void {
        this.done = true;
        this._resolve?.();
        this._resolve = null;
    }
}

type TaskRecord = {
    promise: Promise<void>;
    done: boolean;
};

const tasks = new Set<TaskRecord>();
let frameResolvers: Array<() => void> = [];

export function waitCondition(condition: Condition): Promise<void> {
    return condition.wait();
}

export function notifyCondition(condition: Condition): void {
    condition.notify();
}

export function scheduleTask(fn: () => Promise<void> | void): TaskRecord {
    const record: TaskRecord = { promise: Promise.resolve(), done: false };
    tasks.add(record);
    record.promise = (async () => {
        try {
            await fn();
        } finally {
            record.done = true;
            tasks.delete(record);
        }
    })();
    return record;
}

export function isTaskDone(task: TaskRecord | null | undefined): boolean {
    return task == null || task.done;
}

export function yieldTask(): Promise<void> {
    return new Promise((resolve) => {
        frameResolvers.push(resolve);
    });
}

/** Call once per frame after script updates. */
export function tickCoroutines(): void {
    const resolvers = frameResolvers;
    frameResolvers = [];
    for (const r of resolvers) {
        r();
    }
}

export function installCoroutineGlobals(jg: Record<string, unknown>): void {
    jg.Condition = Condition;
    (globalThis as unknown as { scheduleTask: typeof scheduleTask }).scheduleTask = scheduleTask;
    (globalThis as unknown as { waitCondition: typeof waitCondition }).waitCondition = waitCondition;
    (globalThis as unknown as { notifyCondition: typeof notifyCondition }).notifyCondition =
        notifyCondition;
    (globalThis as unknown as { yieldTask: typeof yieldTask }).yieldTask = yieldTask;
    (globalThis as unknown as { isTaskDone: typeof isTaskDone }).isTaskDone = isTaskDone;
}
