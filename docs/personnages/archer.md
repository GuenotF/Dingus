# Archer

**Identité** : tireur à longue portée ; régulier plutôt qu'explosif, ralentit et repousse ce qui
l'approche, se dégage d'une roulade. **Skin** : Archer (pack *2D HD Character pack 1*, dossier `2Archer`).
**Distance préférée (IA)** : 5.

**Stats** : PV 125 / PA 6 / PM 3

**Animations de base** : idle = Idle, walk = Walk, hit = TakeDamage, die = Die

| # | Sort | PA | Portée | Effets | Limites | Animation | Projectile / impact |
|---|------|----|--------|--------|---------|-----------|---------------------|
| 1 | Flèche | 3 | 2–8, ligne de vue | 13–15 dégâts | 2/tour | Attack1 | flèche / — |
| 2 | Flèche entravante | 3 | 2–4, ligne de vue | 6–8 dégâts, −2 PM (1 tour) | 1/tour, recharge 2 | Attack2 | flèche / éclat de glace au sol |
| 3 | Flèche de recul | 3 | 1–3, en ligne, sur un ennemi | 5–7 dégâts, repousse de 2 | 1/tour | Attack3 | flèche / — |
| 4 | Roulade | 2 | 2–3, en ligne, case libre | bond sur la case | recharge 2 | Rolling | — |

**Intentions** : 2 Flèches (6 PA) ≈ 28 dégâts/tour de loin. Contre un corps à corps qui approche :
Entravante (un tour sur deux) pour le tenir à distance, Recul s'il arrive au contact, Roulade pour s'échapper.

## Équilibrage

Premier jet : PV 130, Flèche 10–12, Entravante portée 2–6 −2 PM sans recharge.
Archer 97 % contre le Guerrier (bloqué en permanence), 0 % contre le Mage de feu (course aux dégâts perdue).

Ce qui a été changé :
1. **IA** : ralentir un ennemi au corps à corps vaut double pour un personnage à distance
   (sinon l'IA préférait toujours deux Flèches et n'entravait jamais) ; un tireur ne fait plus de
   Roulade « pour rien », seulement pour s'éloigner d'un ennemi trop proche.
2. **Flèche** 10–12 → 13–15 : sans ça le Mage gagne la course aux dégâts d'un tour.
3. **Entravante** : recharge 2 (un tour sur deux) et portée 2–6 → 2–4 : le Guerrier n'est plus
   bloqué en permanence, et il faut le laisser approcher pour l'entraver.
4. **PV** 130 → 125.

Résultats (80 combats par carte) :

| Carte | Archer | Guerrier | Tours moy. | 1er joueur gagne |
|---|---|---|---|---|
| Prairie | 48 % | 51 % | 6,7 | 66 % |
| Le lac | 85 % | 15 % | 7,1 | 47 % |
| Place du village | 47 % | 52 % | 5,9 | 42 % |

| Carte | Archer | Mage de feu | Tours moy. | 1er joueur gagne |
|---|---|---|---|---|
| Prairie | 41 % | 58 % | 5,2 | 41 % |
| Le lac | 50 % | 50 % | 5,8 | 52 % |
| Place du village | 53 % | 46 % | 5,3 | 26 % |

**Point ouvert** : sur *Le lac*, l'eau bloque le Guerrier mais pas les flèches, et l'Archer garde
facilement ses distances (85 %). C'est un avantage de carte assumé pour l'instant ; à revoir si on
veut des cartes neutres (moins d'eau, ou des obstacles qui coupent la ligne de vue au bord du lac).
Les écarts sont très sensibles aux seuils de mise à mort (±1 dégât ou ±5 PV peut faire basculer
de 20 à 80 %), d'où des réglages fins.

**Mise à jour** (IA de corps à corps révisée avec le Chevalier maudit) : Archer / Guerrier = 46 / 53 ur la Prairie, 85 / 15 ur le lac, 49 / 50 ur la Place du village.

### Équilibrage (23/11, 20 000 combats, matrice complète)

Victoires de l'Archer : Chevalier maudit 28 %, Gobelin 17 %, Guerrier 54 %, Mage de feu 51 % ; moyenne 38 %.
Il tient contre les tireurs et les lourds, mais les personnages rapides le rattrapent. Cartes : très fort sur le lac contre le Guerrier (90 %).

**Deuxième jet** : 4 PM (au lieu de 3), Flèche 14–16 (au lieu de 13–15). Mesuré sur la prairie (4000 combats) : trop fort, 100 % contre le
Chevalier maudit (30 % avant) et 78 % contre le Guerrier (45 % avant). Les 4 PM lui permettent de fuir sans fin les personnages à 3 PM.

**Troisième jet** : retour à 3 PM, Flèche 14–16 conservée, PV 130 (au lieu de 125). À mesurer.

**Troisième jet mesuré** (4000 combats, toutes cartes) : 43 % de victoires en moyenne. Chevalier maudit 33 %, Gobelin 12 %, Guerrier 64 %, Mage de feu 65 %.
Il domine les tireurs et les lourds mais ne retient pas les rapides.

**Quatrième jet** : Flèche entravante utilisable chaque tour (recharge 2 → 1) : −2 PM à répétition freine le Gobelin (4 PM) et le Chevalier. À mesurer.

**Quatrième jet mesuré** (4000 combats) : 51 % de victoires en moyenne. Chevalier maudit 40 %, Gobelin 14 %, Guerrier 85 %, Mage de feu 65 %.
Entravante à chaque tour aide contre le Chevalier (33 → 40 %) mais écrase le Guerrier (64 → 85 %) et ne change rien contre le Gobelin (12 → 14 %) :
le problème avec le Gobelin vient de lui (vol de PA à chaque tour, fumigène), pas de l'Archer. Réglage laissé tel quel ; le Gobelin et le Guerrier sont retouchés.
