uniform sampler2D model_wells : filter_nearest, repeat_disable;
uniform int model_well_count = 0;
void clip_model_wells(vec3 position, vec3 to_camera) {
    if (position.y > 0.01 || abs(to_camera.y) < 0.0001) { return; }
    vec2 aperture = (position - to_camera * position.y / to_camera.y).xz;
    for (int i = 0; i < model_well_count; i++) {
        vec4 well = texelFetch(model_wells, ivec2(i, 0), 0);
        if (length(aperture - well.xy) < well.z) { discard; }
    }
}
