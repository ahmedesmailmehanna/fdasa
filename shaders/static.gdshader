// Camera static: animated grain + faint scanlines + a rolling bright band.
// Put it on a full-screen ColorRect over the camera feed and tween "intensity":
//   ~0.1  = constant faint grain while the tablet is up
//   ~0.9  = a burst (opening the tablet, switching cameras, someone moving)
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.12;
uniform vec2 grain_resolution = vec2(320.0, 180.0); // lower = chunkier grain
uniform float flicker_speed = 24.0;                  // grain changes per second

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * grain_resolution);
	float frame = floor(TIME * flicker_speed);
	float grain = hash(cell + frame * 1.37);

	// Thin horizontal scanlines
	float scan = 0.85 + 0.15 * sin(UV.y * 900.0);
	// A soft bright band that rolls down the screen
	float band = smoothstep(0.08, 0.0, abs(fract(UV.y - TIME * 0.15) - 0.5)) * 0.25;

	float value = clamp(grain * scan + band, 0.0, 1.0);
	COLOR = vec4(vec3(value), intensity);
}