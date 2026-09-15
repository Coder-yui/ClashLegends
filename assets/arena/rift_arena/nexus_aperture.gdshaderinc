// Match TowerModel3D's ground-plane aperture: expose the native stone well.
// Project every terrain layer onto the opening so buried foundations do not seal it.
void clip_nexus_well(vec3 position, vec3 to_camera) {
    if (position.y > 0.01 || abs(to_camera.y) < 0.0001) { return; }
    vec2 aperture = (position - to_camera * position.y / to_camera.y).xz;
    float nexus_z = 13.0 * sqrt(2.0);
    if (min(length(aperture - vec2(0.0, nexus_z)),
            length(aperture - vec2(0.0, -nexus_z))) < 1.35) { discard; }
}
