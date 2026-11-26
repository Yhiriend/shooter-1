class_name Roster
extends RefCounted
## Los Pawtners jugables del MVP.

const CHARACTERS: Array[CharacterData] = [
	preload("res://pawtners/characters/mochi.tres"),
	preload("res://pawtners/characters/pip.tres"),
	preload("res://pawtners/characters/tofu.tres"),
	preload("res://pawtners/characters/capi.tres"),
]


static func by_role(role: String) -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for c in CHARACTERS:
		if c.role == role:
			result.append(c)
	return result
