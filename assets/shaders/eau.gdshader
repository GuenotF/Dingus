shader_type canvas_item;
// Scintillement de l'eau (pixel art) : des reflets clairs glissent lentement sur les tuiles d'eau.
// Les motifs sont quantifiés au texel pour garder un rendu « pixel », et calculés en coordonnées
// de la carte : les reflets se prolongent d'une tuile à l'autre. Purement visuel.

// 0 coupe l'effet (réglage « Animations du décor »).
uniform float strength = 1.0;
uniform float speed = 0.9;
// Intensité des reflets clairs.
uniform float glint = 0.16;

varying vec2 map_pos;

void vertex() {
	map_pos = VERTEX;
}

void fragment() {
	vec2 p = floor(map_pos / 2.0) * 2.0; // un « pixel » de reflet = 2 texels
	float t = TIME * speed;
	// Deux ondes qui se croisent : les reflets n'apparaissent qu'à l'intersection de leurs crêtes.
	float a = sin(p.x * 0.11 + p.y * 0.21 + t);
	float b = sin(p.x * 0.07 - p.y * 0.17 - t * 0.7 + 1.7);
	float spark = smoothstep(0.78, 0.95, a * b + 0.25 * sin(t * 1.7 + p.x * 0.3));
	float trough = smoothstep(0.0, -0.9, a * b) * 0.05;
	vec3 lit = COLOR.rgb + vec3(0.55, 0.8, 1.0) * glint * spark - vec3(trough);
	COLOR.rgb = mix(COLOR.rgb, lit, strength);
}
