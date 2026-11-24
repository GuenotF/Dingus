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
- Sans Godot sur la machine de travail : la VM du PC (outil device_bash) peut télécharger Godot 4.7.2 Linux depuis GitHub et
  lancer les tests sur une **copie** du projet hors du dossier (pour ne pas toucher au cache `.godot` de l'éditeur) ;
  captures possibles avec `xvfb-run` et `--rendering-driver opengl3`. Rapatrier ensuite les fichiers générés (.import, .uid, scènes).
- Sous Windows, Godot s'appelle par son chemin complet (exécutable `_console.exe` pour voir la sortie des tests).
- Ne pas commiter les dossiers de packs bruts (`2D HD Character Knight`, `isometric tileset`) :
  le jeu utilise ses propres copies dans `assets/`.
- Images en Git classique (pas de Git LFS).

## Créer un personnage
Inventaire des personnages et des skins disponibles : `docs/inventaire_personnages.md` (à mettre à jour à chaque ajout).
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
- **Cartes** : prairie, lac, village, désert (destructibles : rochers, colonnes), « Le barrage » (proto autour des destructibles),
  forêt « Clairière des gobelins » (destructibles : feuillus, troncs ; animation `arbre_vert`).
  Les cartes désert, barrage et forêt sont générées par `tools/build_desert_map.gd`, `tools/build_barricade_map.gd` et `tools/build_forest_map.gd` ;
  **relancer un générateur écrase la scène** (réglages faits à la main dans l'éditeur perdus).
- **Fumée** (Fumigène du Gobelin) : `CombatState.smokes` (nuages, durée 1 tour, expiration au début du tour du lanceur), `has_view` / `smoke_blocks_view`
  (aveugle depuis une case de fumée, écran pour les cases intermédiaires), −2 PM au début du tour dans le nuage ; effets `SMOKE` et `STEAL_PA`,
  zone `SQUARE` ; affichage `scripts/view/smoke_view.gd`. L'IA l'évalue dans `score_cast` / `position_score`.
- **Chiffres flottants** : `FloatingText` empile les chiffres proches (dégâts simultanés lisibles).
- **Personnages et campagne** : listes dans `scripts/core/roster.gd` (`Roster`, sans autoload : utilisable dans les tests) :
  `CLASS_PATHS` (jouables), `ENEMY_PATHS` (PNJ non jouables : hors menu 1v1, démo titre et matrice d'équilibrage),
  `CAMPAIGN_FIGHTS` (titre, carte, ennemi). `GameConfig.start_campaign()` / `start_versus()` (écran titre) ; en campagne,
  l'écran de préparation (`menu.gd`) impose la carte et l'ennemi (`PlayerPanel.fixed_class`), le joueur 1 est humain.
  Pas encore de progression sauvegardée (un seul combat).
- **Sons** : autoload `Sound` (`scripts/audio/sound.gd`), bus Voix / Effets / Musique (volumes dans `Settings`).
  Bruitages `assets/audio/sfx/<nom>_1.ogg, _2...` (variantes tirées au hasard, volume corrigé dans `SFX_TRIM`) ;
  sorts : `cast_sound` / `impact_sound` de `SpellData` ; cartes : `ambience_sound` et `footstep_sound` de `BattleMap` ;
  musiques `music/` (exploration, combat), ambiances `ambience/`. Boutons : clic et survol automatiques.
  Banque de sons brute triée par usage : `C:\ClaudeProjects\Dingus\Sounds` (convertir en OGG avec ffmpeg avant d'importer).
- **Police** : Vinque Antique (`assets/fonts/`, licence détenue par l'utilisateur), appliquée partout via `GameConfig`.

## Pistes et état du projet
Voir la feuille de route dans le Project « Jeu Vidéo 2.5d » (`claude/feuille_de_route.md`).
