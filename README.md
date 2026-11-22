# Tactique Iso

Prototype de jeu tactique 1v1 au tour par tour, en vue isométrique (style Dofus), avec Godot 4.

## Lancer le projet

1. Installer Godot 4.5 ou plus récent (version standard, pas .NET).
2. Dans Godot : **Importer** → sélectionner `project.godot`.
3. Appuyer sur **F5**.

## Contrôles

| Action | Effet |
|---|---|
| Survol d'une case | Aperçu du chemin |
| Clic gauche | Se placer (avant le combat), se déplacer, ou lancer le sort choisi |
| 1 à 4 | Choisir un sort |
| Clic droit / Échap | Annuler le sort choisi |
| Espace / bouton | Prêt (placement) / Fin du tour |

Le menu permet de choisir la classe de chaque joueur et s'il est contrôlé par un humain
ou par l'IA (2 joueurs sur le même écran, contre l'IA, ou IA contre IA pour regarder).

## Classes

| Classe | PV | PA | PM | Sorts |
|---|---|---|---|---|
| Guerrier | 105 | 6 | 3 | Coup d'épée, Charge (bond), Repousser (poussée 2), Cri (+1 PM) |
| Druide | 105 | 6 | 4 | Épine, Ronces (zone, −2 PM), Attirer (attraction 2), Soin |

Une poussée bloquée par un obstacle, un pion ou le bord inflige 8 dégâts par case
non parcourue. Les bonus et malus s'affichent au-dessus du pion avec leur durée.

## Structure

```
scripts/
  core/   Logique pure (grille, combattants, tours). Aucun nœud graphique.
  view/   Affichage : conversion iso, plateau, pions, obstacles, interface.
  main.gd Assemble core + view et gère les entrées.
scenes/   Scènes Godot.
tests/    Tests de la logique.
data/classes/ Classes (.tres) : stats et liste de sorts.
data/spells/  Sorts (.tres) : portée, zone et liste d'effets, modifiables dans l'inspecteur.
maps/     Cartes de combat (scènes à 3 calques : Sol, Decor, Placement).
assets/   Graphismes : tileset (assets/tiles/) et personnages (assets/characters/).
```

**Règle d'or :** `core/` ne connaît pas `view/`. La vue appelle les méthodes de `CombatState`
et réagit à ses signaux. C'est ce qui permettra de faire tourner la même logique sur
un serveur en phase 5.

## Tests

```
godot --headless --path . -s res://tests/test_core.gd
```

## Feuille de route

- [x] Phase 0 — Mise en place
- [x] Phase 1 — Grille iso, déplacement A*, tours
- [x] Phase 2 — PA, sorts (Resources), ligne de vue, PV, victoire
- [x] Phase 3 — Classes, effets, placement, IA simple, menu
- [ ] Phase 4 — Animations, sons, interface
- [ ] Phase 5 — Multijoueur en ligne
- [ ] Phase 6 — Export Windows / Web

## Ajouter ou modifier un sort

Dans le panneau FileSystem de Godot, duplique un fichier de `data/spells/` et modifie-le
dans l'inspecteur : coût, portée, ligne de vue, zone, recharge, et surtout la liste
**Effets** (dégâts, soin, poussée, attraction, bond, bonus/malus de PA ou PM).
Ajoute-le ensuite à la liste `spells` d'une classe dans `data/classes/`.

Pour une nouvelle classe : duplique un fichier de `data/classes/` et ajoute son chemin
dans `CLASS_PATHS` (`scripts/game_config.gd`).

## Équilibrage

```
godot --headless --path . -s res://tests/simulate_balance.gd
```
Simule 80 combats IA contre IA sur **chaque carte** (placements aléatoires) et affiche les victoires
de chaque classe (Guerrier / Druide). Actuellement : Prairie ≈ 35 / 45, Le lac ≈ 24 / 56
(la rivière avantage le personnage à distance).

## Dessiner une carte

Les cartes sont des scènes Godot dans `maps/`. Le menu de départ liste **automatiquement**
toutes les scènes de ce dossier : une carte ajoutée y apparaît sans toucher au code.

Cartes actuelles :
- **Prairie** (`demo.tscn`) : rochers et troncs au centre, jeu sur les lignes de vue.
- **Le lac** (`lac.tscn`) : une rivière coupe le terrain, deux ponts, deux pierres dans l'eau.

1. **Ouvrir** une carte de `maps/`, ou la **dupliquer** (clic droit → Dupliquer) pour en créer une nouvelle.
   Sur le nœud racine, renseigner `map_name` et `description` (affichés dans le menu).
2. Dans l'arbre de la scène, **sélectionner un calque** :
   - `Sol` : le terrain. Chaque case peinte fait partie de la grille de combat.
   - `Decor` : rochers, troncs, fleurs... posés sur le sol.
   - `Placement` : cases de départ (marqueur rouge = joueur 1, bleu = joueur 2).
     Ce calque est invisible en jeu.
3. Le panneau **TileMap** s'ouvre en bas : choisir une tuile, puis peindre dans la vue
   (clic gauche = peindre, clic droit = effacer, outils rectangle et pot de peinture en haut du panneau).
4. Sauvegarder (Ctrl+S) et lancer (F5).

Règles lues sur la carte :
- une tuile marquée **obstacle** (rochers, troncs, souche, pierres dans l'eau) bloque le déplacement et la
  ligne de vue ; les fleurs et buissons du calque `Decor` se traversent ;
- une tuile marquée **water** (l'eau, 2 rangées du tileset) bloque le déplacement mais **pas** la ligne
  de vue : on tire par-dessus. Une poussée s'arrête au bord (avec dégâts de collision), on ne peut pas
  bondir dans l'eau, mais un bond (Charge) peut passer par-dessus ;
- une case sans tuile de `Sol` est un trou infranchissable ;
- la carte doit commencer à la case (0, 0) (coin du haut).

Pour changer quelles tuiles sont des obstacles ou de l'eau : ouvrir `assets/tiles/terrain_tileset.tres`,
onglet **TileSet** en bas → **Paint** → propriété `obstacle` ou `water`, puis cliquer sur les tuiles.
La rangée d'eau la plus claire (glace) se traverse.

## Graphismes

La carte utilise le tileset isométrique (`assets/tiles/`). Les combattants utilisent un **sprite animé**
si leur classe en a un (champ `sprites` de la classe), sinon un pion temporaire.

Actuellement : le **Guerrier** utilise le pack *2D HD Character Knight* (`assets/characters/knight/`).

### Ajouter un personnage animé

1. Copie les planches dans `assets/characters/<nom>/`. Format attendu : une ligne par direction
   (8 lignes), une colonne par image, toutes les images de même taille.
2. Duplique `data/sprites/knight.tres` et règle-le dans l'inspecteur :
   - `frame_size`, `frames_per_row` ;
   - la **ligne** de la planche pour chacune des 4 directions de la grille ;
   - `feet_position` (position des pieds dans une image) et `height` (pour placer le nom) ;
   - la liste `animations` : `idle`, `walk`, `hit`, `die`, plus les noms utilisés par les sorts.
3. Dans la classe (`data/classes/*.tres`), mets ce fichier dans `sprites`.
4. Dans chaque sort, le champ `animation` choisit l'animation du lanceur
   (Guerrier : `melee`, `jump`, `kick`, `cast`). Une animation absente est simplement ignorée.

Les images sont versionnées normalement dans Git (pas de LFS nécessaire).
