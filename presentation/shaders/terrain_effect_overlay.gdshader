shader_type canvas_item;
render_mode unshaded;

uniform vec2 source_size = vec2(256.0, 256.0);

float pixel_hash(vec2 point) {
	return fract(sin(dot(point, vec2(269.5, 183.3))) * 43758.5453123);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	return mix(
		mix(pixel_hash(cell), pixel_hash(cell + vec2(1.0, 0.0)), local.x),
		mix(pixel_hash(cell + vec2(0.0, 1.0)), pixel_hash(cell + vec2(1.0, 1.0)), local.x),
		local.y
	);
}

void fragment() {
	vec4 masks = texture(TEXTURE, UV);
	vec2 texel = 1.0 / source_size;
	vec4 neighbor = max(
		max(texture(TEXTURE, UV + vec2(texel.x, 0.0)), texture(TEXTURE, UV - vec2(texel.x, 0.0))),
		max(texture(TEXTURE, UV + vec2(0.0, texel.y)), texture(TEXTURE, UV - vec2(0.0, texel.y)))
	);
	float strongest = max(max(masks.r, masks.g), masks.b);
	vec2 world_pixel = floor(UV * source_size * 8.0);
	float edge_noise = value_noise((world_pixel + vec2(7.0, 13.0)) / vec2(9.0, 8.0));
	if (strongest <= 0.015) {
		float neighbor_strength = max(max(neighbor.r, neighbor.g), neighbor.b);
		if (neighbor_strength <= 0.015 || edge_noise < 0.60) {
			discard;
		}
		masks = neighbor * (0.18 + edge_noise * 0.10);
		strongest = max(max(masks.r, masks.g), masks.b);
	}
	vec3 color;
	float opacity;
	bool is_fire = masks.r > 0.015 && masks.g > masks.r * 0.28 && masks.r > masks.g;
	if (is_fire) {
		color = vec3(0.20, 0.065, 0.03);
		opacity = 0.62;
	} else if (masks.g >= masks.r && masks.g >= masks.b) {
		color = vec3(0.10, 0.38, 0.48);
		opacity = 0.48;
	} else if (masks.b >= masks.r) {
		color = vec3(0.17, 0.16, 0.145);
		opacity = 0.52;
	} else {
		color = vec3(0.25, 0.145, 0.07);
		opacity = 0.48;
	}
	float coarse = value_noise(world_pixel / vec2(25.0, 21.0));
	float detail = pixel_hash(floor(world_pixel / 3.0));
	if (detail > 0.985) {
		color *= 1.20;
	} else if (detail < 0.025) {
		color *= 0.70;
	}
	float material = clamp(strongest * 0.88 + (coarse - 0.5) * 0.16, 0.0, 1.0);
	float alpha = smoothstep(0.025, 0.22, strongest) * (opacity * (0.58 + material * 0.42));
	COLOR = vec4(color, alpha);
}
