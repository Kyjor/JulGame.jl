const DEFAULT_SCALE_UNITS = 64;

/** Mirrors `src/utils/Enums.jl` — keep numeric values in sync. */
const COLLISION_DIRECTION = {
  None: -1,
  Top: 1,
  Bottom: 2,
  Left: 3,
  Right: 4,
} as const;

/** Mirrors `src/utils/Enums.jl` — keep numeric values in sync. */
const COLLIDER_LOCATION = {
  Above: 1,
  Below: 2,
  LeftSide: 3,
  RightSide: 4,
} as const;

type JulGameGlobal = {
  SCALE_UNITS?: number;
  [key: string]: unknown;
};

const root = globalThis as typeof globalThis & { JulGame?: JulGameGlobal };
const julGame = (root.JulGame ??= {});

if (typeof julGame.SCALE_UNITS !== "number") {
  julGame.SCALE_UNITS = DEFAULT_SCALE_UNITS;
}

Object.assign(globalThis, COLLISION_DIRECTION, COLLIDER_LOCATION);

