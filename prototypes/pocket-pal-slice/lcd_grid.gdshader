// LCD panel look: visible pixel grid, faint scan flicker, subtle vignette.
//
// Applied to whatever CanvasItem presents the LCD image. It is deliberately
// independent of HOW that image was produced, so all three spike approaches
// share one shader and the comparison stays honest.
shader_type canvas_item;

// LCD panel resolution in "LCD pixels" (not screen pixels).
uniform vec2 lcd_resolution = vec2(64.0, 64.0);
// Grid line darkness. 0 = invisible, 1 = black gaps.
uniform float grid_strength : hint_range(0.0, 1.0) = 0.25;
// Fraction of each cell taken by the gap between pixels.
uniform float grid_gap : hint_range(0.0, 0.5) = 0.18;
// Backlight flicker depth. The concept asks for "a faint flicker", not a strobe.
uniform float flicker_strength : hint_range(0.0, 0.2) = 0.025;
uniform float flicker_speed = 7.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.25;
uniform vec3 backlight : source_color = vec3(0.78, 0.85, 0.61);

void fragment() {
	vec4 src = texture(TEXTURE, UV);

	// --- Pixel grid -------------------------------------------------------
	// Position within the current LCD cell, 0..1 on each axis.
	vec2 cell = fract(UV * lcd_resolution);
	// Distance from the cell edges; small near a gap.
	vec2 edge = min(cell, 1.0 - cell);
	float gap = min(edge.x, edge.y);
	// smoothstep over roughly one screen pixel of the cell so the grid stays
	// crisp when the panel is scaled up but does not alias when scaled down.
	float px = fwidth(gap) + 1e-5;
	float grid = smoothstep(grid_gap - px, grid_gap + px, gap);
	float grid_mul = mix(1.0 - grid_strength, 1.0, grid);

	// --- Backlight flicker ------------------------------------------------
	// Two detuned sines beat against each other so the flicker never settles
	// into an obvious loop.
	float f = sin(TIME * flicker_speed) * 0.6 + sin(TIME * flicker_speed * 2.3) * 0.4;
	float flicker = 1.0 + f * flicker_strength;

	// --- Vignette ---------------------------------------------------------
	vec2 d = UV - vec2(0.5);
	float vig = 1.0 - dot(d, d) * vignette_strength * 4.0;

	// Composite over the backlight so transparent areas of the source read as
	// lit panel rather than as holes.
	vec3 lit = mix(backlight, src.rgb, src.a);
	COLOR = vec4(lit * grid_mul * flicker * vig, 1.0);
}
