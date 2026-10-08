extends Node2D
## 公开释放提示：只消费可靠事件，屏幕直立，不参与权威模拟。
const LIFETIME := 1.35
var entries: Array[Dictionary] = []
var nexuses: Array = []
var presentation: BattlePresentation3D

func color_for(team: int) -> Color:
	return Color(0.25, 0.65, 1.0) if presentation.visual_team(team) == 0 else Color(1.0, 0.3, 0.35)

func show_cast(card_id: String, skill_index: int, team: int) -> void:
	if team < 0 or team >= nexuses.size(): return
	var skills := CardDB.active_skills_for(card_id)
	var texture: Texture2D = CardArt.skill_icon(CardDB.get_card(card_id))
	if texture == null and not skills.is_empty():
		texture = CardArt.skill_icon(skills[clampi(skill_index, 0, skills.size() - 1)])
	if texture == null: texture = CardArt.texture_for(card_id)
	entries.append({"team": team, "texture": texture, "age": 0.0})

func clear() -> void:
	entries.clear()
	queue_redraw()

func _process(delta: float) -> void:
	for entry in entries: entry.age += delta
	entries = entries.filter(func(entry): return float(entry.age) < LIFETIME)
	queue_redraw()

func _draw() -> void:
	var counts := [0, 0]
	for entry in entries: counts[int(entry.team)] += 1
	var indexes := [0, 0]
	for entry in entries:
		var team := int(entry.team)
		if not is_instance_valid(nexuses[team]): continue
		var age := float(entry.age)
		var alpha := smoothstep(0.0, 0.10, age) * (1.0 - smoothstep(0.75, LIFETIME, age))
		var center: Vector2 = nexuses[team].get_global_transform_with_canvas().origin
		var column := int(indexes[team]) % 5
		var row := int(indexes[team]) / 5
		center += Vector2((column - (mini(counts[team], 5) - 1) * 0.5) * (ActiveSkillBar.BUTTON_SIZE.x + 4.0), -105.0)
		var rise := smoothstep(0.65, LIFETIME, age) * 18.0
		center.y = maxf(center.y - rise, 80.0) + row * (ActiveSkillBar.BUTTON_SIZE.y + 4.0)
		indexes[team] += 1
		var size := ActiveSkillBar.ICON_SIZE.x
		var radius := size * 0.5
		var tint := Color(color_for(team), alpha)
		draw_circle(center, radius + 4.0, Color(0.02, 0.04, 0.08, 0.85 * alpha))
		if entry.texture != null:
			var points := PackedVector2Array()
			var uvs := PackedVector2Array()
			for i in 64:
				var direction := Vector2.from_angle(TAU * float(i) / 64.0)
				points.append(center + direction * radius)
				uvs.append(Vector2.ONE * 0.5 + direction * 0.5)
			draw_polygon(points, PackedColorArray([Color(1, 1, 1, alpha)]), uvs, entry.texture)
		else:
			draw_circle(center, 12, tint)
		draw_arc(center, radius + 2.0, 0.0, TAU, 64, tint, 2.5, true)
