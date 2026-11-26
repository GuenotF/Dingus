# PNJ — Gobelin chapardeur (ennemi de campagne)

**Non jouable** : listé dans `Roster.ENEMY_PATHS` (`scripts/core/roster.gd`), pas dans `CLASS_PATHS` (absent du menu 1v1, de la démo de l'écran titre
et de la matrice d'équilibrage). Joué uniquement par l'IA, en campagne.

**Identité** : petit gobelin de base, premier adversaire de la campagne (combat d'introduction, volontairement facile).
**Skin** : Goblin 13 (pack *2D Orcs and Goblins - TopDown - V1.0*, version `Combined`) : tunique brune, gourdin.
**Stats** : PV 90 / PA 6 / PM 3. **Distance préférée (IA)** : 1.

**Animations** : idle = Idle, walk = Walk, hit = TakeDamage 1, die = Die 1, attack1 = Attack 1 (coup de haut en bas),
attack2 = Attack 2 (coup de côté, sert de lancer).

| # | Sort | PA | Portée | Effets | Limites | Animation | Projectile |
|---|------|----|--------|--------|---------|-----------|------------|
| 1 | Coup de gourdin | 3 | 1 | 10–13 dégâts | 2/tour | Attack 1 | — |
| 2 | Jet de caillou | 3 | 2–4, ligne de vue | 6–8 dégâts | 2/tour | Attack 2 | caillou qui tourne (dessiné par script) |

**Difficulté visée** : le héros gagne environ 80 à 90 % des combats. Équilibrage léger : contrôle de cohérence seulement,
à reprendre si le combat s'avère trop facile ou trop dur en jeu.
