# Gobelin

**Identité** : harceleur fragile et mobile ; frappe au corps à corps ou de loin, déséquilibre l'adversaire
(lui vole des PA) et se dégage d'un salto arrière. Servira plus tard d'ennemi de campagne / PVE.
**Skin** : Goblin 01 (pack *2D Orcs and Goblins - TopDown - V1.0*, dossier `Combined/Goblin 01`, version sans ombre dans
`Seperate shadows and effects/Goblin 01`). Gobelin vert armé d'une hachette.
**Distance préférée (IA)** : 2 (à confirmer à l'équilibrage).

**Stats** (provisoires) : PV 110 / PA 6 / PM 4

**Animations de base** : idle = Idle, walk = Walk, hit = TakeDamage 1, die = Die 1 (Die 2 en variante)

| # | Sort | PA | Portée | Effets | Limites | Animation | Projectile / impact |
|---|------|----|--------|--------|---------|-----------|---------------------|
| 1 | Estoc | 3 | 1 | 13–15 dégâts | 2/tour | Attack 2 (coup d'estoc) | — |
| 2 | Lancer de hache | 3 | 2–5, ligne de vue | 9–11 dégâts | 2/tour | Attack 1 (à confirmer en jeu) | hache qui tourne (dessinée, `data/effects/hache.tres`) / — |
| 3 | Vol à la tire | 3 | 1 | 6–8 dégâts, −1 PA (1 tour) | 1/tour, recharge 2 | Attack 4 (bond d'attaque) | — |
| 4 | Backflip | 2 | 2–3, en ligne, case libre | bond sur la case | 1/tour, recharge 2 | BackFlip 1 | — |

**Intentions** : 2 Estocs (6 PA) ≈ 28 dégâts/tour au contact, plus léger de loin (Lancer de hache ≈ 10).
Contre un ennemi qui approche : Backflip pour se dégager, Lancer de hache pour continuer à frapper.
Vol à la tire pour priver l'ennemi d'un PA et casser son tour.

## Points à valider

- **Vol à la tire** : décidé avec l'utilisateur : dégâts + −1 PA à la cible (effets existants `DAMAGE` + `MOD_PA`), sans code.
  Variante « vrai vol » (le gobelin gagne le PA) écartée : demanderait un nouvel effet ; vol de vie écarté (Pacte de sang du Chevalier).
- **Lancer de hache** (ex-Jet de couteau, renommé à la demande de l'utilisateur) : le pack n'a pas de projectile de hache ;
  la hache est dessinée par script (15 images, rotation en vol). À juger en jeu (taille, vitesse, sens de rotation).
- **Animations des sorts** : choisies d'après les planches (Attack 2 = estoc, Attack 4 = bond avec impact, BackFlip = salto) ;
  à vérifier en jeu (ordre, sens du salto par rapport à la direction du bond).
- **Backflip** : le salto va vers l'arrière du personnage. Le bond du jeu va vers la case ciblée : vérifier que le sprite
  regarde bien l'adversaire pendant le saut (sinon, inverser la direction d'affichage pour ce sort).
- **Portrait** : à recadrer sur la frame 0 d'Idle. **Voix** : aucune pour l'instant. **Description** : à rédiger.

## Mise en place (23/11)

Créé : assets (`assets/characters/gobelin/`, `assets/effects/axes/`, icônes, portrait), données (`data/classes/gobelin.tres`,
`data/sprites/gobelin.tres`, 4 sorts, `data/effects/hache.tres`), ajouté à `CLASS_PATHS`. Échelle d'affichage 1,4 (le Goblin 01 mesure
≈ 34 px contre ≈ 57 px pour l'Archer). Pieds mesurés sur les planches sans ombre (Idle 70 % / Walk 30 %).
**Non vérifié** (pas de Godot sur la machine de travail) : tests `test_core.gd`, rendu en jeu (pieds, échelle, lignes de direction),
équilibrage.

## Équilibrage

À faire (critères dans `docs/creation_personnage.md`) : `tests/balance_matrix.gd`.
