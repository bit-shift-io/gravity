// Radial zoom blur about the frame centre. `scale` zooms in about the centre;
// `strength` smears samples toward the centre by that fraction of the radius.
extern number strength;
extern number scale;

const int SAMPLES = 12;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen)
{
	vec2 centre = vec2(0.5, 0.5);
	vec2 d = (uv - centre) / scale;
	vec4 sum = vec4(0.0);
	for (int i = 0; i < SAMPLES; i++) {
		float s = float(i) / float(SAMPLES - 1);
		sum += Texel(tex, centre + d * (1.0 - strength * s));
	}
	return (sum / float(SAMPLES)) * color;
}
