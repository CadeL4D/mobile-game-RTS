shader_type canvas_item;
render_mode unshaded;

uniform vec2 source_size = vec2(256.0, 256.0);

void fragment() {
	vec4 resources = texture(TEXTURE, UV);
	float strongest = max(max(resources.r, resources.g), max(resources.b, resources.a));
	if (strongest <= 0.015) {
		discard;
	}
	vec2 local = fract(UV * source_size) * 8.0 - vec2(4.0);
	vec3 color = vec3(0.0);
	float alpha = 0.0;
	if (resources.r >= resources.g && resources.r >= resources.b && resources.r >= resources.a) {
		// Living wood is the connected forest material itself. A per-node LOD glyph
		// would turn the canopy back into individual trees at wide mobile zoom.
		discard;
	} else if (resources.g >= resources.b && resources.g >= resources.a) {
		float shelf = abs(local.x) * 0.74 + abs(local.y) * 0.92;
		if (shelf < 4.2) {
			color = local.y < -0.5 ? vec3(0.59, 0.61, 0.59) : vec3(0.34, 0.36, 0.35);
			alpha = 0.96;
		}
	} else if (resources.b >= resources.a) {
		float shard_a = abs(local.x + 1.4) + abs(local.y + 0.5) * 0.48;
		float shard_b = abs(local.x - 1.6) + abs(local.y + 1.1) * 0.42;
		if (shard_a < 2.1 || shard_b < 2.0) {
			color = local.y < -1.0 ? vec3(0.59, 0.90, 0.91) : vec3(0.18, 0.61, 0.65);
			alpha = 0.98;
		}
	} else {
		float leaf = abs(local.x) + abs(local.y) * 0.72;
		if (leaf < 3.4) {
			color = leaf < 1.35 ? vec3(0.84, 0.68, 0.23) : vec3(0.35, 0.52, 0.17);
			alpha = 0.94;
		}
	}
	COLOR = vec4(color, alpha * (0.62 + strongest * 0.38));
}
