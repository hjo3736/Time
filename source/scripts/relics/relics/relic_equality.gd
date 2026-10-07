class_name RelicEquality
extends Relic


## Four equal quarters. The order is left as it is — night still holds the small
## hours — so only the lengths change and nothing else has to be relearned.
func modify_sky_bounds(_run: RunState, _bounds: PackedInt32Array) -> PackedInt32Array:
	var quarter := Balance.MINUTES_PER_DAY / 4
	return PackedInt32Array([quarter, quarter * 2, quarter * 3, quarter * 4])
