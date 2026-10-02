// One separable gaussian pass. `tapStep` is the uv offset between taps along the
// blur axis (texel size * spacing). 9 taps total; weights come from Lua.
extern float weights[5];
extern vec2 tapStep;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
	vec3 sum = Texel(tex, uv).rgb * weights[0];
	for (int i = 1; i < 5; i++) {
		vec2 o = tapStep * float(i);
		sum += (Texel(tex, uv + o).rgb + Texel(tex, uv - o).rgb) * weights[i];
	}
	return vec4(sum, 1.0);
}
