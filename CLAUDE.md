# Dingus — consignes pour Claude

Jeu tactique 1v1 au tour par tour en vue isométrique (style Dofus), Godot 4.7, GDScript.
Échanges et commentaires de code en français.

## Workflow
- Travailler **directement dans ce dossier** (le clone de l'utilisateur, `C:\ClaudeProjects\Dingus\Dingus`),
  pas dans une copie : l'utilisateur teste aussitôt dans Godot (F5), sans `git pull`.
- Vérifier avant de rendre la main, avec **Godot 4.7.2** (même version que l'utilisateur) :
  - tests : `godot --headless --path . -s res://tests/test_core.gd` → « Tests terminés : OK » ;
  - équilibrage après un changement de classe, de sort ou de carte : `res://tests/balance_matrix.gd`
    (matrice, plusieurs processus, alertes ; seuils dans `tests/balance_config.json`, options dans l'en-tête du script) ;
    `res://tests/simulate_balance.gd` reste disponible pour le détail par duel ;
  - pour un changement visible : jouer une partie et faire des captures d'écran.
- **Pas de branche par ajout** : on commite sur `main`. Une branche seulement si l'utilisateur le demande ou pour une
  très grosse modification qui pourrait casser le jeu (le prévenir avant).
- **Claude commite** (message clair en français), **l'utilisateur pousse** (`git push origin main`).
  Quand le PC de l'utilisateur est éteint, Claude travaille dans un clone de son espace cloud et pousse une branche
  que l'utilisateur fusionne (`git merge --ff-only`).
- Ne jamais faire `git add -A` : les fichiers audio et la police apparaissent à tort comme modifiés (attributs LFS).
  Ajouter les fichiers un par un. Les fichiers `.uid` de Godot sont versionnés (les ajouter avec leur script).
- Sous Windows, Godot s'appelle par son chemin complet (exécutable `_console.exe` pour voir la sortie des tests).
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

## Fonctionnalités en place (repères pour ne pas les redécouvrir)
- **Fond et ambiance** : `scripts/view/background_view.gd` (halo, vignette, socle, particules). Par carte : `background_color`
  et `ambiance` (aucune, sable, pollen, lucioles) dans la scène. Réglage joueur : niveau de particules (`Settings.particles_level`).
- **Vent et eau** : `scripts/map/tile_wind.gd` pose des shaders (`assets/shaders/vent.gdshader`, `eau.gdshader`) sur des
  tuiles précises, table par TileSet dans `CONFIG`. Réglage joueur : animation du décor (`Settings.scenery_animation`).
- **Destructibles** : logique dans `BattleGrid` (`add_destructible`, `damage_destructible`, signaux dans `CombatState`) ;
  un obstacle est destructible si sa tuile a la donnée `destructible_hp` > 0 (calque de données du TileSet).
  Seuls les sorts qui font des dégâts les ciblent (`SpellData.damages_obstacles()`) ; poussée contre un obstacle = dégâts.
  L'IA en tient compte (`AiBrain._obstacle_value`). Affichage : `scripts/view/obstacle_view.gd` (barre de PV, secousse),
  animations d'effondrement du pack dans `assets/destruction/` associées aux tuiles par `scripts/view/destruction_anims.gd`
  (sans association : ancien effondrement dessiné par le code).
- **Cartes** : prairie, lac, village, désert (destructibles : rochers, colonnes), « Le barrage » (proto autour des destructibles).
  Les cartes désert et barrage sont générées par `tools/build_desert_map.gd` et `tools/build_barricade_map.gd` ;
  **relancer un générateur écrase la scène** (réglages faits à la main dans l'éditeur perdus).
- **Chiffres flottants** : `FloatingText` empile les chiffres proches (dégâts simultanés lisibles).
- **Police** : Vinque Antique (`assets/fonts/`, licence détenue par l'utilisateur), appliquée partout via `GameConfig`.

## Pistes et état du projet
Voir la feuille de route dans le Project « Jeu Vidéo 2.5d » (`claude/feuille_de_route.md`).
