class_name ClassData
extends Resource
## Définition d'une classe jouable (data/classes/*.tres).

@export var class_label: String = "Classe"
@export var color: Color = Color.WHITE
## Une phrase de présentation, affichée dans le menu sous le nom.
@export var description: String = ""
@export var max_hp: int = 100
@export var max_pa: int = 6
@export var max_pm: int = 3
## Distance à l'ennemi que l'IA cherche à garder (1 = corps à corps).
@export_range(1, 10) var preferred_range: int = 1
@export var spells: Array[SpellData] = []
## Graphismes animés (optionnel). Sans eux, le pion temporaire est dessiné.
## Type Resource pour que core/ ne dépende pas du code d'affichage (CharacterSprites).
@export var sprites: Resource
## Voix (optionnel, CharacterVoice) : répliques à l'attaque, aux dégâts, à la mort...
@export var voice: Resource
