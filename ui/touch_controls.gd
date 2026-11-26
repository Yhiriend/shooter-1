class_name TouchControls
extends CanvasLayer
## Controles táctiles: joystick izquierdo (mover) y derecho (apuntar).
## Se muestran solo en pantallas táctiles, o siempre con `force_visible` para probar en PC.

@export var force_visible := false

@onready var move_stick: TouchStick = $MoveStick
@onready var aim_stick: TouchStick = $AimStick
@onready var interact_button: TouchButton = $InteractButton


func _ready() -> void:
	visible = force_visible or DisplayServer.is_touchscreen_available()
	interact_button.visible = false


func is_touch_mode() -> bool:
	return visible
