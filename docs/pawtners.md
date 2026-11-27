# Pawtners y habilidades

Referencia de los 4 Pawtners del MVP: quiénes son, cómo se juegan y qué hace exactamente cada habilidad. Los valores son los que usa el juego hoy (26 de noviembre de 2026); se ajustan en playtest.

Para el diseño general, ver [GDD.md](GDD.md). Para armas y escudos, ver [armas.md](armas.md).

## Índice

1. [Roles](#roles)
2. [Cómo funcionan las habilidades](#cómo-funcionan-las-habilidades)
3. [Mochi · Gata calicó · Zarpa](#mochi--gata-calicó--zarpa)
4. [Pip · Conejo enano · Zarpa](#pip--conejo-enano--zarpa)
5. [Tofu · Panda · Madriguera](#tofu--panda--madriguera)
6. [Capi · Capibara · Madriguera](#capi--capibara--madriguera)
7. [Estados alterados](#estados-alterados)
8. [Cómo usan las habilidades los bots](#cómo-usan-las-habilidades-los-bots)
9. [Dónde se editan](#dónde-se-editan)

## Roles

Hay dos roles. Cada dúo funciona mejor con uno de cada, y en la partida contra bots tu compañero siempre es del rol contrario al tuyo.

| Rol | Función | Pawtners |
| --- | --- | --- |
| **Zarpa** | Entra primero, saca información y gana duelos | Mochi, Pip |
| **Madriguera** | Tapa la visión, controla zonas y protege al dúo | Tofu, Capi |

## Cómo funcionan las habilidades

Cada Pawtner tiene 4 habilidades, una por ranura:

| Ranura | Cómo se consigue | Notas |
| --- | --- | --- |
| **C** | Se compra en la tienda (por carga) | Las cargas que no uses se guardan para la siguiente ronda |
| **Q** | Se compra en la tienda (por carga) | Igual que la C |
| **E** | Gratis: 1 carga al empezar cada ronda | La de Tofu admite una 2.ª carga comprada (100) |
| **X** | Definitiva: se carga con puntos | 5 puntos (Capi, 4) |

**Puntos de definitiva:** +1 por cada eliminación, por sembrar la semilla, por arrancar la planta y por recoger un trébol (hay uno en cada pasillo y reaparecen cada 2 rondas). Los puntos se conservan al cambiar de lado; las cargas de C y Q se reinician con la economía.

**En la fase de compra** se pueden usar las habilidades de preparación (trampas, vigías, nubes, miel, muros, curación, señuelo, impulso, golpe al suelo). Lo colocado no sale de tu zona: si apuntas más allá de la barrera, cae en el borde. No se pueden usar la definitiva, la Madriguera, el Gran salto, el Ovillo, el Cascabel ni los Ojos nocturnos. Los bots defensores van a su maceta y dejan ahí su trampa o su vigía.

**Modos de lanzamiento:**

| Modo | En el móvil | En PC |
| --- | --- | --- |
| Instantánea | Un toque: sale hacia donde te mueves, a tus pies o alrededor tuyo | Pulsar la tecla |
| Dirección | Mantener el botón y arrastrar: una flecha marca la dirección; sale al soltar | Mantener la tecla, apuntar con el ratón y soltar |
| Área | Mantener y arrastrar: se ve el círculo de alcance y la zona de caída con su tamaño real; cae al soltar | Igual, con el ratón |

Un toque corto sin arrastrar lanza las de dirección y área hacia donde mira tu Pawtner (las de área, al 60 % del alcance). Mientras estás aturdido o en medio de un impulso o salto no puedes usar habilidades.

---

## Mochi · Gata calicó · Zarpa

*Curiosa y presumida; siempre lleva un cascabel.*

**Estilo de juego:** la que entra primero. Revela con el ovillo, deja sin visión al rival con el cascabel y gana el duelo; el impulso le da la salida si la cosa sale mal. Su definitiva castiga a quien corre: obliga al rival a caminar despacio.

| Tecla | Habilidad | Modo | Coste | Qué hace |
| --- | --- | --- | --- | --- |
| C | **Ovillo rebotón** | Dirección | 200 (máx. 1) | Lanza un ovillo en línea recta, hasta 12 m. Rebota en coberturas hasta 3 veces (pierde un 20 % de velocidad en cada rebote). Al detenerse (1,4 s o tras el último rebote) revela a tu equipo a todos los enemigos a 5 m durante 2 s. |
| Q | **Cascabel** | Área | 150 (máx. 2) | Lo lanzas a un punto a hasta 8 m; vuela 0,5 s (o hasta chocar) y estalla con un destello de luz blanca. Los enemigos a 8 m del estallido que lo vean con su visión real (dentro de su radio de visión y con línea de vista; da igual hacia dónde miren) quedan con 1 m de visión durante 1,5 s. No afecta a tu equipo. |
| E | **Salto felino** | Instantánea | Gratis | Impulso de 4 m en 0,15 s hacia donde te mueves (si estás quieto, hacia donde miras). Choca con las paredes. Se recupera con cada eliminación en la ronda (si la gastaste). |
| X | **Ojos nocturnos** | Instantánea | 5 puntos | Durante 8 s, tu equipo ve a todo enemigo que esté corriendo, en todo el mapa. Quien camina o está quieto no aparece. |

**Consejos:** lanza el ovillo antes de entrar a una maceta para saber si hay alguien. El cascabel funciona mejor detrás de una esquina, donde el rival te está esperando.

---

## Pip · Conejo enano · Zarpa

*Hiperactivo, habla rápido.*

**Estilo de juego:** movilidad y engaño. Distrae con pasos falsos, se mete bajo tierra para aparecer donde no lo esperan y entra al combate cayendo encima del rival con su definitiva.

| Tecla | Habilidad | Modo | Coste | Qué hace |
| --- | --- | --- | --- | --- |
| C | **Zanahoria señuelo** | Área | 100 (máx. 2) | Planta una zanahoria a hasta 8 m. Durante 4 s genera ondas de pasos falsos (una cada 0,35 s) que los enemigos a 15 m oyen como si fueran pasos reales. |
| Q | **Tierra al aire** | Instantánea | 200 (máx. 1) | Golpe al suelo: los enemigos a 3 m quedan lentos (60 % de velocidad) y con el cono de disparo ×3 durante 1,5 s. |
| E | **Madriguera rápida** | Instantánea | Gratis | Se mete bajo tierra 0,4 s y sale hasta 6 m más allá, en la dirección en que te mueves (si estás quieto, hacia donde miras). Pasa por debajo de coberturas; sale en el punto libre más lejano. Mientras va bajo tierra no se le ve. Deja una marca en la entrada y en la salida. |
| X | **Gran salto** | Área | 5 puntos | Salta en arco a un punto a hasta 15 m, por encima de las coberturas (0,8 s). Al caer aturde 1,2 s a los enemigos a 4 m. |

**Consejos:** usa la zanahoria en el pasillo contrario al que vas a atacar. Tierra al aire es para cuando el rival está encima: lento y con el cono abierto, pierde el duelo.

---

## Tofu · Panda · Madriguera

*Dormilón y tranquilo; abraza su bambú.*

**Estilo de juego:** el controlador. Corta líneas de vista con nubes y muros para que el dúo pueda cruzar, sembrar o arrancar, y frena al rival con la miel.

| Tecla | Habilidad | Modo | Coste | Qué hace |
| --- | --- | --- | --- | --- |
| C | **Muro de bambú** | Dirección | 200 (máx. 1) | Levanta un muro de 6 m a 2,5 m delante de ti, perpendicular a la dirección elegida. Dura 10 s y tiene 300 de vida (las balas de cualquier equipo lo dañan). Bloquea movimiento, balas y visión. No se levanta dentro de coberturas ni de la valla. |
| Q | **Charco de miel** | Área | 150 (máx. 1) | Charco de 3 m de radio a hasta 8 m, durante 6 s. Los enemigos dentro se mueven al 60 % y sus pasos hacen ruido aunque caminen. |
| E | **Nube de bambú** | Área | Gratis (2.ª: 100) | Nube de 3 m de radio a hasta 10 m, durante 14 s. Corta la línea de vista: nadie ve a través. Desde dentro solo se ve a menos de 1 m. |
| X | **Siesta del bosque** | Área | 5 puntos | Nube grande de 8 m de radio a hasta 12 m, durante 8 s. Solo afecta a los rivales: a ellos les bloquea la visión como la E y, si están dentro, quedan con 1 m de visión. Tofu y su compañero ven a través de la nube (para ellos se dibuja casi transparente) y no quedan cegados dentro. |

**Consejos:** una nube en la entrada de la maceta permite sembrar sin que te vean desde lejos. El muro sirve para taparte mientras arrancas la planta.

---

## Capi · Capibara · Madriguera

*Calma total; lleva una naranja en la cabeza.*

**Estilo de juego:** el centinela y apoyo. Vigila con el pajarito, atrapa al que entra con la trampa, cura al dúo y, con su definitiva, revive al compañero.

| Tecla | Habilidad | Modo | Coste | Qué hace |
| --- | --- | --- | --- | --- |
| C | **Naranja trampa** | Instantánea | 150 (máx. 2) | Coloca una trampa a tus pies que dura toda la ronda. Los enemigos solo la ven a menos de 3 m. Si un enemigo pasa a 0,9 m, recibe 20 de daño, queda inmovilizado 1,5 s (puede disparar) y revelado a tu equipo durante 3 s. La trampa se consume. |
| Q | **Baño termal** | Área | 200 (máx. 1) | Charco de 2,5 m de radio a hasta 6 m, durante 5 s. Cura a los aliados que estén dentro 8 de vida por segundo, hasta 40 por aliado. |
| E | **Vigía tranquilo** | Área | Gratis | Coloca un pajarito a hasta 6 m, mirando en la dirección en que lo lanzas. Da a tu equipo visión en un cono de 90° y 8 m (también abre la niebla). Cae de un impacto enemigo. Pulsando E otra vez lo recoges y recuperas la carga. |
| X | **Calma total** | Instantánea | 4 puntos | Si tu compañero cayó en esta ronda, lo revive con 100 de vida donde está su peluche (o donde cayó). Si está vivo, ambos reciben 50 de escudo con un 30 % de reducción de daño. |

**Consejos:** deja el vigía mirando a la entrada por la que suele venir el rival. La Calma total no depende del rescate de dúo: sirve aunque ya se haya usado o el peluche haya desaparecido.

---

## Estados alterados

Lo que las habilidades le hacen a un Pawtner:

| Estado | Efecto | Lo causan |
| --- | --- | --- |
| **Cegado** | Visión reducida a 1 m; en tu pantalla, destello blanco. Todos le ven una cinta blanca sobre los ojos | Cascabel (Mochi Q), Siesta del bosque (Tofu X) |
| **Lento** | Se mueve más despacio | Tierra al aire (Pip Q, 60 %), Charco de miel (Tofu Q, 60 %) |
| **Cono abierto** | Dispersión del arma ×3 | Tierra al aire (Pip Q) |
| **Aturdido** | No se mueve, no dispara ni usa habilidades. Todos le ven estrellitas girando sobre la cabeza | Gran salto (Pip X) |
| **Inmovilizado** | No se mueve, pero puede disparar | Naranja trampa (Capi C) |
| **Revelado** | El rival lo ve aunque no tenga línea de vista | Ovillo (Mochi C), trampa (Capi C), Ojos nocturnos (Mochi X), polen de la Semilla Lunar |
| **Pasos ruidosos** | Sus pasos hacen ondas aunque camine | Charco de miel (Tofu Q) |

Nubes y muros cortan la línea de vista tanto para los jugadores como para los bots.

## Cómo usan las habilidades los bots

Los bots compran cargas de C y Q con lo que les sobra después del arma y el escudo (en rondas de ahorro no compran nada). Usan una habilidad cada vez, con al menos 6 s entre dos usos de la misma ranura, y solo con lo que ve u oye su equipo.

| Habilidad | Cuándo la usa un bot |
| --- | --- |
| Ovillo rebotón | Al acercarse a la zona a la que va (entre 3 y 11 m), sin estar en combate |
| Cascabel | En combate, con el enemigo dentro del alcance |
| Salto felino | En combate y con menos de 50 de vida: sale hacia un costado |
| Ojos nocturnos | Fuera de combate, con rivales vivos |
| Zanahoria señuelo | Esperando en posición: a un costado |
| Tierra al aire | En combate, con el enemigo a 3 m |
| Madriguera rápida | En combate y con menos de 40 de vida: se aleja del enemigo |
| Gran salto | En combate, con el enemigo entre 4 y 15 m: cae encima |
| Muro de bambú | En combate, mientras siembra o arranca, o herido |
| Charco de miel | En combate, con el enemigo entre 3 y 8 m |
| Nube de bambú | En combate, herido o mientras siembra o arranca: entre él y el enemigo |
| Siesta del bosque | En combate con 2 enemigos a la vista, o mientras siembra o arranca |
| Naranja trampa | Esperando en posición: una por ronda |
| Baño termal | Fuera de combate, con un aliado herido (menos de 70) a 4 m |
| Vigía tranquilo | Esperando en posición: una vez por ronda, mirando hacia el spawn rival |
| Calma total | Con el compañero caído, o en combate con poco escudo |

## Dónde se editan

Todos los valores son recursos de Godot, editables desde el inspector sin tocar código:

| Qué | Archivo |
| --- | --- |
| Pawtners (nombre, animal, rol, color, habilidades) | `pawtners/characters/<id>.tres` |
| Habilidades (modo, coste, cargas, alcance, radio, duración, cantidad) | `abilities/data/<pawtner>_<habilidad>.tres` |
| Lógica de cada efecto | `abilities/ability_effects.gd` y `abilities/objects/` |
| Reglas de uso de los bots | `bots/bot_abilities.gd` |
