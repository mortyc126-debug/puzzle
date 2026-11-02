shader_type canvas_item;

// Улучшенные версии аватарок и рамок (Progression.item_tiers).
// tier 1 — «Сияющая»: раз в 3 секунды по картинке пробегает светлый блик.
// tier 2 — «Золотая»: картинка уходит в золото (gold_mix), блик тёплый, по ней мерцают искры.
// Игра перерисовывает экран ~20 раз в секунду из-за живых фонов тем — этого хватает для плавного блика.

uniform float tier = 1.0;
uniform float gold_mix = 0.0;
uniform float period = 3.0;
uniform float phase = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	vec3 rgb = tex.rgb;
	if (gold_mix > 0.0) {
		float lum = dot(rgb, vec3(0.299, 0.587, 0.114));
		vec3 gold = mix(vec3(0.5, 0.31, 0.06), vec3(1.0, 0.9, 0.55), smoothstep(0.05, 0.95, lum));
		rgb = mix(rgb, gold, gold_mix);
	}
	// Диагональный блик: проходит за ~1 секунду, остальное время картинка спокойна
	float t = fract(TIME / period + phase);
	float center = t * 2.6 - 0.45;
	float along = (UV.x + UV.y) * 0.5;
	float band = smoothstep(0.09, 0.0, abs(along - center));
	vec3 shine = tier > 1.5 ? vec3(1.0, 0.86, 0.5) : vec3(0.92, 0.96, 1.0);
	rgb += band * shine * 0.6;
	// Искры золотой версии: по одной в клетке сетки 7×7, каждая мерцает со своей фазой
	if (tier > 1.5) {
		vec2 cell = floor(UV * 7.0);
		vec2 local = fract(UV * 7.0);
		float seed = hash21(cell);
		vec2 spot = vec2(hash21(cell + 3.1), hash21(cell + 7.7)) * 0.6 + 0.2;
		float twinkle = pow(max(sin(TIME * (1.2 + seed * 2.0) + seed * 40.0), 0.0), 8.0);
		float d = length(local - spot);
		float star = smoothstep(0.16, 0.0, d) * twinkle * step(0.55, seed);
		rgb += vec3(1.0, 0.95, 0.75) * star * 1.2;
	}
	COLOR = vec4(rgb, tex.a);
}
