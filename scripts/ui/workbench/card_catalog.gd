extends RefCounted
## 工作台目录包含正式卡、独立形态和系统对象；只读定义，不参与正式卡组资格。

static func entries(cards: Dictionary, query: String = "", category: String = "all") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Array = cards.keys()
	ids.sort()
	for base_id in cards:
		if has_forms(cards[base_id]):
			ids.append(String(base_id) + ":1")
	ids.push_front("training_dummy")
	var selectable := CardDB.selectable_ids()
	for raw_id in ids:
		var id := String(raw_id)
		var base_id := id.get_slice(":", 0)
		if cards.values().any(func(stats): return String(stats.get("deployment_upgrade_id", "")) == id): continue
		var form := 1 if id.ends_with(":1") else 0
		var stats := stats_for_form(cards.get(base_id, {}), form)
		var title := "训练木桩" if id == "training_dummy" else String(stats.get("name", id))
		var kind := String(stats.get("type", "unit"))
		var system := base_id not in selectable or form != 0
		if not query.strip_edges().is_empty() and not (title + " " + id).to_lower().contains(query.strip_edges().to_lower()):
			continue
		if category == "system" and not system: continue
		if category == "cards" and system: continue
		if category in ["unit", "spell", "building"] and (kind != category or system): continue
		result.append({"id": id, "base_id": base_id, "name": title, "type": kind, "system": system})
	return result

static func has_forms(base: Dictionary) -> bool:
	return base.has("transformed_stats") or base.has("deployment_upgrade_id")

static func stats_for_form(base: Dictionary, form: int) -> Dictionary:
	if form == 1 and base.has("deployment_upgrade_id"):
		return CardDB.get_card(String(base.deployment_upgrade_id))
	return PresentationConfig.for_form(base, form)

static func deployment_id(base_id: String, form: int) -> String:
	var base := CardDB.get_card(base_id)
	return String(base.deployment_upgrade_id) if form == 1 and base.has("deployment_upgrade_id") else base_id
