// CRT: barrel warp, rounded-corner mask and edge vignette over the composited
// game-rectangle image. Black outside the curved shape.
uniform float aspect;       // width / height
uniform float curvature;    // barrel strength, 0 = flat
uniform float cornerRadius; // in half-heights
uniform float vignette;     // edge darkening 0..1
uniform float heightPx;     // game-rectangle height in screen pixels
uniform float scanlineIntensity; // 0..1 darkening at line troughs
uniform float scanlinePitch;     // screen pixels per scanline period
uniform float grain;        // film grain amplitude, 0..1
uniform float grainTime;    // animated time for grain noise

// Hash function for pseudo-random noise from a 2D input.
float hash(vec2 p)
{
	p = fract(p * vec2(12.9898, 78.233));
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc)
{
	vec2 p = uv * 2.0 - 1.0;
	// Edge midpoints map to exactly the edge (divide by 1 + k); corners reach
	// past it and are clipped by the rounded mask.
	vec2 w = p * (1.0 + curvature * dot(p, p)) / (1.0 + curvature);

	// Rounded box in aspect-correct units (half-height = 1).
	vec2 half_ = vec2(aspect, 1.0);
	float r = min(cornerRadius, 1.0);
	vec2 q = abs(w) * half_ - (half_ - vec2(r));
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
	float aa = fwidth(d) + 1e-5;
	float mask = 1.0 - smoothstep(-aa, aa, d);

	// Never sample outside the texture (clamp would smear edge pixels).
	vec2 suv = clamp(w * 0.5 + 0.5, 0.0, 1.0);
	vec3 c = Texel(tex, suv).rgb;

	// Animated film grain: hash-based noise per screen pixel, applied inside
	// the mask. Grain changes every frame via the time uniform.
	// Scale by a time-varying factor too: a plain offset would only slide one
	// fixed pattern across the screen instead of changing it.
	vec3 grainNoise = vec3(hash(sc * (1.0 + fract(grainTime * 0.1731)) + fract(grainTime) * 97.0));
	c += (grainNoise - 0.5) * grain;

	// Scanlines: sine of the post-warp row in screen pixels, so the pitch is
	// constant across window sizes and the lines bow with the bubble. A sine
	// (not a hard step) keeps fractional scales from aliasing.
	float yPx = (w.y * 0.5 + 0.5) * heightPx;
	float scan = 1.0 - scanlineIntensity * (0.5 + 0.5 * sin(yPx / scanlinePitch * 6.28318530718));

	float e = max(abs(w.x), abs(w.y));
	float vig = 1.0 - vignette * smoothstep(0.55, 1.05, e) * e;
	return vec4(c * scan * vig * mask, 1.0) * color;
}
