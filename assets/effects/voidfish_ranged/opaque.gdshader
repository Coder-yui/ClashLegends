shader_type spatial;
// Native blendMode=3: alpha-one replacement with depth writes, retaining emitter order.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_always, shadows_disabled, fog_disabled;
#define NATIVE_OPAQUE
#include "res://assets/effects/voidfish_ranged/particle.gdshaderinc"
