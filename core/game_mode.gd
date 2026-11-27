class_name GameMode
extends RefCounted
## Modo elegido en el menú principal y configuración de la sala de pruebas. Se guarda en
## variables estáticas porque sobrevive al cambio de escena (menú → mapa) sin autoload.

const MENU_SCENE := "res://ui/main_menu.tscn"
const MATCH_SCENE := "res://maps/huerto_lunar.tscn"
const SETTINGS_PATH := "user://practice.cfg"

## Sala de pruebas: reaparición a los 2 s, recursos infinitos y bots configurables.
static var practice := false

## Sala de pruebas: qué pueden hacer los demás Pawtners. Por defecto, blancos quietos.
static var enemies_move := false
static var enemies_attack := false
static var ally_move := false
static var ally_attack := false


static func start_match(tree: SceneTree, is_practice: bool) -> void:
	practice = is_practice
	if is_practice:
		load_practice_settings()
	tree.paused = false
	tree.change_scene_to_file(MATCH_SCENE)


static func go_to_menu(tree: SceneTree) -> void:
	practice = false
	tree.paused = false
	tree.change_scene_to_file(MENU_SCENE)


## Permisos de un bot del equipo `team` en la sala de pruebas (`local_team` = el tuyo).
static func bot_can_move(team: int, local_team: int) -> bool:
	return ally_move if team == local_team else enemies_move


static func bot_can_attack(team: int, local_team: int) -> bool:
	return ally_attack if team == local_team else enemies_attack


## Lee una opción de la sala por nombre (lo usa la pantalla de configuración).
static func get_setting(key: String) -> bool:
	match key:
		"enemies_move": return enemies_move
		"enemies_attack": return enemies_attack
		"ally_move": return ally_move
		"ally_attack": return ally_attack
	return false


static func set_setting(key: String, value: bool) -> void:
	match key:
		"enemies_move": enemies_move = value
		"enemies_attack": enemies_attack = value
		"ally_move": ally_move = value
		"ally_attack": ally_attack = value


static func load_practice_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	enemies_move = cfg.get_value("practice", "enemies_move", enemies_move)
	enemies_attack = cfg.get_value("practice", "enemies_attack", enemies_attack)
	ally_move = cfg.get_value("practice", "ally_move", ally_move)
	ally_attack = cfg.get_value("practice", "ally_attack", ally_attack)


static func save_practice_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("practice", "enemies_move", enemies_move)
	cfg.set_value("practice", "enemies_attack", enemies_attack)
	cfg.set_value("practice", "ally_move", ally_move)
	cfg.set_value("practice", "ally_attack", ally_attack)
	cfg.save(SETTINGS_PATH)
