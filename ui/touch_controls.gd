class_name TouchControls
extends CanvasLayer
## Controles táctiles: joystick izquierdo (mover) y derecho (apuntar).
## Se muestran solo en pantallas táctiles, o siempre con `force_visible` para probar en PC.

@export var force_visible := false

@onready var move_stick: TouchStick = $MoveStick
@onready var aim_stick: TouchStick = $AimStick
@onready var interact_button: TouchButton = $InteractButton
## Botones de habilidad por ranura: "C", "Q", "E", "X".
@onready var ability_buttons := {
	"C": $AbilityC as TouchButton,
	"Q": $AbilityQ as TouchButton,
	"E": $AbilityE as TouchButton,
	"X": $AbilityX as TouchButton,
}


func _ready() -> void:
	visible = force_visible or DisplayServer.is_touchscreen_available()
	interact_button.visible = false
	# Los muestra el PlayerController cuando ya existe tu Pawtner.
	for button: TouchButton in ability_buttons.values():
		button.visible = false


## Oculta los joysticks (por ejemplo, con la tienda abierta) para que no roben toques.
func set_sticks_enabled(enabled: bool) -> void:
	move_stick.visible = enabled
	aim_stick.visible = enabled


func is_touch_mode() -> bool:
	return visible
