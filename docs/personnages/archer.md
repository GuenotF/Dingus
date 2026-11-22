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
