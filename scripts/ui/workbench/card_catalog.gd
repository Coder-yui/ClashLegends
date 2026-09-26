extends RefCounted
## 工作台目录包含正式卡、独立形态和系统对象；只读定义，不参与正式卡组资格。

static func entries(cards: Dictionary, query: String = "", category: String = "all") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Array = cards.keys()
	ids.sort()
	for base_id in cards:
		for form in range(1, form_labels(cards[base_id]).size()):
			ids.append(selection_id(String(base_id), form))
	ids.push_front("training_dummy")
	var selectable := CardDB.selectable_ids()
	for raw_id in ids:
		var id := String(raw_id)
		var base_id := id.get_slice(":", 0)
		if cards.values().any(func(stats): return id in [String(stats.get("deployment_upgrade_id", "")), String(stats.get("growth_ranged_id", "")), String(stats.get("growth_melee_id", ""))]): continue
		var form := form_index(id)
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
	return form_labels(base).size() > 1

static func stats_for_form(base: Dictionary, form: int) -> Dictionary:
	if base.has("growth_ranged_id") and form in [1, 2]:
		return CardDB.get_card(String(base["growth_ranged_id" if form == 1 else "growth_melee_id"]))
	if form == 1 and base.has("deployment_upgrade_id"):
		return CardDB.get_card(String(base.deployment_upgrade_id))
	return PresentationConfig.for_form(base, form)

static func deployment_id(base_id: String, form: int) -> String:
	var base := CardDB.get_card(base_id)
	if base.has("growth_ranged_id") and form in [1, 2]:
		return String(base["growth_ranged_id" if form == 1 else "growth_melee_id"])
	return String(base.deployment_upgrade_id) if form == 1 and base.has("deployment_upgrade_id") else base_id

static func form_index(id: String) -> int:
	return int(id.get_slice(":", 1)) if id.contains(":") else 0

static func selection_id(base_id: String, form: int) -> String:
	return base_id + (":" + str(form) if form > 0 else "")

static func form_labels(base: Dictionary) -> Array[String]:
	if base.has("growth_ranged_id"): return ["普通形态", "蓝凯形态", "红凯形态"]
	if base.has("deployment_upgrade_id"): return ["近战形态", "远程形态"]
	if base.has("transformed_stats"): return ["基础形态", "变形形态"]
	return ["基础形态"]

static func canonical_id(id: String, cards: Dictionary) -> String:
	for base_id in cards:
		for form in range(1, form_labels(cards[base_id]).size()):
			if id != base_id and deployment_id(base_id, form) == id:
				return selection_id(base_id, form)
	return id
