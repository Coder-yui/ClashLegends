extends RefCounted
## Presentation units only; never used to derive collision or damage.
const MODEL_SCALE := 2.50
const MESH_UNIT := 0.0085
const SOURCE_SKIN_SCALE := 1.75
const EFFECT_SCALE := MESH_UNIT * MODEL_SCALE / SOURCE_SKIN_SCALE
# E ground ring calibrated to a 160 px radius at 40 px/world unit.
# Keep XYZ uniform; shield particles still follow model scale.
const E_EFFECT_SCALE := 0.01
const GROUND_OFFSET := 0.0055 * MODEL_SCALE
const E_EVENT_RATIO := 8.0 / 19.0 # Spell3: frame 8, 19 intervals at 31 Hz.
