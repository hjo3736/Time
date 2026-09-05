class_name RoomLabels
extends RefCounted


static func name_of(room: Room) -> String:
	if room == null:
		return ""
	match room.kind:
		Room.Kind.START: return TranslationServer.translate("ui.room.start")
		Room.Kind.EMPTY: return TranslationServer.translate("ui.room.empty")
		Room.Kind.COMBAT: return TranslationServer.translate("ui.room.combat")
		Room.Kind.ELITE: return TranslationServer.translate("ui.room.elite")
		Room.Kind.SHOP: return TranslationServer.translate("ui.room.shop")
		Room.Kind.FIRE: return TranslationServer.translate("ui.room.fire")
		Room.Kind.BOSS: return TranslationServer.translate("ui.room.boss")
		Room.Kind.EVENT: return TranslationServer.translate("ui.room.event")
	return ""


static func short_of(room: Room, here: bool) -> String:
	if here:
		return "◈"
	if room != null and room.is_spent():
		return "·"
	return name_of(room)


static func price_of(room: Room, minutes: int) -> String:
	var span := RunClock.format_span(minutes)
	if room != null and room.is_spent():
		return TranslationServer.translate("ui.room.price_spent").format({"span": span})
	return TranslationServer.translate("ui.room.price").format({"span": span})
