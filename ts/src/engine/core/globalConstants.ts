const DEFAULT_SCALE_UNITS = 64;

type JulGameGlobal = {
  SCALE_UNITS?: number;
  [key: string]: unknown;
};

const root = globalThis as typeof globalThis & { JulGame?: JulGameGlobal };
const julGame = (root.JulGame ??= {});

if (typeof julGame.SCALE_UNITS !== "number") {
  julGame.SCALE_UNITS = DEFAULT_SCALE_UNITS;
}

