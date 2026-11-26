# Armas, escudos y precisión

Referencia de las armas y escudos del MVP y de cómo funciona el disparo. Los valores son los que usa el juego hoy (26 de noviembre de 2026); se ajustan en playtest.

Para el diseño general, ver [GDD.md](GDD.md). Para Pawtners y habilidades, ver [pawtners.md](pawtners.md).

## Resumen

Cada Pawtner porta **un arma y un escudo (o ninguno)**. La vida base es 100 y no se regenera. La munición es infinita: solo cuenta el cargador, y recargar siempre lo llena.

## Armas

| | Pistola de burbujas | Escopeta de confeti | Rifle de semillas |
| --- | --- | --- | --- |
| **Precio** | Gratis (inicial) | 900 | 1.700 |
| **Daño** | 10 por bala (1/10 de la vida) | 6 perdigones de 17 | 50 (2 impactos matan) |
| **Para matar (sin escudo)** | 10 balas | Los 6 perdigones (de cerca) | 2 impactos |
| **Cargador** | 15 | 2 | 1 |
| **Cadencia** | 0,2 s entre disparos (moderada) | 0,6 s | 1,4 s (la más baja) |
| **Recarga** | 1,5 s | 2,0 s | 1,4 s después de cada tiro |
| **Alcance** | 7,5 m | 4,5 m | 9 m |
| **Cono quieto (medio ángulo)** | 0,8° | 12° | 0,6° |
| **Cómo se dispara** | Mantener | Mantener | **Al soltar** |
| **Ruido del disparo** | 25 m | 30 m | 30 m |

### Pistola de burbujas

El arma con la que empiezas cada partida y a la que vuelves si mueres. Cada bala quita 1/10 de la vida, así que pide constancia y buena puntería. Cada disparo seguido abre el cono 1,5° (hasta 5,5° más) y se recupera a 10° por segundo: las ráfagas cortas son más precisas.

### Escopeta de confeti

Para esquinas y macetas. Cada disparo suelta 6 perdigones repartidos en un cono amplio, y cada uno hace 17 de daño: solo mata de un disparo si impactan todos, es decir, de muy cerca. Moverse casi no le afecta (×1,2 corriendo). 2 disparos por cargador.

### Rifle de semillas

El arma de precisión. Al mantener y arrastrar el joystick de disparo solo apuntas; el tiro sale **al soltar** (en PC, al soltar el clic). Cada impacto hace 50, así que 2 impactos matan, pero el cargador es de 1 bala: cada tiro obliga a recargar 1,4 s. Si sueltas mientras recarga, el tiro no sale.

## Precisión

Cada arma tiene un **cono de dispersión**: las balas salen en un ángulo aleatorio dentro de él, concentradas hacia el centro. El cono se dibuja en el suelo delante de tu Pawtner.

El tamaño del cono depende de cómo te mueves:

| Estado | Multiplicador del cono (pistola y rifle) | Escopeta |
| --- | --- | --- |
| Quieto | ×1 | ×1 |
| Caminando (joystick a menos de la mitad) | ×1,5 | ×1 |
| Corriendo | ×3 | ×1,2 |
| Apuntado fino (solo PC, clic derecho) | ×0,6 adicional | ×0,6 adicional |
| Tierra al aire de Pip | ×3 adicional durante 1,5 s | ×3 adicional |

Además, los disparos seguidos abren el cono (*bloom*) en la pistola; el rifle y la escopeta no tienen *bloom*.

El **tiro certero** (+50 % de daño en el primer disparo estando quieto) existe en el sistema, pero está desactivado en las 3 armas del MVP para que los daños sean exactos: 10 balas de pistola, 6 perdigones o 2 tiros de rifle.

## Escudos

| | Escudo ligero | Escudo pesado |
| --- | --- | --- |
| **Precio** | 300 | 800 |
| **Vida extra** | +25 | +50 |
| **Reducción de daño** | -15 % | -30 % |

- El escudo absorbe el daño antes que la vida.
- La reducción solo funciona mientras al escudo le quedan puntos; al romperse, recibes el daño completo.
- Ejemplo con escudo pesado contra el rifle: el 1.er tiro hace 35 (queda escudo 15); el 2.º hace 35 (rompe el escudo y quita 20 de vida); luego hacen falta 2 tiros más de 50. En total, 4 impactos en lugar de 2.
- La definitiva de Capi (Calma total) puede dar 50 de escudo con un 30 % de reducción.

## Comprar y conservar el equipo

| Situación | Qué pasa |
| --- | --- |
| Inicio de partida y cambio de lado | Todos con pistola, sin escudo y 800 croquetas |
| Sobrevives a la ronda (o te rescatan) | Conservas arma y escudo (con los puntos que le queden) |
| Mueres | Vuelves a la pistola y sin escudo |
| Compras en la tienda | Elegir otra arma u otro escudo devuelve la compra anterior de la ronda; tocar lo comprado lo devuelve |
| Lo que traes de la ronda anterior | No se devuelve (no lo pagaste en esta ronda) |

**Croquetas:** ganar la ronda da 1.500; perderla, 900, 1.100 o 1.300 según la racha de derrotas; cada eliminación, 100; sembrar o arrancar, 150 para todo el equipo. Máximo acumulable: 5.000.

## Dónde se editan

| Qué | Archivo |
| --- | --- |
| Armas (daño, cargador, cadencia, recarga, alcance, cono, disparo al soltar) | `weapons/<arma>.tres` |
| Lógica del disparo y del cono | `weapons/weapon.gd` |
| Escudos y precios de la economía | `core/economy.gd` |
