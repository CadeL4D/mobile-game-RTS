shader_type canvas_item;
render_mode unshaded;

uniform vec2 source_size = vec2(256.0, 256.0);

float pixel_hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = pixel_hash(cell);
	float b = pixel_hash(cell + vec2(1.0, 0.0));
	float c = pixel_hash(cell + vec2(0.0, 1.0));
	float d = pixel_hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

void fragment() {
	vec2 texel = 1.0 / source_size;
	float strength = texture(TEXTURE, UV).r;
	float neighbor = 0.0;
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(texel.x, 0.0)).r);
	neighbor = max(neighbor, texture(TEXTURE, UV - vec2(texel.x, 0.0)).r);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(0.0, texel.y)).r);
	neighbor = max(neighbor, texture(TEXTURE, UV - vec2(0.0, texel.y)).r);
	vec2 world_pixel = floor(UV * source_size * 8.0);
	float coarse = value_noise(world_pixel / vec2(31.0, 27.0));
	float middle_noise = value_noise((world_pixel + vec2(11.0, 7.0)) / vec2(14.0, 12.0));
	float sparse_detail = pixel_hash(floor(world_pixel / 3.0));
	if (strength <= 0.015) {
		// Only selected chunks of an occupied neighbor cross the ownership edge,
		// producing a broken root fringe instead of an eight-pixel square wall.
		if (neighbor <= 0.015 || middle_noise < 0.60) {
			discard;
		}
		strength = neighbor * (0.16 + coarse * 0.10);
	}
	float material = clamp(strength * 0.82 + (coarse - 0.5) * 0.26 + (middle_noise - 0.5) * 0.10, 0.0, 1.0);
	vec3 frontier = vec3(0.27, 0.20, 0.08);
	vec3 middle = vec3(0.25, 0.035, 0.19);
	vec3 core = vec3(0.47, 0.055, 0.35);
	vec3 color = mix(frontier, middle, smoothstep(0.16, 0.56, material));
	color = mix(color, core, smoothstep(0.60, 0.94, material));
	if (abs(middle_noise - 0.50) < 0.018 && strength > 0.12) {
		color *= 0.58;
	} else if (abs(middle_noise - 0.72) < 0.012 && strength > 0.42) {
		color = mix(color, vec3(0.60, 0.10, 0.44), 0.34);
	} else if (sparse_detail > 0.985) {
		color = mix(color, vec3(0.68, 0.12, 0.49), 0.46);
	} else if (sparse_detail < 0.025) {
		color *= 0.62;
	}
	float alpha = smoothstep(0.018, 0.18, strength) * (0.20 + material * 0.38);
	COLOR = vec4(color, alpha);
}
