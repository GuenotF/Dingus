# Créer un personnage

Workflow validé avec le Mage de feu. Un personnage = une fiche, des assets, des données ;
du code seulement si un sort a besoin d'un nouvel effet.

## Checklist

- [ ] **Identité** : nom, rôle (corps à corps, distance, soutien…), distance préférée pour l'IA (`preferred_range`).
- [ ] **Skin** : un personnage du pack (planches 15 images × 8 directions, 128×128).
- [ ] **Animations de base** : `idle` (attente), `walk` (déplacement), `hit` (dégâts), `die` (mort).
- [ ] **4 sorts**, chacun avec : coût en PA, portée, ligne de vue, zone, effets, limites (lancers/tour, recharge),
      animation du lanceur, et si besoin projectile (`projectile`) et effet d'impact (`impact`).
- [ ] **Stats** : PV, PA, PM.
- [ ] **Portrait** : PNG rond 88 px dans `assets/ui/portraits/<classe>.png` (tête et épaules recadrées sur la frame 0 de l'animation `idle`, orientation bas-gauche), champ `portrait` de la classe ; sans lui, la bulle de l'ordre du tour affiche l'initiale.
- [ ] **Voix** (optionnel) : ressource `CharacterVoice` dans `data/voices/`, champ `voice` de la classe (voir README, Sons).
- [ ] **Description** : une phrase de présentation (champ `description` de la classe, affichée dans le menu).
- [ ] **Tests** : `tests/test_core.gd` vérifie automatiquement la checklist (4 sorts, stats, skin, animations, effets).
- [ ] **Équilibrage** : `tests/simulate_balance.gd` contre chaque autre personnage, sur chaque carte.

## Critères d'équilibrage

- 40 à 60 % de victoires contre chaque autre personnage, **sur chaque carte** ;
- 6 à 12 tours en moyenne (on tolère un peu moins, à surveiller) ;
- aucun combat sans fin ; avantage du premier joueur limité.

## Étapes

1. **Fiche** (`docs/personnages/<nom>.md`, modèle ci-dessous) : validée avec l'utilisateur avant tout code.
2. **Assets** : copier dans `assets/characters/<nom>/` uniquement les planches utilisées ;
   effets dans `assets/effects/` (assemblés en une ligne et réduits : les originaux sont très lourds).
3. **Données** :
   - `data/sprites/<nom>.tres` (CharacterSprites : directions lignes 1/3/5/7, pieds, hauteur, animations).
     **Pieds** : mesurer, **pour chacune des 4 directions**, le milieu entre les deux pieds sur la version
     *Shadowless* des planches (70 % Idle, 30 % Walk) → `feet_down_right`, `feet_down_left`, `feet_up_left`,
     `feet_up_right` ; puis vérifier visuellement sur une case avec son centre marqué ;
   - `data/effects/*.tres` (EffectAnimation : origine, échelle, vitesse, au sol ou non) ;
   - `data/spells/<nom>_*.tres` (SpellData) ;
   - `data/classes/<nom>.tres` (ClassData) — le menu et le simulateur le trouvent automatiquement
     une fois ajouté à `CLASS_PATHS` (`scripts/game_config.gd`).
4. **Code** (seulement si nécessaire) : nouvel effet dans `core/`, son évaluation par l'IA (`ai_brain.gd`), ses tests.
5. **Vérification visuelle** : une partie jouée, une capture de chaque sort (lancement, vol, impact).
6. **Équilibrage** : simuler, comparer aux critères, ajuster les **chiffres** (pas le design) et noter
   les écarts à la fiche. Si l'IA joue mal le personnage, corriger l'IA avant les chiffres.
7. **Commit**, puis l'utilisateur teste en jouant.

## Modèle de fiche

```
# <Nom>
Identité : …            Skin : …            Distance préférée (IA) : …
Stats : PV … / PA … / PM …
Animations de base : idle = …, walk = …, hit = …, die = …

| # | Sort | PA | Portée | Effets | Limites | Animation | Projectile / impact |
|---|------|----|--------|--------|---------|-----------|---------------------|

Intentions : …
Équilibrage (résultats de la simulation, par carte et par adversaire) : …
```
