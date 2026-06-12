shader_type canvas_item;

uniform int outline_width : hint_range(1, 12) = 6;

void fragment() {
	float max_alpha = 0.0;
	vec2 px = TEXTURE_PIXEL_SIZE;
	for (int dx = -12; dx <= 12; dx++) {
		if (abs(dx) > outline_width) {
			continue;
		}
		for (int dy = -12; dy <= 12; dy++) {
			if (abs(dy) > outline_width) {
				continue;
			}
			if (length(vec2(float(dx), float(dy))) > float(outline_width) + 0.5) {
				continue;
			}
			vec2 offset = vec2(float(dx), float(dy)) * px;
			max_alpha = max(max_alpha, texture(TEXTURE, UV + offset).a);
		}
	}
	COLOR = vec4(1.0, 1.0, 1.0, max_alpha);
}
