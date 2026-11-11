class_name CardUpgrade
extends Resource

const INHERIT := -99
const UNLIMITED := -1

@export var name_suffix := "+"
@export var effects: Array[CardEffect] = []
@export var cost_hours := INHERIT
@export var max_upgrade := 1
@export var growth := 1
@export var override_targeting := false
@export var targeting := CardTargeting.Mode.SINGLE_ENEMY
@export_flags("Exhaust", "Retain", "Innate", "Ethereal", "Unplayable") var add_keywords := 0
@export_flags("Exhaust", "Retain", "Innate", "Ethereal", "Unplayable") var remove_keywords := 0
@export var text_key := &""
