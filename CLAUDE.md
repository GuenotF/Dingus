# Dingus — consignes pour Claude

Jeu tactique 1v1 au tour par tour en vue isométrique (style Dofus), Godot 4.7, GDScript.
Échanges et commentaires de code en français.

## Workflow
- Travailler **directement dans ce dossier** (le clone de l'utilisateur, `C:\ClaudeProjects\Dingus\Dingus`),
  pas dans une copie : l'utilisateur teste aussitôt dans Godot (F5), sans `git pull`.
- Vérifier avant de rendre la main, avec **Godot 4.7.2** (même version que l'utilisateur) :
  - tests : `godot --headless --path . -s res://tests/test_core.gd` → « Tests terminés : OK » ;
  - équilibrage après un changement de classe, de sort ou de carte : `res://tests/simulate_balance.gd` ;
  - pour un changement visible : jouer une partie et faire des captures d'écran.
- **Claude commite** (message clair en français), **l'utilisateur pousse** (`git push`) :
  le push vers GitHub n'est pas possible depuis l'environnement de Claude.
- Ne pas commiter les dossiers de packs bruts (`2D HD Character Knight`, `isometric tileset`) :
  le jeu utilise ses propres copies dans `assets/`.
- Images en Git classique (pas de Git LFS).

## Créer un personnage
Suivre `docs/creation_personnage.md` : fiche validée avec l'utilisateur d'abord, puis assets, données,
code si besoin, captures, équilibrage (critères chiffrés), commit.

## Architecture (voir README)
- `scripts/core/` : logique pure (grille, combat, sorts, IA). **Ne dépend jamais de `view/`** :
  elle tournera telle quelle sur un serveur en multijoueur.
- `scripts/view/` : affichage ; réagit aux signaux de `CombatState`.
- `data/` : classes, sorts, sprites en `.tres` (modifiables dans l'inspecteur).
- `maps/` : cartes (calques Sol, Decor, Placement), listées automatiquement dans le menu.
