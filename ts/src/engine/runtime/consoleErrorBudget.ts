/** Caps console.error spam (e.g. per-frame sprite failures) so DevTools stays usable. */

export type ConsoleErrorBudget = {
    count: number;
    max: number;
    exceeded: boolean;
    /** First occurrences of distinct error message keys (for fix loops). */
    samples: string[];
};

const DEFAULT_MAX = 40;

function budgetSlot(): { JulGame?: { consoleErrorBudget?: ConsoleErrorBudget } } {
    return globalThis as { JulGame?: { consoleErrorBudget?: ConsoleErrorBudget } };
}

export function getConsoleErrorBudget(): ConsoleErrorBudget | undefined {
    return budgetSlot().JulGame?.consoleErrorBudget;
}

export function isConsoleErrorBudgetExceeded(): boolean {
    return getConsoleErrorBudget()?.exceeded === true;
}

/**
 * Wrap `console.error` so only the first `maxErrors` calls are forwarded.
 * Further calls are dropped after one budget-exceeded notice.
 */
export function installConsoleErrorBudget(maxErrors: number = DEFAULT_MAX): ConsoleErrorBudget {
    const existing = getConsoleErrorBudget();
    if (existing) {
        return existing;
    }

    const state: ConsoleErrorBudget = {
        count: 0,
        max: Math.max(1, maxErrors),
        exceeded: false,
        samples: [],
    };

    const g = budgetSlot();
    g.JulGame ??= {};
    g.JulGame.consoleErrorBudget = state;

    const seen = new Set<string>();
    const orig = console.error.bind(console);
    console.error = (...args: unknown[]) => {
        if (state.exceeded) {
            return;
        }
        const key = args
            .map((a) => (typeof a === "string" ? a : a instanceof Error ? a.message : String(a)))
            .join(" ")
            .slice(0, 240);
        if (!seen.has(key) && state.samples.length < 30) {
            seen.add(key);
            state.samples.push(key);
        }
        state.count += 1;
        if (state.count > state.max) {
            state.exceeded = true;
            orig(
                `[console.error] budget exceeded (${state.max}); silencing further errors`,
            );
            return;
        }
        orig(...args);
    };

    return state;
}
