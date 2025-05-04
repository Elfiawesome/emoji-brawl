// Filename: wind_sway_individual.gdshader
shader_type canvas_item;

// Uniforms: Parameters you can tweak in the Godot Inspector

// Speed of the swaying animation
uniform float speed : hint_range(0.1, 5.0) = 0.5;
// Maximum horizontal distance the top of the tile will sway (in pixels, approximately)
uniform float amplitude : hint_range(0.0, 5.0) = 1.0;
// Controls how strongly the top of the tile sways compared to the bottom.
uniform float vertical_gradient_power : hint_range(0.5, 4.0) = 2.0;

// *** IMPORTANT: Set this to match the Tile Size configured in your TileSet ***
uniform vec2 tile_size = vec2(16.0, 16.0); // Example: 16x16 pixels

// --- Helper Function: Simple Hash ---
// Takes a 2D vector (like tile coordinates) and returns a pseudo-random float between 0.0 and 1.0
// This ensures each tile position gets a unique, stable value.
float hash21(vec2 p) {
	// Use fract(sin(...)) for a simple pseudo-random hash
	// The specific numbers are arbitrary "magic numbers" to scramble the input
    p = fract(p * vec2(123.45, 678.91));
    p += dot(p, p + 45.67);
    return fract(p.x * p.y);
}
// ---

// The vertex function runs for each corner of the tile's quad.
void vertex() {
	// 1. Calculate the approximate grid coordinate of this tile.
	// Dividing the world vertex position by the tile size gives us a rough coordinate.
	// Using floor() snaps it to the integer grid cell the vertex belongs to.
	// All 4 vertices of the same tile should ideally map to the same tile_coord.
	vec2 tile_coord = floor(VERTEX / tile_size);

	// 2. Generate a unique, stable random value for this specific tile coordinate.
	// This value (rand) will be consistent for all vertices of the same tile,
	// but different for adjacent tiles.
	float tile_rand = hash21(tile_coord);

	// 3. Calculate a base time factor
	float time_factor = TIME * speed;

	// 4. Use the tile's random value to create a unique phase offset.
	// Multiplying by 2*PI (approx 6.28318) gives a full range of phase shifts.
	// This ensures each tile starts its sway cycle at a different point.
	float phase_offset = tile_rand * 6.28318;

	// 5. Calculate the sine wave using the time and the unique phase offset.
	// The result 'wave' will oscillate between -1.0 and 1.0, but out of sync for different tiles.
	float wave = sin(time_factor + phase_offset);

	// 6. Determine the influence based on the vertical position within the tile (UV.y).
	// Top (UV.y=0) moves most, bottom (UV.y=1) moves least.
	float vertical_influence = pow(max(0.0, 1.0 - UV.y), vertical_gradient_power);

	// 7. Calculate the final horizontal offset for this vertex.
	float horizontal_offset = wave * amplitude * vertical_influence;

	// 8. Apply the offset to the vertex's horizontal position.
	VERTEX.x += horizontal_offset;

	// Optional: Add slight vertical movement similarly, perhaps using a different hash or phase.
	// float tile_rand_y = hash21(tile_coord + vec2(0.5, 0.5)); // Slightly different hash input
	// float phase_offset_y = tile_rand_y * 6.28318;
	// float wave_y = cos(time_factor * 0.8 + phase_offset_y); // Use cos or different speed
	// float vertical_offset = wave_y * amplitude * 0.15 * vertical_influence;
	// VERTEX.y += vertical_offset;
}

// Fragment function remains unchanged (optional)
// void fragment() {
//     COLOR = texture(TEXTURE, UV);
// }