class_name CharacterData
extends Resource
## Un Pawtner jugable: identidad, aspecto y sus 4 habilidades (C, Q, E, X).
## Ver docs/GDD.md, «Roles y roster MVP».

@export var id := ""
@export var display_name := ""
@export var animal := ""
## "Zarpa" (entra y saca información) o "Madriguera" (controla y protege).
@export var role := "Zarpa"
@export_multiline var personality := ""
@export var body_color := Color.WHITE
## En orden: C, Q, E, X.
@export var abilities: Array[AbilityData] = []


func ability(slot: String) -> AbilityData:
	for a in abilities:
		if a.slot == slot:
			return a
	return null
