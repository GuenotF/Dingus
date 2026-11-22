shader_type canvas_item;
// Vent sur le décor (arbres, herbes, fleurs) : le haut du sprite se balance, le pied reste fixe.
// Tout est dans le vertex : le sprite est un quad dont seuls les deux coins du haut bougent,
// ce qui donne un léger cisaillement. Aucune logique de jeu.

// Zone du sprite dans l'atlas, en coordonnées UV (x, y, largeur, hauteur) : fixée par TileWind.
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
// Déplacement maximal du haut du sprite, en pixels de la tuile.
uniform float amplitude = 4.0;
uniform float speed = 1.3;
// 0 coupe l'effet (réglage « Animations du décor »).
uniform float strength = 1.0;
// Pas de quantification en pixels de la tuile (0 = mouvement lisse) : utile en pixel art.
uniform float snap = 0.0;

void vertex() {
	float top = clamp(1.0 - (UV.y - region.y) / region.w, 0.0, 1.0);
	// Une rafale traverse la carte en diagonale : les arbres voisins sont presque en phase.
	float t = TIME * speed + (VERTEX.x * 0.5 + VERTEX.y) * 0.006;
	float gust = sin(t) + 0.4 * sin(t * 2.3 + 1.3);
	float dx = amplitude * top * gust * strength;
	if (snap > 0.0) {
		dx = floor(dx / snap + 0.5) * snap;
	}
	VERTEX.x += dx;
}
