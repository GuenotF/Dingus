# Mage de feu

**Identité** : mage à distance orienté dégâts ; fragile, frappe fort, touche derrière les obstacles,
repousse ce qui s'approche. **Skin** : Wizard (pack *2D HD Character pack 1*). **Distance préférée (IA)** : 4.

**Stats** : PV 135 / PA 6 / PM 4

**Animations de base** : idle = Idle, walk = Walk, hit = TakeDamage, die = Die

| # | Sort | PA | Portée | Effets | Limites | Animation | Projectile / impact |
|---|------|----|--------|--------|---------|-----------|---------------------|
| 1 | Flammèche | 2 | 1–5, ligne de vue | 8–10 dégâts | 3/tour | Attack2 | trait de feu / — |
| 2 | Boule de feu | 4 | 3–7, ligne de vue | 18–22 dégâts | 1/tour | Special2 | boule de feu / petite explosion |
| 3 | Pluie de feu | 4 | 3–6, sans ligne de vue | croix : 9–11 dégâts | 1/tour, recharge 2 | CastSpell | — / zone de feu au sol |
| 4 | Nova de flammes | 4 | sur soi | 4 cases autour (pas le lanceur) : 12–15 dégâts, repousse de 2 | recharge 2 | Special1 | — / zone de feu au sol |

**Intentions** : Boule de feu + Flammèche (6 PA) ≈ 29 dégâts/tour à distance ; Pluie de feu par-dessus les
obstacles ; Nova pour repousser le Guerrier au contact.

## Équilibrage

Écarts par rapport au premier jet (90 PV / 3 PM, Flammèche 6–8, Boule 15–19, Nova 5 PA repousse 1) :
le Guerrier gagnait 100 % des combats. Corrections :
1. **IA** : un personnage à distance évite de finir son tour à portée de déplacement d'un ennemi.
2. **Chiffres** : PM 3 → 4, Flammèche 8–10, Boule 18–22, Nova 4 PA et repousse de 2.
3. **Durée des combats** : PV du Mage 135 et du Guerrier 105 → 150 (combats de 4 à 6 tours).

Résultats (80 combats par carte) :

| Carte | Guerrier | Mage de feu | Tours moy. | 1er joueur gagne |
|---|---|---|---|---|
| Prairie | 52 % | 47 % | 5,9 | 55 % |
| Le lac | 53 % | 46 % | 6,1 | 41 % |

Après la ligne de vue permissive en diagonale (passer par le coin d'un obstacle ne bloque plus) :

| Carte | Guerrier | Mage de feu | Tours moy. | 1er joueur gagne |
|---|---|---|---|---|
| Prairie | 56 % | 43 % | 5,8 | 51 % |
| Le lac | 48 % | 51 % | 6,1 | 43 % |
