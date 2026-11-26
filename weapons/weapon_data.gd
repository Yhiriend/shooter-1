class_name WeaponData
extends Resource
## Datos de un arma. Ver docs/GDD.md, «Armas del MVP» y «Precisión».

@export var display_name := "Arma"
@export var price := 0

@export_group("Daño")
@export var damage := 30.0
## Proyectiles por disparo (escopeta > 1).
@export var pellets := 1
## Bonus de daño del tiro certero (primer disparo estando quieto).
@export var first_shot_bonus := 0.5
## Tiempo sin disparar necesario para recuperar el tiro certero.
@export var first_shot_recovery_time := 0.5

@export_group("Cadencia y cargador")
@export var fire_interval := 0.12
@export var magazine := 25
@export var reload_time := 2.0

@export_group("Proyectil")
@export var projectile_speed := 40.0
@export var max_range := 14.0
@export var projectile_color := Color(1, 1, 1)
@export var projectile_radius := 0.08
## Distancia a la que se oye el disparo (ondas de sonido).
@export var noise_radius := 30.0

@export_group("Precisión (medio ángulo del cono, en grados)")
@export var base_spread_deg := 1.5
@export var walk_spread_mult := 1.5
@export var run_spread_mult := 3.0
@export var aim_fine_spread_mult := 0.6
@export var bloom_per_shot_deg := 1.2
@export var max_bloom_deg := 8.0
@export var bloom_recovery_deg_per_s := 12.0
