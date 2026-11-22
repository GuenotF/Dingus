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
| Clic droit | Annuler le sort choisi |
| Échap / bouton ⚙ | Annuler le sort choisi, sinon ouvrir le menu pause |
| Espace / bouton | Prêt (placement) / Fin du tour |
| F11 | Plein écran / fenêtre |
| M | Couper / remettre le son |

Le jeu s'ouvre en fenêtre maximisée et tout s'agrandit avec la fenêtre. Sous chaque personnage,
un cercle à la couleur de son équipe (rouge : joueur 1, bleu : joueur 2) ; un cercle jaune en plus
indique le personnage qui joue.

**Interface de combat** : en bas, l'orbe de PV, les PA (étoile bleue) et PM (pas verts) du personnage
qui joue, ses sorts et « Fin du tour ». Chaque case de sort montre son coût (pastille bleue, rouge si
PA insuffisants), les lancers restants (points) et la recharge (chiffre sur fond sombre) ; une infobulle
détaille le sort au survol. En haut à droite : le tour et l'ordre de jeu. Quand un sort vise un
personnage, sa barre de PV montre la part que le sort peut retirer et les dégâts prévus (« K.O. » si létal).

Le menu oppose les deux joueurs face à face : chaque panneau montre le nom du joueur (crayon ou double-clic
pour le modifier, il s'affiche en combat), le personnage choisi animé sur sa case (flèches ‹ › pour en changer),
ses PV / PA / PM et ses sorts (survol = même infobulle qu'en combat), et une pilule **Humain / IA**.
Au centre, l'aperçu de la carte (la vraie scène, flèches ‹ › pour changer) et « Lancer le combat » (ou Entrée).
2 joueurs sur le même écran, contre l'IA, ou IA contre IA pour regarder.

## Classes

| Classe | PV | PA | PM | Sorts |
|---|---|---|---|---|
| Guerrier | 150 | 6 | 3 | Coup d'épée, Charge (bond), Repousser (poussée 2), Cri (+1 PM) |
| Mage de feu | 135 | 6 | 4 | Flammèche, Boule de feu, Pluie de feu (zone sans ligne de vue), Nova de flammes (autour de soi, repousse) |
| Archer | 125 | 6 | 3 | Flèche (portée 8), Flèche entravante (−2 PM), Flèche de recul (repousse 2), Roulade (bond) |
| Chevalier maudit | 120 | 6 | 3 | Lame sombre (vol de vie), Chaîne infernale (attire de 5, −2 PM), Malédiction (−2 PA), Pacte de sang (−12 PV, +3 PA) |

Créer un nouveau personnage : voir [docs/creation_personnage.md](docs/creation_personnage.md)
(checklist, étapes, critères d'équilibrage, modèle de fiche).

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
- [x] Phase 4 — Animations, sons, interface
- [ ] Phase 5 — Multijoueur en ligne
- [ ] Phase 6 — Export Windows / Web

## Ajouter ou modifier un sort

Dans le panneau FileSystem de Godot, duplique un fichier de `data/spells/` et modifie-le
dans l'inspecteur : coût, portée, ligne de vue, zone, recharge, et surtout la liste
**Effets** (dégâts, vol de vie, soin, poussée, attraction, bond, bonus/malus de PA ou PM).
Son **icône** (champ `icon`, groupe Visuel) : un SVG blanc sur fond transparent dans `assets/ui/spells/`
(sans icône, la case affiche les deux premières lettres du nom).
Ajoute-le ensuite à la liste `spells` d'une classe dans `data/classes/`.

Pour une nouvelle classe : duplique un fichier de `data/classes/` et ajoute son chemin
dans `CLASS_PATHS` (`scripts/game_config.gd`).

## Équilibrage

```
godot --headless --path . -s res://tests/simulate_balance.gd
```
Simule 80 combats IA contre IA pour **chaque paire de personnages** sur **chaque carte** et affiche
victoires, durée moyenne et avantage du premier joueur. Options pour cibler un cas :
`-- personnage=Archer adversaire=Mage carte=Prairie parties=20 graine=1`.

Résultats actuels (victoires du premier nommé) :

| Duel | Prairie | Le lac | Place du village |
|---|---|---|---|
| Guerrier / Mage de feu | 67 / 32 % | 45 / 55 % | 61 / 38 % |
| Archer / Guerrier | 46 / 53 % | 85 / 15 % | 49 / 50 % |
| Archer / Mage de feu | 41 / 58 % | 50 / 50 % | 53 / 46 % |
| Chevalier maudit / Guerrier | 63 / 36 % | 45 / 54 % | 52 / 47 % |
| Chevalier maudit / Mage de feu | 49 / 50 % | 0 / 100 % | 47 / 52 % |
| Chevalier maudit / Archer | 73 / 26 % | 26 / 73 % | 75 / 24 % |

Détail et historique des réglages : `docs/personnages/`.

## Dessiner une carte

Les cartes sont des scènes Godot dans `maps/`. Le menu de départ liste **automatiquement**
toutes les scènes de ce dossier : une carte ajoutée y apparaît sans toucher au code.

Cartes actuelles :
- **Prairie** (`demo.tscn`) : rochers et troncs au centre, jeu sur les lignes de vue.
- **Le lac** (`lac.tscn`) : une rivière coupe le terrain, deux ponts, deux pierres dans l'eau.
- **Place du village** (`village.tscn`) : place pavée autour d'un puits, étals, charrette, tonneaux,
  clôtures. Tuiles du pack *Fantasy tileset - 2D Isometric* (`assets/tiles/village/`), en rendu lissé.

1. **Ouvrir** une carte de `maps/`, ou la **dupliquer** (clic droit → Dupliquer) pour en créer une nouvelle.
   Sur le nœud racine, renseigner `map_name` et `description` (affichés dans le menu).
2. Dans l'arbre de la scène, **sélectionner un calque** :
   - `Sol` : le terrain. Chaque case peinte fait partie de la grille de combat.
   - `SolDetail` (optionnel) : surcouches à plat sur le sol (herbe, gravillons), toujours sous les personnages.
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

Actuellement : le **Guerrier** utilise le pack *2D HD Character Knight* (`assets/characters/knight/`),
le **Mage de feu**, l'**Archer** et le **Chevalier maudit** le pack *2D HD Character pack 1* (`assets/characters/wizard/`, `assets/characters/archer/`, `assets/characters/chevalier/`).

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

## Menus et paramètres

- **Menu pause** (Échap ou bouton ⚙ en haut à gauche du combat) : Reprendre, Rejouer, Paramètres,
  Menu principal, Quitter le jeu. Le combat est gelé tant qu'il est ouvert (l'IA attend aussi).
  Rejouer, Menu principal et Quitter demandent confirmation. Code : `scripts/view/pause_menu.gd`.
- **Paramètres** (aussi depuis l'icône ⚙ du menu principal, à côté de l'icône Quitter) : volume général,
  volume des voix, son coupé, plein écran. Code : `scripts/view/settings_panel.gd`.
- Les réglages sont gérés par l'autoload `Settings` (`scripts/settings.gd`) et mémorisés dans
  `user://settings.cfg` (sous Windows : `%APPDATA%\Godot\app_userdata\Dingus`).

## Sons

Les voix passent par l'autoload `Sound` (`scripts/audio/sound.gd`, bus audio « Voix »).
Un personnage parle si sa classe a une **voix** (champ `voice`, une ressource `CharacterVoice`
dans `data/voices/`) : plusieurs variantes par moment (attaque, attaque lourde, cri, dégâts,
gros dégâts, mort, victoire, premier tour, choix dans le menu), tirées au hasard. Le moment d'un sort
dépend de son animation (`melee` → attaque, `jump` / `kick` → attaque lourde, sinon cri).

Pour donner une voix à un personnage : convertir les sons en `.ogg` dans `assets/audio/voices/<perso>/`,
créer une ressource `CharacterVoice` (clic droit dans FileSystem → Nouvelle ressource), y glisser les sons,
puis la mettre dans le champ `voice` de la classe.

Actuellement : le **Guerrier** parle (*Warrior Voice Pack* de John Carroll,
[johncarroll.itch.io](https://johncarroll.itch.io/) ; 52 répliques converties en OGG).
L'Archer, le Mage de feu et le Chevalier maudit n'ont pas encore de voix.

