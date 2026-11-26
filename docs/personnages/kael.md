# Kael — le Paladin

**Identité** : paladin loyal bon, au corps à corps. Il **tient** : il se protège, se soigne, **cloue** son adversaire sur place
et le punit. Force : la résistance. Faiblesse : la mobilité (aucun bond). Doit être jouable contre tous les personnages.
**Skin** : Paladin (pack *2D HD Character pack 1*, dossier `4Paladin`). **Distance préférée (IA)** : 1.
**Stats** : PV 136 / PA 6 / PM 3
**Voix** : aucune pour l'instant.
**Description (menu)** : « Corps à corps : se protège, entrave et châtie »

**Animations de base** : idle = Idle, walk = Walk, hit = TakeDamage, die = Die
(sorts : melee = Melee, consecrate = Special2, pray = ShieldBlockStart, guard = CastSpell)

| # | Sort | PA | Portée | Effets | Limites | Animation | Projectile / impact |
|---|------|----|--------|--------|---------|-----------|---------------------|
| 1 | Châtiment divin | 3 | 1–2, ligne de vue | 16–19 dégâts ; **+6 sur une cible entravée** | 2/tour | Melee | — / éclat doré |
| 2 | Entrave sacrée | 3 | 1–5, ligne de vue | la cible perd tous ses PM à son prochain tour, sans dégâts | 1/tour, recharge 3 | Special2 | — / lien doré au sol |
| 3 | Imposition des mains | 3 | sur soi | soin 24–28 | 1/tour, recharge 3 | ShieldBlockStart | — / halo doré |
| 4 | Bouclier de la foi | 3 | sur soi | bouclier de 24 jusqu'au début de son prochain tour | 1/tour, recharge 2 | CastSpell | — / éclat doré |

Valeurs actuelles (`data/` fait foi). Premier jet avant simulation : PV 140, soin 20–24, bouclier 20.

## Règles

### Entrave sacrée
1. La cible commence son prochain tour avec **0 PM**. L'effet disparaît à la fin de ce tour.
2. Les **bonds restent permis** (Charge, Roulade...), comme les attaques.
3. Pousser ou attirer une cible entravée reste possible.
4. Un bonus de PM reçu pendant ce tour s'applique normalement.

### Synergie du Châtiment
- Le bonus de +6 (22–25 au total) ne vaut que contre une cible sous **Entrave sacrée**. Les autres retraits de PM
  (Chaîne infernale, Coup bas, fumée) ne le déclenchent pas.
- L'Entrave s'arrête à la fin du tour de la cible. La synergie ne joue donc **que dans le tour où Kael la pose** :
  Entrave (3 PA) puis Châtiment (3 PA), à portée 1–2. Elle revient au mieux un tour sur trois.
- Ce combo fait 22–25 dégâts, contre 32–38 pour deux Châtiments : on échange des dégâts contre le contrôle.
- L'aperçu au survol et l'infobulle du sort affichent le bonus.

### Bouclier de la foi
1. Réserve de **PV temporaires** : elle est consommée avant les PV.
2. Elle absorbe **tous** les dégâts, collisions de poussée comprises.
3. Ce qui reste disparaît au début du tour suivant de Kael. Les boucliers ne se cumulent pas.
4. Vol de vie : le lanceur ne récupère rien sur la part absorbée.
5. Le bouclier est visible sur le combattant et sa valeur est lisible dans l'interface ; l'aperçu des dégâts en tient compte.

## Mise en œuvre (code)
- Effets `EffectData.Kind.SHIELD` et `IMMOBILIZE` ; champ `bonus_vs_immobilized` sur les dégâts. L'Entrave est un effet à
  part (et non un retrait de PM géant) : la cible entravée est reconnue sans ambiguïté (`Fighter.is_immobilized`).
- `Fighter.shield` (consommé dans `take_damage`, remis à 0 au début du tour) ; signal `CombatState.shield_absorbed` ;
  aperçu des dégâts nets du bouclier.
