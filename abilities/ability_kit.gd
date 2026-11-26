class_name AbilityKit
extends Node
## Las 4 habilidades de un Pawtner: cargas de C, Q y E, y puntos de la definitiva (X).
## Ver docs/GDD.md, «Roles y roster MVP».

signal changed
## Se lanzó una habilidad (para estadísticas y pruebas).
signal ability_cast(slot: String, ability: AbilityData)

const SLOTS: Array[String] = ["C", "Q", "E", "X"]
## Mochi recupera su E al conseguir este número de eliminaciones.
const DASH_RECHARGE_KILLS := 1
## En la fase de compra no se puede: la definitiva, saltar o excavar por encima de la barrera,
## ni lanzar cosas que revelan o ciegan al otro lado.
const SETUP_BLOCKED: Array[AbilityData.Effect] = [
	AbilityData.Effect.BURROW,
	AbilityData.Effect.BIG_LEAP,
	AbilityData.Effect.YARN_REVEAL,
	AbilityData.Effect.BELL_FLASH,
	AbilityData.Effect.NIGHT_EYES,
]

var character: CharacterData
var charges := {"C": 0, "Q": 0, "E": 0}
var ult_points := 0

var _pawtner: Pawtner
var _kills_for_recharge := 0


func setup(p: Pawtner, c: CharacterData) -> void:
	_pawtner = p
	character = c


func ability(slot: String) -> AbilityData:
	return character.ability(slot) if character else null


func ult_cost() -> int:
	var x := ability("X")
	return x.ult_cost if x else 0


func is_ult_ready() -> bool:
	return ult_points >= ult_cost()


## Inicio de partida (todo a cero) o cambio de lado (`keep_ult`: los puntos de definitiva se conservan).
func reset_match(keep_ult := false) -> void:
	charges = {"C": 0, "Q": 0, "E": 0}
	if not keep_ult:
		ult_points = 0
	_kills_for_recharge = 0
	changed.emit()


## Inicio de ronda: la E vuelve a tener sus cargas gratis. C y Q compradas se conservan.
func begin_round() -> void:
	var e := ability("E")
	if e:
		charges["E"] = maxi(charges["E"], e.free_charges)
	_kills_for_recharge = 0
	changed.emit()


func add_charge(slot: String, amount := 1) -> void:
	var a := ability(slot)
	charges[slot] = clampi(charges.get(slot, 0) + amount, 0, a.max_charges)
	changed.emit()


func add_ult_point(amount := 1) -> void:
	ult_points = mini(ult_points + amount, ult_cost())
	changed.emit()


func on_kill() -> void:
	add_ult_point()
	if character and character.id == "mochi":
		_kills_for_recharge += 1
		if _kills_for_recharge >= DASH_RECHARGE_KILLS and charges["E"] == 0:
			_kills_for_recharge = 0
			add_charge("E")


func can_cast(slot: String) -> bool:
	var a := ability(slot)
	if a == null or _pawtner == null or not _pawtner.can_act() or _pawtner.frozen:
		return false
	if _pawtner.setup_lock and (slot == "X" or a.effect in SETUP_BLOCKED):
		return false
	if slot == "X":
		return is_ult_ready()
	# El vigía de Capi se puede recoger aunque no queden cargas.
	if a.effect == AbilityData.Effect.WATCHER and AbilityEffects.find_watcher(_pawtner):
		return true
	return charges.get(slot, 0) > 0


## Lanza la habilidad hacia `aim_point` (limitado a su alcance). true si se lanzó.
func cast(slot: String, aim_point: Vector3) -> bool:
	if not can_cast(slot):
		return false
	var a := ability(slot)
	var target := AbilityEffects.clamp_target(_pawtner, aim_point, a.cast_range)
	var m := MatchManager.current
	if _pawtner.setup_lock and m:
		# Lo que se coloca en la compra se queda dentro de tu zona.
		target = HuertoLunar.current.clamp_to_setup_zone(m.role_of(_pawtner), target)
	var result := AbilityEffects.cast(_pawtner, a, target)
	if result == AbilityEffects.CastResult.FAILED:
		return false
	if slot == "X":
		ult_points = 0
	elif result == AbilityEffects.CastResult.REFUND:
		charges[slot] = mini(charges[slot] + 1, a.max_charges)
	else:
		charges[slot] -= 1
	changed.emit()
	Sfx.ability(a.effect, slot == "X", _pawtner.global_position)
	ability_cast.emit(slot, a)
	return true
