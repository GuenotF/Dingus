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
| Clic gauche | Déplacer le personnage actif, ou lancer le sort choisi |
| 1 / 2 / 3 | Choisir un sort (Coup d'épée, Flèche, Bombe) |
| Clic droit / Échap | Annuler le sort choisi |
| Espace / bouton | Fin du tour |

Les deux joueurs jouent sur le même écran, chacun à son tour.

## Structure

```
scripts/
  core/   Logique pure (grille, combattants, tours). Aucun nœud graphique.
  view/   Affichage : conversion iso, plateau, pions, obstacles, interface.
  main.gd Assemble core + view et gère les entrées.
scenes/   Scènes Godot.
tests/    Tests de la logique.
data/spells/  Sorts (.tres), modifiables dans l'inspecteur Godot.
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
- [ ] Phase 3 — Classes, effets, IA simple
- [ ] Phase 4 — Animations, sons, interface
- [ ] Phase 5 — Multijoueur en ligne
- [ ] Phase 6 — Export Windows / Web

## Ajouter ou modifier un sort

Dans le panneau FileSystem de Godot, duplique un fichier de `data/spells/`, modifie ses
valeurs dans l'inspecteur (coût, portée, ligne de vue, dégâts, zone, lancers par tour),
puis ajoute son chemin dans `SPELL_PATHS` (`scripts/main.gd`).

## Graphismes

Les formes sont dessinées en code (temporaire). Les dimensions de tuile sont définies
dans `scripts/view/iso.gd` (64×32). Les vrais graphismes remplaceront `BoardView`,
`ObstacleView` et `FighterView` sans toucher à `core/`.
