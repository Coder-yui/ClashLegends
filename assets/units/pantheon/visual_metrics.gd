extends RefCounted
## Medium-body visual calibration: matches Twisted Fate head height in idle.
const BODY_SCALE := 1.05
const PREVIOUS_BODY_SCALE := 1.3
const RATIO := BODY_SCALE / PREVIOUS_BODY_SCALE
const PROP_SCALE := 0.009 * RATIO
const PARTICLE_SCALE := 0.0075 * RATIO
