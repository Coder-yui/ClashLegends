shader_type spatial;
render_mode cull_disabled, specular_disabled;
varying vec3 world_position;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p=world_position.xz;
    float t=TIME*.22;
    float depth=1.0-smoothstep(.45,1.40,abs(p.y));
    // Broad drifting strokes, with broken highlights instead of a cellular grid.
    float bend=sin(p.x*.62+t)*.20+sin(p.x*1.73-t)*.07;
    float stream=sin((p.y+bend)*12.0+p.x*.28-t*1.4);
    float secondary=sin((p.y-bend)*23.0-p.x*.52+t*.75);
    float broken=smoothstep(.15,.70,sin(p.x*1.24+t)+sin(p.x*2.6-t)*.28);
    float highlight=pow(max(stream,0.0),13.0)*broken;
    float ripple=pow(max(secondary,0.0),18.0)*.25;
    vec3 deep=vec3(.028,.20,.245);
    vec3 shallow=vec3(.095,.34,.33);
    vec3 water=mix(shallow,deep,depth*.74);
    water+=vec3(.04,.10,.10)*(highlight*.43+ripple*.30);
    float shore=smoothstep(1.18,1.42,abs(p.y));
    water+=vec3(.065,.13,.12)*shore*(.40+.24*sin(p.x*7.0-t));
    ALBEDO=water;
    EMISSION=water*.17;
    ROUGHNESS=.82;
}
