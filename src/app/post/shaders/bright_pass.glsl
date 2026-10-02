// Downsample (2x2 box) and keep only what is brighter than `threshold`.
// `texel` is 1 / source size; the half-res pixel centre sits on the corner of
// four source texels, so +-0.5 texel hits each of them.
extern float threshold;
extern vec2 texel;

vec3 bright(Image tex, vec2 uv) {
	vec3 c = Texel(tex, uv).rgb;
	float l = max(c.r, max(c.g, c.b));
	return c * (max(l - threshold, 0.0) / max(l, 0.0001));
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
	vec2 h = texel * 0.5;
	vec3 sum = bright(tex, uv + vec2(-h.x, -h.y))
		+ bright(tex, uv + vec2(h.x, -h.y))
		+ bright(tex, uv + vec2(-h.x, h.y))
		+ bright(tex, uv + vec2(h.x, h.y));
	return vec4(sum * 0.25, 1.0);
}
