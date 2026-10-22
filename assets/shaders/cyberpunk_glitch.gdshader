shader_type canvas_item;

uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.2;
uniform float scanline_speed = 2.0;

void fragment() {
	vec2 uv = UV;
	float scanline = sin(uv.y * 300.0 + TIME * scanline_speed) * 0.04;
	
	vec4 color_r = texture(TEXTURE, uv + vec2(glitch_intensity * 0.01 + scanline, 0.0));
	vec4 color_g = texture(TEXTURE, uv);
	vec4 color_b = texture(TEXTURE, uv - vec2(glitch_intensity * 0.01 + scanline, 0.0));
	
	COLOR = vec4(color_r.r, color_g.g, color_b.b, color_g.a);
}
