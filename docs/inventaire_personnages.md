# Inventaire des personnages

À tenir à jour quand on ajoute un personnage ou un nouveau pack (voir aussi `docs/creation_personnage.md`).
Dernière mise à jour : 2026-11-23.

## Personnages jouables (5)

Liste dans `CLAUDE.md`/`scripts/game_config.gd` (`CLASS_PATHS`). PA 6 pour tous sauf mention ; PM 3 par défaut.

| Personnage | Skin (pack, dossier) | Rôle | PV | PM | Distance IA | Sorts | Voix | Fiche |
|---|---|---|---|---|---|---|---|---|
| Guerrier | *2D HD Character Knight* (`assets/characters/knight/`) | corps à corps, repousse | 150 | 3 | – | Coup d'épée, Charge, Repousser, Cri | oui (*Warrior Voice Pack*) | pas de fiche détaillée |
| Mage de feu | *2D HD Character pack 1* : `3Wizard` | distance, gros dégâts, fragile | 135 | 4 | 4 | Flammèche, Boule de feu, Pluie de feu, Nova de flammes | non | `docs/personnages/mage_de_feu.md` |
| Archer | *2D HD Character pack 1* : `2Archer` | distance, ralentit et repousse | 125 | 3 | 5 | Flèche, Flèche entravante, Flèche de recul, Roulade | non | `docs/personnages/archer.md` |
| Chevalier maudit | *2D HD Character pack 1* : `7DeathKnight` | corps à corps, attire, vole la vie | 120 | 3 | 1 | Lame sombre, Chaîne infernale, Malédiction, Pacte de sang | non | `docs/personnages/chevalier_maudit.md` |
| Gobelin | *2D Orcs and Goblins - TopDown - V1.0* : `Goblin 01` (`assets/characters/gobelin/`) | pillard : vole des PA, enfume, repousse | 120 | 4 | 1 | Vol à la tire, Coup bas, Pétard, Fumigène | non | `docs/personnages/gobelin.md` |

Équilibrage actuel (rapport du 23/11, 20 parties par côté et par carte) : le Chevalier maudit domine (≈ 62 % de victoires
contre les autres), Archer 48 %, Mage de feu 47 %, Guerrier 44 %. Détails : `tests/balance_matrix.gd`.

## Skins disponibles non utilisés

Dossier `Characters/2D HD Character pack 1 V1.2/` (sur le PC de l'utilisateur, hors dépôt). Chaque skin a environ 30 animations
(Idle, Walk, Run, TakeDamage, Die, Rolling, Slide, FrontFlip, Kick, Special1/2, CastSpell…).

| Dossier | Jeu d'attaques | Remarque |
|---|---|---|
| `1Knight` | Melee, Melee2, MeleeSpin, Pummel, boucliers | type chevalier (corps à corps) |
| `4Paladin` | idem `1Knight` | type chevalier (corps à corps) |
| `5CamoArcher` | Attack1–3, QuickShot, AttackRun | type archer (distance) |
| `6Mage` | idem `5CamoArcher` | type mage (distance) |
| `8DarkLord` | idem `5CamoArcher` | à voir en jeu |
| `9Longbow` | idem `5CamoArcher` | type archer (distance) |

Aussi disponibles : projectiles (`Characters/Projectiles/Projectiles - 2D HD Character pack 1`), *Warrior Voice Pack* (voix du Guerrier).
Les descriptions d'apparence des skins non utilisés sont à compléter en les voyant en jeu.

## Pack Orcs et gobelins (`Characters/2D Orcs and Goblins - TopDown - V1.0/`, hors dépôt)

Pour les ennemis de campagne / PVE. Deux versions : `Combined` (avec ombres et effets) et `Seperate shadows and effects`
(planches sans ombre, plus dossiers `Shadows`, `Effects`, `Outlines`). Même format que le pack 1 : planches 1920×1024,
15 images × 8 directions de 128×128. **Auteur et licence : à retrouver** (comme pour les autres packs).
Contenu : 17 gobelins (`Goblin 01` à `17`), 12 orcs (`Orc 01` à `12`), 2 animaux (`Animal 1`, `2`).

| Dossier | Utilisation / animations (vérifiées sur les dossiers cités) |
|---|---|
| `Goblin 01` | **utilisé** (Gobelin). Gobelin vert à la hachette. Attack 1-4, Run Attack, Block, BackFlip 1, Roll 1, Slide 1, Strafe, Crouch, Taunt, Die 1-2, TakeDamage 1 |
| `Goblin 14`, `Goblin 17` | même jeu que le 01 (le 17 a une 5e attaque) |
| `Goblin 05` | 4 attaques, sans Block ni BackFlip |
| `Goblin 02`, `Goblin 08` | 6 attaques + Attack Run ; fichiers lourds (effets ?), à regarder en jeu |
| `Goblin 11` | gobelin monté sur un loup : 3 attaques, Attack Run 1-2, Eating (jeu d'animations des animaux) |
| autres gobelins, orcs, animaux | non inspectés |

Projectiles : aucun dans ce pack ; la hache du Gobelin (`assets/effects/axes/hache.png`) est dessinée par script (`tools/` : voir historique du commit).

## Pour ajouter un personnage
Suivre `docs/creation_personnage.md`, puis ajouter une ligne dans le tableau ci-dessus (et retirer le skin de la liste des non utilisés).
