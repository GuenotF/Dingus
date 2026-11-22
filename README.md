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
assets/   (à venir) Graphismes et sons.
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
Simule 80 combats IA contre IA (placements aléatoires) et affiche les victoires de chaque
classe. Réglage actuel : environ 43 / 37.

## Graphismes

Les formes sont dessinées en code (temporaire). Les dimensions de tuile sont définies
dans `scripts/view/iso.gd` (64×32). Les vrais graphismes remplaceront `BoardView`,
`ObstacleView` et `FighterView` sans toucher à `core/`.
