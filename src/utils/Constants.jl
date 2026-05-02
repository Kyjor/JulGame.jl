const BASE_SCALE_UNIT = 64.0
"""Runtime scale (px per world unit base); editor scene viewer may adjust via `SCALE_UNITS_REF[] = ...`."""
const SCALE_UNITS_REF = Ref{Float64}(BASE_SCALE_UNIT)

const BASE_GRAVITY = 9.81
GRAVITY = BASE_GRAVITY

const BASE_TIME_SCALE = 1.0
TIME_SCALE = BASE_TIME_SCALE