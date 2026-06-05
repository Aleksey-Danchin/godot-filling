shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
    COLOR = textureLod(screen_texture, SCREEN_UV, 3.0); // 3.0 — сила размытия
    COLOR.rgb *= 0.5; // Сразу и затемнение
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
