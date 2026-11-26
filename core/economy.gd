class_name Economy
extends RefCounted
## Croquetas de cada Pawtner, catálogo de la tienda y compras de la ronda.
## Cada Pawtner porta un arma y un escudo (o ninguno). Lo comprado en la ronda se
## puede devolver durante la fase de compra; cambiar de arma o escudo devuelve el anterior.
## Ver docs/GDD.md, «Economía en croquetas».

signal credits_changed(p: Pawtner, credits: int)
signal purchases_changed(p: Pawtner)

const START_CREDITS := 800
const MAX_CREDITS := 5000
const WIN_REWARD := 1500
## Por derrotas seguidas: 1.ª, 2.ª, 3.ª o más.
const LOSS_REWARDS: Array[int] = [900, 1100, 1300]
const KILL_REWARD := 100
const OBJECTIVE_REWARD := 150

const PISTOL := preload("res://weapons/bubble_pistol.tres")
const SHOTGUN := preload("res://weapons/confetti_shotgun.tres")
const RIFLE := preload("res://weapons/seed_rifle.tres")
const WEAPONS: Array[WeaponData] = [PISTOL, SHOTGUN, RIFLE]

## Escudos: vida extra y reducción de daño mientras les queden puntos.
const SHIELDS: Array[Dictionary] = [
	{"name": "Escudo ligero", "price": 300, "amount": 25.0, "reduction": 0.15},
	{"name": "Escudo pesado", "price": 800, "amount": 50.0, "reduction": 0.30},
]

var _credits := {}  # Pawtner -> int
var _loss_streak: Array[int] = [0, 0]
## Compras de la ronda: Pawtner -> {"weapon": {...}, "shield": {...}}.
var _purchases := {}


func credits(p: Pawtner) -> int:
	return _credits.get(p, 0)


func reset(pawtners: Array[Pawtner]) -> void:
	_loss_streak = [0, 0]
	_purchases.clear()
	for p in pawtners:
		_set_credits(p, START_CREDITS)


## Al empezar cada fase de compra: lo que se lleva puesto ya no se puede devolver.
func begin_round() -> void:
	_purchases.clear()


func add(p: Pawtner, amount: int) -> void:
	_set_credits(p, credits(p) + amount)


func add_team(pawtners: Array[Pawtner], team: int, amount: int) -> void:
	for p in pawtners:
		if p.team == team:
			add(p, amount)


func award_round(pawtners: Array[Pawtner], winner: int) -> void:
	var loser := 1 - winner
	_loss_streak[winner] = 0
	var loss_reward := LOSS_REWARDS[mini(_loss_streak[loser], LOSS_REWARDS.size() - 1)]
	_loss_streak[loser] += 1
	add_team(pawtners, winner, WIN_REWARD)
	add_team(pawtners, loser, loss_reward)


func can_afford(p: Pawtner, price: int) -> bool:
	return credits(p) >= price


# --- Consultas para la tienda ---

## Arma comprada en esta ronda, o null.
func bought_weapon(p: Pawtner) -> WeaponData:
	var rec: Dictionary = _record(p).get("weapon", {})
	return rec.get("data", null)


## Arma con la que empezó la ronda (a la que se vuelve al devolver la compra).
func weapon_at_round_start(p: Pawtner) -> WeaponData:
	var rec: Dictionary = _record(p).get("weapon", {})
	return rec.get("previous", p.weapon.data)


## Índice del escudo comprado en esta ronda, o -1.
func bought_shield(p: Pawtner) -> int:
	var rec: Dictionary = _record(p).get("shield", {})
	return rec.get("index", -1)


## Croquetas gastadas en esta ronda.
func spent_this_round(p: Pawtner) -> int:
	var total := 0
	for rec: Dictionary in _record(p).values():
		total += int(rec["price"])
	return total


## ¿Puede pagar `price` si devuelve lo que ya compró en esa categoría?
func can_afford_swap(p: Pawtner, category: String, price: int) -> bool:
	var rec: Dictionary = _record(p).get(category, {})
	return credits(p) + int(rec.get("price", 0)) >= price


# --- Armas ---

## Compra un arma (devolviendo la comprada antes en esta ronda). true si se pudo.
func buy_weapon(p: Pawtner, data: WeaponData) -> bool:
	if p.weapon.data == data:
		return false
	var rec: Dictionary = _record(p).get("weapon", {})
	var original: WeaponData = rec.get("previous", p.weapon.data)
	if data == original:
		# Volver al arma con la que empezó la ronda = devolver la compra.
		sell_weapon(p)
		return true
	if not can_afford_swap(p, "weapon", data.price):
		return false
	sell_weapon(p)
	add(p, -data.price)
	p.equip(data)
	_record(p)["weapon"] = {"data": data, "price": data.price, "previous": original}
	purchases_changed.emit(p)
	return true


## Devuelve el arma comprada en esta ronda y recupera la anterior.
func sell_weapon(p: Pawtner) -> void:
	var rec: Dictionary = _record(p).get("weapon", {})
	if rec.is_empty():
		return
	_record(p).erase("weapon")
	add(p, int(rec["price"]))
	p.equip(rec["previous"])
	purchases_changed.emit(p)


# --- Escudos ---

## Compra el escudo `index` (devolviendo el comprado antes en esta ronda). true si se pudo.
func buy_shield(p: Pawtner, index: int) -> bool:
	var item: Dictionary = SHIELDS[index]
	var amount: float = item["amount"]
	if p.armor_index == index and p.shield >= amount:
		return false
	var price: int = item["price"]
	if not can_afford_swap(p, "shield", price):
		return false
	var rec: Dictionary = _record(p).get("shield", {})
	var previous: Dictionary = rec.get("previous", _armor_state(p))
	sell_shield(p)
	add(p, -price)
	p.set_armor(index, amount, item["reduction"])
	_record(p)["shield"] = {"index": index, "price": price, "previous": previous}
	purchases_changed.emit(p)
	return true


## Devuelve el escudo comprado en esta ronda y recupera el que tenía antes (o ninguno).
func sell_shield(p: Pawtner) -> void:
	var rec: Dictionary = _record(p).get("shield", {})
	if rec.is_empty():
		return
	_record(p).erase("shield")
	add(p, int(rec["price"]))
	var prev: Dictionary = rec["previous"]
	if int(prev["index"]) < 0:
		p.clear_armor()
		p.health_changed.emit(p.health, p.shield)
	else:
		p.set_armor(prev["index"], prev["shield"], prev["reduction"])
	purchases_changed.emit(p)


func _armor_state(p: Pawtner) -> Dictionary:
	return {"index": p.armor_index, "shield": p.shield, "reduction": p.shield_reduction}


func _record(p: Pawtner) -> Dictionary:
	if not _purchases.has(p):
		_purchases[p] = {}
	return _purchases[p]


func _set_credits(p: Pawtner, value: int) -> void:
	_credits[p] = clampi(value, 0, MAX_CREDITS)
	credits_changed.emit(p, _credits[p])
