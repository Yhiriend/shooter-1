class_name Layers
extends RefCounted
## Capas de física compartidas por todo el juego (valores de bit).

## Capa 1: bloquea movimiento y balas (suelo, valla, coberturas altas y bajas).
const WORLD := 1
## Capa 2: bloquea visión (valla y coberturas altas; las bajas no).
const VISION_BLOCKER := 2
## Capa 3: cuerpos de los Pawtners.
const PAWTNER := 4
## Capa 4: barreras de la fase de compra (solo frenan a los Pawtners; no balas ni visión).
const BARRIER := 8
## Con qué chocan los Pawtners al moverse.
const PAWTNER_MASK := WORLD | PAWTNER | BARRIER
