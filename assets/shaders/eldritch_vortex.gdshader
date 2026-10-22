shader_type canvas_item;

uniform float swirl_strength : hint_range(0.0, 5.0) = 1.2;
uniform vec4 void_tint : source_color = vec4(0.3, 0.1, 0.4, 1.0);

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 uv = UV - center;
	float dist = length(uv);
	float angle = atan(uv.y, uv.x) + (1.0 - dist) * swirl_strength * sin(TIME * 0.8);
	
	vec2 swirled_uv = vec2(cos(angle), sin(angle)) * dist + center;
	vec4 base_color = texture(TEXTURE, clamp(swirled_uv, vec2(0.0), vec2(1.0)));
	
	COLOR = mix(base_color, void_tint, (1.0 - dist) * 0.35);
}