- IA : bouclier quand un ennemi peut frapper au prochain tour ; Entrave notée selon la cible (tireur, mêlée à 2 cases,
  inutile au contact) ; face à un ennemi de mêlée entravé, Kael reste à 2 cases (`SAFE_FROM_BOUND_VALUE`).
- Affichage : étiquette et liseré doré du bouclier (combattant, orbe, vignette), « bouclier -N » flottant, chaîne au sol
  sur la cible entravée.
- Effets dorés, icônes et portrait générés par `tools/build_kael_assets.gd`. **Les icônes sont provisoires** (les autres
  personnages ont des illustrations peintes).
- Sons repris de la banque existante.
- Tests : `_test_shield`, `_test_immobilize`, `_test_kael_ai`.

## Intentions
Approcher sous Bouclier ; Entrave à distance pour rattraper un tireur ; au contact, deux Châtiments, ou Entrave puis Châtiment
renforcé pour empêcher la fuite ; Imposition des mains quand la pression monte. Chaque tour passé à se défendre réduit ses dégâts.

## Équilibrage
Cibles : 40 à 60 % de victoires contre chaque autre personnage sur chaque carte, 6 à 12 tours en moyenne, aucun combat sans fin.

**Référence sans Kael (26/11, 4800 combats)** : le jeu était déjà hors cible (24 alertes ; Gobelin 90 % contre l'Archer).
Après l'ajout, les 70 lignes de duels sans Kael sont identiques.

**IA avant les chiffres** : au premier jet, Kael entravait à 2 cases puis revenait au contact. Corrigé : contre le Guerrier,
victoires de Kael ≈ 0 % → 38 %.

**Leviers essayés** (un par un ou combinés) : bouclier 20 à 28, bouclier à 2 PA (effet surtout contre le Gobelin), PV 120 à 155,
Châtiment 14–17 à 18–21, soin 26–30, Entrave recharge 4. Le choix de l'IA entre Châtiment et Bouclier tient à un seuil :
un petit écart de chiffres peut changer fortement un duel (bouclier 28 : le Chevalier maudit passe de 95 % à 10 % de victoires).

**Réglage retenu (PV 136, bouclier 24, soin 24–28), 4800+ combats, matrice complète — victoires de Kael** :

| Adversaire | Global | Barrage | Prairie | Désert | Clairière | Lac | Village | Tours moy. |
|---|---|---|---|---|---|---|---|---|
| Guerrier | 55 % | 54 | 54 | 51 | 67 | 66 | 37 | 10,3 |
| Mage de feu | 99 % | 100 | 100 | 100 | 96 | 100 | 100 | 8,2 |
| Archer | 54 % | 81 | 61 | 45 | 49 | 36 | 54 | 15,7 |
| Chevalier maudit | 28 % | 22 | 29 | 27 | 40 | 19 | 30 | 10,4 |
| Gobelin | 60 % | 92 | 50 | 70 | 52 | 61 | 31 | 10,8 |

Aucun combat sans fin. Moyenne de Kael : 59 %.

**Points ouverts**
- **Mage de feu (99 %)** : problème de design plus que de chiffres. Sans soin ni bouclier le duel est à 51/49 (diagnostic) ;
  avec eux, le Mage n'a pas assez de dégâts. Affaiblir Kael par les chiffres le fait perdre contre les autres.
- **Chevalier maudit (28 %)** : vol de vie, et Malédiction (−2 PA) qui, avec des sorts tous à 3 PA, retire une action sur deux.
- **Archer** : combats longs (≈ 16 tours).
- **Guerrier** : avantage du premier joueur élevé (68 % pour le premier joueur).
- Défense à 3 PA : se protéger coûte un Châtiment, le gain net est faible (piste : revoir les coûts en PA).
- Mesures IA contre IA : à confronter aux parties jouées.
