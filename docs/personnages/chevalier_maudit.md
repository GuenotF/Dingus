# Chevalier maudit

**Identité** : chevalier noir au corps à corps qui force le contact : il **attire** sa cible, la **ralentit**,
**ponctionne** sa vie et lui retire des PA. Il se sacrifie volontiers (Pacte de sang) pour frapper plus.
**Skin** : Death Knight (pack *2D HD Character pack 1*, dossier `7DeathKnight`). **Distance préférée (IA)** : 1.

**Stats** : PV 120 / PA 6 / PM 3

**Animations** : idle = Idle, walk = Walk, hit = TakeDamage, die = Die, melee = Melee, cast = CastSpell,
curse = Special2, pact = Special1

| # | Sort | PA | Portée | Effets | Limites | Animation | Projectile / impact |
|---|------|----|--------|--------|---------|-----------|---------------------|
| 1 | Lame sombre | 3 | 1 | 14–17 dégâts, **vol de vie** (50 % des dégâts retirés) | 2/tour | Melee | — |
| 2 | Chaîne infernale | 3 | 2–6, en ligne, ligne de vue | 4–6 dégâts, attire de 5 cases, −2 PM (1 tour) | 1/tour, recharge 2 | CastSpell | trait de mort / — |
| 3 | Malédiction | 2 | 1–4, ligne de vue | 4–6 dégâts, −2 PA (1 tour) | 1/tour, recharge 3 | Special2 | — / explosion sombre au sol |
| 4 | Pacte de sang | 1 | sur soi | −12 PV, +3 PA | 1/tour, recharge 3 | Special1 | — / explosion sombre au sol |

**Code ajouté** : effet `DRAIN` (vol de vie, `CombatState.DRAIN_RATIO` = 0,5), avec aperçu du soin au survol.
Le Pacte de sang combine des effets existants (DAMAGE sur soi + MOD_PA).

**Intentions** : la Chaîne rattrape les tireurs (attire, puis −2 PM pour les empêcher de repartir),
puis 2 Lames sombres par tour (≈ 31 dégâts, ≈ 15 PV rendus). Le Pacte s'ouvre au contact (−12 PV pour
+2 PA nets, de quoi lancer une Lame de plus). Malédiction coupe le tour adverse en deux.

## IA

- Le Pacte de sang est lancé **avant de frapper** et seulement si une attaque est possible depuis la case
  (jamais « pour rien »), s'il reste plus de 3 fois son coût en PV et assez de PA après gain.
- Vol de vie : compte dans le score d'un sort, davantage quand le lanceur est blessé.
- Au corps à corps, la **position** se juge au chemin à parcourir, pas à vol d'oiseau : sans cela, un rocher
  entre deux combattants donnait l'impression d'être déjà au contact et l'IA restait plantée (des combats
  sans fin, surtout Guerrier / Chevalier sur la Prairie). Ce changement touche aussi le Guerrier.

## Équilibrage

Le gros levier est la **mobilité** : à 4 PM le Chevalier rattrape tout le monde (98 % contre le Mage, qui ne
peut plus garder ses distances), à 3 PM il ne rattrape plus rien (88 % de défaites contre le Mage, 100 % contre
l'Archer) ; les PV et les dégâts bougent peu ces écarts. La solution retenue : 3 PM et une **Chaîne** (attire de 5,
−2 PM, recharge 2) comme outil de rattrapage.
Réglages essayés : PV 105 à 140, Lame 12–19, vol de vie 35 % / 50 %, Chaîne recharge 2 ou 3 et −1 ou −2 PM,
Malédiction −1 ou −2 PA (presque sans effet), PM 3 ou 4.

Résultats (60 combats par carte, victoires du Chevalier en premier) :

| Adversaire | Prairie | Le lac | Place du village | Tours moy. | Sans fin |
|---|---|---|---|---|---|
| Guerrier | 63 % | 45 % | 52 % | 6 | 0 |
| Mage de feu | 49 % | 0 % | 47 % | 6 | 0 |
| Archer | 73 % | 26 % | 75 % | 7 | 0 |

**Points ouverts**
- **Chevalier contre Archer ≈ 75 % sur terre** : trop fort. La Chaîne (−2 PM) cloue l'Archer (1 PM restant) ; avec
  −1 PM le résultat s'inverse complètement (100 % pour l'Archer). Le réglage est un seuil, pas une pente.
- **Le lac** : l'eau bloque le Chevalier et pas les sorts à distance (0 % contre le Mage). Même défaut de carte
  que l'Archer contre le Guerrier.
- **Guerrier contre Mage de feu** passe de 56 / 43 à 67 / 32 sur la Prairie à cause du changement d'IA de
  corps à corps (le Guerrier rattrape mieux), à surveiller.
