class_name AbilityData
extends Resource
## Datos de una habilidad. La lógica de cada efecto vive en AbilityEffects.
## Ver docs/GDD.md, «Roles y roster MVP».

## Cómo se apunta: INSTANT sale con un toque; DIRECTION se arrastra para elegir la
## dirección; AREA se arrastra para elegir el punto de caída dentro del alcance.
enum AimMode { INSTANT, DIRECTION, AREA }

enum Effect {
	YARN_REVEAL,   ## Mochi C: ovillo que rebota y revela al detenerse
	BELL_FLASH,    ## Mochi Q: cascabel que deja casi sin visión a quien lo mira
	DASH,          ## Mochi E: impulso corto
	NIGHT_EYES,    ## Mochi X: revela a todo enemigo que corra
	DECOY,         ## Pip C: zanahoria que hace pasos falsos
	GROUND_SLAM,   ## Pip Q: golpe que frena y abre el cono de los cercanos
	BURROW,        ## Pip E: viaje bajo tierra
	BIG_LEAP,      ## Pip X: gran salto que aturde al caer
	BAMBOO_WALL,   ## Tofu C: muro que bloquea balas y visión
	HONEY_POOL,    ## Tofu Q: charco que frena y hace ruido
	SMOKE,         ## Tofu E: nube que bloquea visión
	BIG_SMOKE,     ## Tofu X: nube grande que ciega a quien está dentro
	ORANGE_TRAP,   ## Capi C: trampa que inmoviliza y revela
	HOT_SPRING,    ## Capi Q: charco que cura a aliados
	WATCHER,       ## Capi E: pajarito vigía que da visión
	TOTAL_CALM,    ## Capi X: revive al compañero o da escudo a ambos
}

@export var display_name := ""
@export var aim_mode := AimMode.INSTANT
## Tecla/ranura: "C", "Q", "E" o "X".
@export var slot := "C"
@export_multiline var description := ""
@export var effect := Effect.YARN_REVEAL

@export_group("Cargas y coste")
## C y Q: precio por carga. E: precio de cada carga extra (0 = no se compran).
@export var price := 0
@export var max_charges := 1
## Cargas gratis al empezar cada ronda (la E).
@export var free_charges := 0
## Puntos de definitiva necesarios (la X).
@export var ult_cost := 0

@export_group("Parámetros")
## Distancia máxima al punto apuntado (0 = sobre uno mismo).
@export var cast_range := 0.0
@export var radius := 0.0
@export var duration := 0.0
## Daño, curación, distancia o vida, según el efecto.
@export var amount := 0.0
