shader_type canvas_item;

// Радужное имя игрока: оттенок плывёт вдоль текста. Красятся только светлые проходы (сам текст
// и белое свечение), тёмная тень надписи остаётся тенью.

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	if (COLOR.r > 0.9 && COLOR.g > 0.9 && COLOR.b > 0.9) {
		float hue = fract(local_pos.x / 380.0 - TIME * 0.1);
		base.rgb = hsv2rgb(vec3(hue, 0.5, 1.0));
	}
	COLOR = base;
}
