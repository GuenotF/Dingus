# Gobelin — le Pillard

**Identité** : pillard fourbe et fragile. Il n'écrase pas l'adversaire, il l'épuise : lui vole des PA, le ralentit, l'aveugle dans la fumée,
le repousse à coups de pétard. Servira plus tard d'ennemi de campagne / PVE (et se marie bien avec les coffres à bonus).
**Skin** : Goblin 01 (pack *2D Orcs and Goblins - TopDown - V1.0*). **Distance préférée (IA)** : 1 (à réviser à l'équilibrage).
**Stats** (provisoires) : PV 120 / PA 6 / PM 4

**Animations de base** : idle = Idle, walk = Walk, hit = TakeDamage 1, die = Die 1

| # | Sort | PA | Portée | Effets | Limites | Animation | Projectile / impact |
|---|------|----|--------|--------|---------|-----------|---------------------|
| 1 | Vol à la tire | 3 | 1 | 8–10 dégâts ; la cible perd 1 PA (1 tour) **et le gobelin gagne 1 PA tout de suite** | 1/tour, recharge 1 (chaque tour) | Attack 4 (bond d'attaque) | — |
| 2 | Coup bas | 3 | 1 | 10–12 dégâts, −2 PM (1 tour) | 1/tour | Attack 3 (à confirmer en jeu) | — |
| 3 | Pétard | 2 | 1–4, ligne de vue | 6–8 dégâts, repousse de 2 (collision = dégâts de poussée habituels) | 2/tour | Attack 1 (lancer) | pétard qui tourne (dessiné) / petite explosion (feu du pack, réduite) |
| 4 | Fumigène | 3 | 2–5, sans ligne de vue | nuage 3×3 centré sur la case visée, 1 tour (règles ci-dessous) | 1/tour, recharge 3 | Attack 1 (lancer) | bouffées grises dessinées par le code (`SmokeView`) |

Retirés du premier jet : Estoc, Lancer de hache, Backflip. Leurs données (`data/spells/gobelin_estoc|hache|backflip.tres`), la hache
(`assets/effects/axes/`) et les icônes restent dans le dépôt, inutilisées, pour d'autres personnages (orcs, gobelins ennemis).

## Règles du fumigène (validées le 23/11)

1. **Zone** : carré 3×3 centré sur la case visée (portée 2 à 5, pas de ligne de vue nécessaire). Les obstacles pleins n'en gardent pas.
2. **Durée** : 1 tour. Posé pendant le tour du gobelin, il disparaît au début de son tour suivant : il couvre tout le tour de l'ennemi.
3. **Ralentissement** : un combattant qui **commence son tour** dans le nuage a −2 PM pour ce tour (`CombatState.SMOKE_PM_MALUS`).
4. **Aveugle (dedans)** : depuis une case du nuage, aucun sort qui demande une ligne de vue (même au contact). Restent permis : les sorts
   sans ligne de vue (Fumigène...) et ceux sur sa propre case. Vaut pour tout le monde, gobelin compris.
5. **Écran (dehors)** : une case du nuage entre le lanceur et la cible coupe la ligne de vue (on ne compte pas les extrémités : une cible
   *dans* le nuage reste visible depuis une case voisine hors du nuage).
6. Recharge de 3 tours : un nuage tous les trois tours au mieux (un tour sur trois, l'ennemi joue dans la fumée).

**Risque d'équilibrage** : un ennemi de mêlée pris dans le nuage ne peut plus frapper tant qu'il n'en est pas sorti, avec −2 PM pour en
sortir. Leviers si c'est trop fort : ralentissement, recharge, ou permettre de frapper au contact.

## Mise en œuvre (code)

- `EffectData.Kind.STEAL_PA` (vol de PA) et `SMOKE` ; `SpellData.AreaShape.SQUARE` (`area_size` = rayon, 1 → 3×3).
- `CombatState` : `smokes`, signaux `smoke_added` / `smoke_removed`, `is_smoked`, `smoke_blocks_view`, `has_view` (grille + fumée), expiration au
  début du tour du lanceur, ralentissement au début du tour.
- IA : vol de PA et fumigène notés dans `score_cast`, se tenir dans la fumée pénalisé dans `position_score` (l'ennemi aveuglé cherche à en sortir).
- Affichage : `scripts/view/smoke_view.gd` (sprites générés par le code), branché dans `main.gd`.
- Tests : `_test_steal_pa`, `_test_square_area`, `_test_smoke`, `_test_goblin_ai_finishes` dans `tests/test_core.gd`.

**Intentions** : Vol à la tire (3 PA, +1 PA rendu) puis Coup bas (3 PA) puis un Pétard (2 PA) au contact, ou un Fumigène sur l'ennemi puis des
Pétards pour le garder à distance pendant qu'il est aveugle et ralenti.

## Mise en place (23/11)

Créé : assets (`assets/characters/gobelin/`, `assets/effects/axes/`, icônes, portrait), données (`data/classes/gobelin.tres`,
`data/sprites/gobelin.tres`, 4 sorts, `data/effects/hache.tres`), ajouté à `CLASS_PATHS`. Échelle d'affichage 1,4 (le Goblin 01 mesure
≈ 34 px contre ≈ 57 px pour l'Archer). Pieds mesurés sur les planches sans ombre (Idle 70 % / Walk 30 %).
**Non vérifié** (pas de Godot sur la machine de travail) : tests `test_core.gd`, rendu en jeu (pieds, échelle, lignes de direction),
équilibrage.

## Équilibrage

**Premier jet (23/11, 1600 combats)** : le Gobelin perd 100 % de ses duels (0 % contre le Guerrier, l'Archer, le Mage de feu et
le Chevalier maudit), combats de 4,6 à 6,5 tours. Un 0 % partout vient du rôle, pas des chiffres.
Cause (lecture de `ai_brain.gd`, non mesurée) : avec `preferred_range = 2`, l'IA le joue en tireur : elle pénalise le corps à corps
(−6 sous 2 cases, −4 s'il est à portée de déplacement d'un ennemi) et le fait fuir, alors que son meilleur sort est l'Estoc (portée 1,
13–15). Il se rabat donc sur le Lancer de hache (9–11, plus faible que la Flèche) et inflige presque rien.
**Correction** : `preferred_range = 1` (joué comme un combattant de mêlée). Effet de bord à surveiller : pour une classe de mêlée l'IA
note le Backflip comme un bond *vers* l'ennemi (comme la Charge), pas comme une retraite.
Les chiffres des sorts n'ont pas été modifiés. À refaire : `tests/balance_matrix.gd -- personnage=Gobelin`.

### Pillard, premier jet (23/11, 1600 combats, victoires du Gobelin)

Chiffres : PV 110, Vol 6–8 (recharge 2), Coup bas 8–10, Pétard 5–7.
Archer 62 % (Prairie 70, désert 65, barrage 65, village 75, **lac 35**), Chevalier maudit 29 % (lac 49, village 56, désert 25, prairie 14,
barrage 4), Mage de feu 9 %, Guerrier 1 % ; moyenne 25 %, combats de 5,5 à 6,6 tours, aucun combat sans fin.
Lecture : déficit de puissance brute. Le Guerrier fait ≈ 40 par tour (Coup d'épée 18–22 ×2, 150 PV), le Gobelin ≈ 20 ; ses effets de contrôle
(vol de PA, −2 PM, nuage) n'y suffisent pas. Archer trop faible sur le lac (l'eau gêne le gobelin, pas les flèches).

**Deuxième jet** : PV 120, Vol à la tire 8–10 et recharge 1 (utilisable chaque tour : −1 PA permanent pour l'ennemi, coût net de 2 PA pour
nous), Coup bas 10–12, Pétard 6–8. Le Fumigène (recharge 3, décidée avec l'utilisateur) et les règles du nuage ne changent pas.
À mesurer. Si Guerrier et Mage restent très bas : regarder l'IA (garder la distance avec 4 PM, enchaîner Fumigène puis Pétards) avant les chiffres.

### Pillard, deuxième jet mesuré (23/11, 20 000 combats, matrice complète)

Victoires du Gobelin : Archer 83 %, Chevalier maudit 50 %, Guerrier 19 %, Mage de feu 20 % ; moyenne 43 %.
Il bat les personnages qui ont du mal à fuir et perd contre les deux gros frappeurs. Cartes : Mage de feu 97 % de défaites sur le lac.

**Troisième jet** (mesuré sur la prairie, 4000 combats : Guerrier 34 % au lieu de 20 %, Mage de feu 41 % au lieu de 17 %, Chevalier 62 %) : PV 135 (135 = Mage de feu). Les autres chiffres ne bougent pas, pour voir si les PV seuls rapprochent le duel du Guerrier et du Mage.

**Troisième jet mesuré** (4000 combats, toutes cartes) : 57 % de victoires en moyenne. Archer 88 %, Chevalier maudit 61 %, Guerrier 38 %, Mage de feu 43 %.
Dans la cible, sauf contre l'Archer (trop facile ; l'Archer est retouché, pas le Gobelin). Lac : défaite quasi sûre contre le Mage de feu (9 %).
