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
## Color de referencia (bordes de la selección, y cuerpo si no hay modelo).
@export var body_color := Color.WHITE
## Modelo 3D (glb con esqueleto y animaciones Idle/Walk/Sprint). Sin modelo se usa
## el greybox de cápsula y esfera de pawtner.tscn. Los genera tools/build_pawtners.py.
@export var model: PackedScene
## Retrato cuadrado de la cabeza (selección de Pawtner). Lo genera tools/render_portraits.py.
@export var portrait: Texture2D
## En orden: C, Q, E, X.
@export var abilities: Array[AbilityData] = []


func ability(slot: String) -> AbilityData:
	for a in abilities:
		if a.slot == slot:
			return a
	return null
