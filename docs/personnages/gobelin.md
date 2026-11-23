# Gobelin — le Pillard (refonte en attente de validation)

> État du code : le jeu contient encore le premier jet (Estoc, Lancer de hache, Vol à la tire, Backflip). Cette fiche décrit la refonte
> « Pillard » décidée le 23/11 ; rien n'est codé tant que l'utilisateur n'a pas validé les règles ci-dessous.

**Identité** : pillard fourbe et fragile. Il n'écrase pas l'adversaire, il l'épuise : lui vole des PA, le ralentit, l'aveugle dans la fumée,
le repousse à coups de pétard. Servira plus tard d'ennemi de campagne / PVE (et se marie bien avec les coffres à bonus).
**Skin** : Goblin 01 (pack *2D Orcs and Goblins - TopDown - V1.0*). **Distance préférée (IA)** : 1 (à réviser après la refonte).
**Stats** (provisoires) : PV 110 / PA 6 / PM 4

**Animations de base** : idle = Idle, walk = Walk, hit = TakeDamage 1, die = Die 1

| # | Sort | PA | Portée | Effets | Limites | Animation | Projectile / impact |
|---|------|----|--------|--------|---------|-----------|---------------------|
| 1 | Vol à la tire | 3 | 1 | 6–8 dégâts ; la cible perd 1 PA (1 tour) **et le gobelin gagne 1 PA tout de suite** | 1/tour, recharge 2 | Attack 4 (bond d'attaque) | — |
| 2 | Coup bas | 3 | 1 | 8–10 dégâts, −2 PM (1 tour) | 1/tour | Attack 3 (à confirmer en jeu) | — |
| 3 | Pétard | 2 | 1–4, ligne de vue | 5–7 dégâts, repousse de 2 (collision = dégâts de poussée habituels) | 2/tour | Attack 1 (lancer) | pétard lancé (à dessiner) / explosion (effet de feu existant) |
| 4 | Fumigène | 3 | 2–5, sans ligne de vue | nuage 2×2 cases pendant 1 tour : ralentit, aveugle (dedans), fait écran (voir règles) | 1/tour, recharge 2 | Attack 1 (lancer) | nuage gris (à dessiner) |

Retirés par rapport au premier jet : Estoc, Lancer de hache, Backflip (le pétard et le Coup bas donnent la distance ; plus de retraite).
Assets déjà créés mais inutilisés après la refonte : planches `attack2` et `backflip`, projectile `hache`, icônes Estoc / hache / Backflip.

## Règles du fumigène (à valider)

Demandé : ralentit ; bloque la ligne de vue ; aveugle totalement un combattant qui est dedans ; fait écran pour un combattant qui est
dehors ; 1 tour ; carré de 2 cases de côté ; recharge 2. Interprétation retenue, à corriger si besoin :
1. **Zone** : carré 2×2 dont la case visée est le coin haut-gauche (cases x..x+1, y..y+1). Il peut empiéter sur obstacles et combattants.
2. **Durée** : posé pendant le tour du gobelin, il dure jusqu'au début du tour suivant du gobelin, donc il couvre tout le tour de l'ennemi.
3. **Ralentissement** : un combattant dans le nuage au début de son tour a −2 PM ce tour-là (le gobelin aussi s'il y reste).
4. **Aveugle (dedans)** : depuis une case du nuage, on ne peut lancer aucun sort qui demande une ligne de vue (même au contact). Restent
   permis : les sorts sans ligne de vue (ex. Pluie de feu, Fumigène) et les sorts sur soi. Vaut pour tout le monde, gobelin compris.
5. **Écran (dehors)** : une case du nuage située entre le lanceur et la cible coupe la ligne de vue (comme un obstacle). Une cible *dans*
   le nuage reste visible depuis une case voisine hors du nuage (on ne compte que les cases intermédiaires).
6. **Cumul** : un nouveau nuage pendant que l'ancien dure ne s'empile pas (la recharge de 2 l'empêche de toute façon).

Conséquences à surveiller à l'équilibrage : un ennemi de mêlée pris dans le nuage ne peut plus frapper tant qu'il n'en est pas sorti, avec
−2 PM pour en sortir : le sort peut neutraliser presque tout un tour. Si c'est trop fort : réduire la durée, le ralentissement, ou
laisser frapper au contact.

## Ce que ça demande en code (estimation)

- **Nouvel effet « vol de PA »** (cible −1 PA, lanceur +1 PA immédiat) + évaluation par l'IA. Petit.
- **Nouvelle forme de zone** carré 2×2 (`SpellData.AreaShape`). Petit.
- **Nuages de fumée** dans `CombatState` (cases + durée), branchés sur la ligne de vue (`cells_in_range_from`) et sur le ralentissement
  de début de tour, sans toucher à `view/`. Moyen.
- **IA** : valoriser le fumigène (enfermer un ennemi de mêlée, se cacher d'un tireur), éviter d'y entrer soi-même ; le Pétard comme
  outil de dégagement. Moyen.
- **Affichage** : nuage (sprites dessinés par script, comme la hache), pétard, explosion ; indicateur sur un combattant aveuglé. Moyen.
- **Tests** : nuage et ligne de vue, aveuglement, durée, ralentissement, vol de PA, zone 2×2.

**Intentions** : 6 PA = Vol (3, +1 PA rendu) puis Coup bas (3) puis un Pétard (2) ≈ 3 sorts par tour au contact ; un tour sur deux Fumigène sur
l'ennemi puis Pétards pour le garder à distance pendant qu'il est aveugle.

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
