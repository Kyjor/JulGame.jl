/** Port of Battler `scripts/utils/Easings.jl` for transpiled game scripts. */

export function linear(x: number): number {
    return x;
}

export function ease_in_sine(x: number): number {
    return 1 - Math.cos((x * Math.PI) / 2);
}

export function ease_out_sine(x: number): number {
    return Math.sin((x * Math.PI) / 2);
}

export function ease_in_out_sine(x: number): number {
    return -(Math.cos(Math.PI * x) - 1) / 2;
}

export function ease_in_quad(x: number): number {
    return x ** 2;
}

export function ease_out_quad(x: number): number {
    return 1 - (1 - x) ** 2;
}

export function ease_in_out_quad(x: number): number {
    return x < 0.5 ? 2 * x ** 2 : 1 - (-2 * x + 2) ** 2 / 2;
}

export function ease_in_cubic(x: number): number {
    return x ** 3;
}

export function ease_out_cubic(x: number): number {
    return 1 - (1 - x) ** 3;
}

export function ease_in_out_cubic(x: number): number {
    return x < 0.5 ? 4 * x ** 3 : 1 - (-2 * x + 2) ** 3 / 2;
}

export function ease_in_quart(x: number): number {
    return x ** 4;
}

export function ease_out_quart(x: number): number {
    return 1 - (1 - x) ** 4;
}

export function ease_in_out_quart(x: number): number {
    return x < 0.5 ? 8 * x ** 4 : 1 - (-2 * x + 2) ** 4 / 2;
}

export function ease_in_quint(x: number): number {
    return x ** 5;
}

export function ease_out_quint(x: number): number {
    return 1 - (1 - x) ** 5;
}

export function ease_in_out_quint(x: number): number {
    return x < 0.5 ? 16 * x ** 5 : 1 - (-2 * x + 2) ** 5 / 2;
}

export function ease_in_expo(x: number): number {
    return x === 0 ? 0 : 2 ** (10 * (x - 1));
}

export function ease_out_expo(x: number): number {
    return x === 1 ? 1 : 1 - 2 ** (-10 * x);
}

export function ease_in_out_expo(x: number): number {
    if (x === 0) return 0;
    if (x === 1) return 1;
    if (x < 0.5) return 2 ** (20 * x - 10) / 2;
    return (2 - 2 ** (-20 * x + 10)) / 2;
}

export function ease_in_circ(x: number): number {
    return 1 - Math.sqrt(1 - x ** 2);
}

export function ease_out_circ(x: number): number {
    return Math.sqrt(1 - (x - 1) ** 2);
}

export function ease_in_out_circ(x: number): number {
    return x < 0.5
        ? (1 - Math.sqrt(1 - (2 * x) ** 2)) / 2
        : (Math.sqrt(1 - (-2 * x + 2) ** 2) + 1) / 2;
}

const c1 = 1.70158;
const c2 = c1 * 1.525;
const c3 = c1 + 1;

export function ease_in_back(x: number): number {
    return c3 * x ** 3 - c1 * x ** 2;
}

export function ease_out_back(x: number): number {
    return 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2;
}

export function ease_in_out_back(x: number): number {
    return x < 0.5
        ? ((2 * x) ** 2 * ((c2 + 1) * 2 * x - c2)) / 2
        : (((2 * x - 2) ** 2 * ((c2 + 1) * (x * 2 - 2) + c2)) + 2) / 2;
}

const c4 = (2 * Math.PI) / 3;
const c5 = (2 * Math.PI) / 4.5;

export function ease_in_elastic(x: number): number {
    if (x === 0) return 0;
    if (x === 1) return 1;
    return -(2 ** (10 * x - 10)) * Math.sin((x * 10 - 10.75) * c4);
}

export function ease_out_elastic(x: number): number {
    if (x === 0) return 0;
    if (x === 1) return 1;
    return 2 ** (-10 * x) * Math.sin((x * 10 - 0.75) * c4) + 1;
}

export function ease_in_out_elastic(x: number): number {
    if (x === 0) return 0;
    if (x === 1) return 1;
    if (x < 0.5) return -(2 ** (20 * x - 10) * Math.sin((20 * x - 11.125) * c5)) / 2;
    return (2 ** (-20 * x + 10) * Math.sin((20 * x - 11.125) * c5)) / 2 + 1;
}

export function ease_out_bounce(x: number): number {
    const n1 = 7.5625;
    const d1 = 2.75;
    if (x < 1 / d1) return n1 * x ** 2;
    if (x < 2 / d1) return n1 * (x -= 1.5 / d1) * x + 0.75;
    if (x < 2.5 / d1) return n1 * (x -= 2.25 / d1) * x + 0.9375;
    return n1 * (x -= 2.625 / d1) * x + 0.984375;
}

export function ease_in_bounce(x: number): number {
    return 1 - ease_out_bounce(1 - x);
}

export function ease_in_out_bounce(x: number): number {
    return x < 0.5
        ? (1 - ease_out_bounce(1 - 2 * x)) / 2
        : (1 + ease_out_bounce(2 * x - 1)) / 2;
}
