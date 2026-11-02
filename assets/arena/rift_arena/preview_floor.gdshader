shader_type spatial;
uniform vec4 floor_color : source_color = vec4(0.09, 0.14, 0.22, 1.0);
varying vec3 world_position;
#include "res://assets/arena/rift_arena/model_aperture.gdshaderinc"
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    clip_model_wells(world_position, INV_VIEW_MATRIX[2].xyz);
    ALBEDO = floor_color.rgb;
    ROUGHNESS = 0.78;
}
