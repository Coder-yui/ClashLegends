extends ScrollContainer
## 与备战详情共用只读展示规则，展示当前观察形态。
var _body: VBoxContainer
var card_id := ""

func show_card(id: String, stats: Dictionary) -> void:
	card_id = id
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if _body != null:
		remove_child(_body)
		_body.queue_free()
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	add_child(_body)
	scroll_vertical = 0
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	_body.add_child(header)
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(72, 128)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture = CardArt.texture_for(id)
	header.add_child(art)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	_text(String(stats.get("name", "训练木桩")), 26, identity)
	_text("%s · %s" % [CardDetails.type_name(String(stats.get("type", "unit")), stats), id], 16, identity)
	if stats.is_empty():
		_text("实战测试用木桩，可用于观察伤害和控制效果。", 16, identity)
		return
	_text("费用：" + ("上一张卡本身费用" if String(stats.get("spell_kind", "")) == "mirror" else CardDetails.format_number(float(stats.get("cost", 0)))), 16, identity)
	_text(CardDetails.brief_description(stats), 16, identity)
	_attributes(stats, "属性")
	var abilities := GridContainer.new()
	abilities.columns = 2
	abilities.add_theme_constant_override("h_separation", 16)
	abilities.add_theme_constant_override("v_separation", 4)
	_body.add_child(abilities)
	for passive in CardDetails.passives(stats):
		var section := _section(abilities)
		_text(String(passive.name), 20, section)
		_text(String(passive.description), 16, section)
	var skills := CardDB.active_skills_for(id)
	for i in skills.size():
		var skill: Dictionary = skills[i]
		var section := _section(abilities)
		_text(String(skill.get("name", "主动技能")), 20, section)
		_text("消耗 %s · %d 次 · 冷却 %ss" % [CardDetails.format_number(float(skill.get("cost", 0))), int(skill.get("max_uses", 1)), CardDetails.format_number(float(skill.get("cooldown", 0)))], 16, section)
		_text(CardDetails.active_choice_description(id, i), 16, section)
	var upgraded_id := String(stats.get("deployment_upgrade_id", ""))
	if not upgraded_id.is_empty():
		var upgraded: Dictionary = CardDB.get_card(upgraded_id)
		_attributes(upgraded, String(upgraded.get("name", "强化部署")))

func _attributes(stats: Dictionary, title: String) -> void:
	_text(title, 20)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	_body.add_child(grid)
	for attribute in CardDetails.attributes(stats):
		for value in [attribute.name, attribute.value]:
			var label := Label.new()
			label.text = str(value)
			label.add_theme_font_size_override("font_size", 16)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			grid.add_child(label)

func _section(parent: Node) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	return box

func _text(value: String, font_size: int = 16, parent: Node = null) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	(parent if parent != null else _body).add_child(label)
