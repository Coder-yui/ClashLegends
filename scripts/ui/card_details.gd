class_name CardDetails
extends RefCounted
## 只读卡牌展示数据；供详情 UI 与内容回归共用，不持有界面或对局状态。

const TILE_SIZE := ArenaRules.TILE_SIZE

static func type_name(card_type: String, stats: Dictionary = {}) -> String:
	match card_type:
		"spell": return "法术"
		"building": return "建筑"
		_:
			return "空军" if bool(stats.get("is_air", false)) else "地面"

static func brief_description(stats: Dictionary) -> String:
	var description := String(stats.get("description", ""))
	return description if not description.is_empty() else "这张卡可以通过合理的部署位置和出牌时机发挥作用。"

static func attributes(stats: Dictionary, quantity_override: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var card_type := String(stats.get("type", "unit"))
	if String(stats.get("spell_kind", "")) == "mirror":
		return [{"name": "费用", "value": "上一张卡本身费用"}, {"name": "复制目标", "value": "上一张成功使用的卡"}, {"name": "开局", "value": "仅进入后四张队列"}]
	if card_type == "spell":
		result.append({"name": "类型", "value": type_name(card_type, stats)})
		var target := "友方单位" if StringName(stats.get("spell_kind", "")) == &"heal" else "敌方单位"
		result.append({"name": "目标", "value": target})
		result.append({"name": "作用范围", "value": "%s（%.2f格）" % [format_number(float(stats.get("radius", 0.0))), float(stats.get("radius", 0.0)) / TILE_SIZE]})
		result.append({"name": "持续时间", "value": "%s秒" % format_number(float(stats.get("duration", 0.0)))})
		return result

	var quantity := quantity_override if not quantity_override.is_empty() else str(maxi(int(stats.get("deployment_count", 1)), 1))
	if card_type == "unit" and stats.has("deployment_member_ids"):
		var member_ids: Array = stats.get("deployment_member_ids", [])
		var unique_members := {}
		for member_id in member_ids:
			unique_members[String(member_id)] = true
		result.append({"name": "类型", "value": "混合地面编队" if unique_members.size() > 1 else "地面编队"})
		result.append({"name": "成员", "value": deployment_member_summary(stats)})
		result.append({"name": "站位", "value": deployment_formation_name(stats)})
		return result
	result.append({"name": "生命", "value": format_number(roundf(float(stats.get("hp", 0.0))))})
	result.append({"name": "类型", "value": type_name(card_type, stats)})
	if card_type == "building":
		result.append({"name": "数量", "value": quantity})
		result.append({"name": "目标", "value": target_name(stats)})
		var building_damage := float(stats.get("damage", 0.0))
		var building_interval := float(stats.get("interval", 0.0))
		if building_damage > 0.0:
			result.append({"name": "单次伤害", "value": format_number(roundf(building_damage))})
			if building_interval > 0.0:
				result.append({"name": "每秒伤害", "value": format_number(roundf(building_damage / building_interval))})
				result.append({"name": "攻击间隔", "value": "%s秒" % format_number(building_interval)})
			if stats.has("range"):
				var building_range := float(stats.get("range", 0.0))
				result.append({"name": "攻击距离", "value": "%s（%.2f格）" % [format_number(building_range), building_range / TILE_SIZE]})
		if float(stats.get("splash_radius", 0.0)) > 0.0:
			var splash_radius := float(stats.get("splash_radius", 0.0))
			result.append({"name": "溅射半径", "value": "%s（%.2f格）" % [format_number(splash_radius), splash_radius / TILE_SIZE]})
		if stats.has("footprint_tiles") or stats.has("radius"):
			result.append({"name": "体积", "value": volume_name(stats)})
		if stats.has("lifespan"):
			var lifespan_suffix := "（生命持续衰减）" if bool(stats.get("lifespan_hp_decay", false)) else ""
			result.append({"name": "存活时间", "value": "%s秒%s" % [format_number(float(stats.get("lifespan", 0.0))), lifespan_suffix]})
		return result

	result.append({"name": "目标", "value": target_name(stats)})
	if stats.has("sight") and float(stats.get("sight", 0.0)) > 0.0:
		result.append({"name": "视野", "value": format_number(float(stats.get("sight", 0.0)))})
	var speed := float(stats.get("speed", 0.0))
	if stats.has("speed"):
		result.append({"name": "移速", "value": "%s/秒（%s）" % [format_number(speed), CardDB.speed_tier_name(speed)]})
	# 数量占据原视野所在的位序，视野统一放到属性列表最后。
	result.append({"name": "数量", "value": quantity})
	var damage := float(stats.get("damage", 0.0))
	var continuous := bool(stats.get("is_continuous_attack", false))
	var damage_multipliers: Array = stats.get("attack_damage_multipliers", [])
	if not continuous and damage > 0.0:
		if damage_multipliers.is_empty():
			result.append({"name": "单次伤害", "value": format_number(roundf(damage))})
		else:
			var fist_names := ["左拳", "右拳", "左拳", "右拳"]
			var fist_values: Array[String] = []
			for index in range(mini(damage_multipliers.size(), 2)):
				var fist_name: String = fist_names[index % fist_names.size()]
				var fist_damage := damage * float(damage_multipliers[index])
				fist_values.append("%s（%s）" % [format_number(roundf(fist_damage)), fist_name])
			result.append({"name": "单次伤害", "value": "，".join(fist_values)})
	var interval := float(stats.get("interval", 0.0))
	var dps: float = damage if continuous else (damage / interval if interval > 0.0 and damage > 0.0 else 0.0)
	if not continuous and not damage_multipliers.is_empty():
		var combo_pattern: Array = stats.get("attack_pattern", [])
		if combo_pattern.size() > 1:
			var combo_damage := BattleNumbers.quantity(damage * float(damage_multipliers[0])) + BattleNumbers.quantity(damage * float(damage_multipliers[1]))
			var combo_interval := float(stats.get("attack_interval_display", combo_pattern[1])) + float(combo_pattern[0])
			if combo_interval > 0.0:
				dps = combo_damage / combo_interval
	if damage > 0.0:
		result.append({"name": "每秒伤害", "value": format_number(roundf(dps))})
	if not continuous and interval > 0.0:
		var display_interval := float(stats.get("attack_interval_display", interval))
		result.append({"name": "攻击间隔", "value": "%s秒" % format_number(display_interval)})
	if damage > 0.0 and stats.has("range"):
		result.append({"name": "攻击距离", "value": "%s（%.2f格）" % [format_number(float(stats.get("range", 0.0))), float(stats.get("range", 0.0)) / TILE_SIZE]})
	if stats.has("radius"):
		result.append({"name": "体积", "value": volume_name(stats)})
	if stats.has("mass"):
		result.append({"name": "质量", "value": format_number(float(stats.get("mass", 0.0)))})
	return result

static func target_name(stats: Dictionary) -> String:
	if String(stats.get("type", "unit")) == "spell":
		return "敌方单位"
	if float(stats.get("damage", 0.0)) <= 0.0:
		return "无"
	if bool(stats.get("building_only", false)):
		return "建筑"
	return "空中和地面" if bool(stats.get("can_attack_air", false)) else "地面"

static func deployment_member_summary(stats: Dictionary) -> String:
	var counts := {}
	var order: Array[String] = []
	for raw_id in stats.get("deployment_member_ids", []):
		var id := String(raw_id)
		if not counts.has(id):
			counts[id] = 0
			order.append(id)
		counts[id] += 1
	var parts: Array[String] = []
	for id in order:
		var member_stats := CardDB.get_card(id)
		parts.append("%s×%d" % [String(member_stats.get("name", id)), int(counts[id])])
	return "、".join(parts)

static func deployment_formation_name(stats: Dictionary) -> String:
	var count := maxi(int(stats.get("deployment_count", stats.get("deployment_member_ids", []).size())), 1)
	match StringName(stats.get("deployment_formation", "ring")):
		&"polygon":
			if count == 3:
				return "三角形三个顶点"
			if count == 6:
				return "六边形六个顶点"
			return "正多边形%d个顶点" % count
		&"square": return "正方形四个顶点"
		&"line": return "横排%d名" % count
		&"depth_line": return "前后纵列%d名" % count
		_: return "环形%d名" % count

static func volume_name(stats: Dictionary) -> String:
	if stats.has("footprint_tiles"):
		var footprint: Vector2i = stats.footprint_tiles
		return "%d×%d格（半径%s）" % [footprint.x, footprint.y, format_number(float(stats.get("radius", 0.0)))]
	var tier := String(stats.get("size_tier", ""))
	var tier_name := CardDB.size_tier_name(StringName(tier)) if not tier.is_empty() else ""
	return "%s（半径%s）" % [tier_name, format_number(float(stats.get("radius", 0.0)))] if not tier_name.is_empty() else format_number(float(stats.get("radius", 0.0)))

static func passives(stats: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if float(stats.get("attack_wave_damage", 0.0)) > 0.0:
		result.append({"name": "焰浪", "description": "每次远程普攻附带一道固定方向的穿透焰浪，光剑出手后延迟%s秒发出，按主目标锁定对空或对地，沿出手瞬间固定的轴线横向1→2倍线性扩宽（最大合法射程含余波为标尺），终点为当时目标位置后%s格；对同类别敌人造成%d伤害一次（对地包含塔和水晶），可与光剑伤害叠加。焰浪不额外叠加攻速被动。" % [format_number(float(stats.attack_wave_delay)), format_number(float(stats.attack_wave_tail_distance) / TILE_SIZE), int(stats.attack_wave_damage)]})
	if int(stats.get("hit_haste_max_stacks", 0)) > 0:
		result.append({"name": "登神之阶", "description": "每次普攻实际命中获得1层，每层提高%s%%攻速，最多%d层；每次命中刷新全部层数的%s秒持续时间，溅射多人只获得1层。" % [format_number(float(stats.hit_haste_per_stack) * 100.0), int(stats.hit_haste_max_stacks), format_number(float(stats.hit_haste_duration))]})
	if float(stats.get("rush_distance", 0.0)) > 0.0:
		result.append({"name": "虚空冲撞", "description": "一生一次：距建筑%s格内，在最近的合法位置准备%s秒后冲撞。准备免击退，冻结/眩晕后重新准备；冲撞免控，沿途地面敌军受到%d伤害并被挤向两旁。准备、冲撞及撞后收势期间不能施放其他主动技能。撞击建筑造成%d伤害，扣自身当前生命%s%%，爆发%d只虚空蠕虫。桥面可冲，不能穿过河水。" % [format_number(float(stats.rush_distance) / TILE_SIZE), format_number(float(stats.rush_prepare_time)), int(stats.rush_path_damage), int(stats.rush_building_damage), format_number(float(stats.rush_self_health_ratio) * 100), int(stats.rush_spawn_count)]})

	if bool(stats.get("is_continuous_attack", false)):
		result.append({"name": "龙息", "description": "持续造成每秒%s伤害，并对目标周围%s范围造成伤害。" % [format_number(float(stats.get("damage", 0.0))), format_number(float(stats.get("splash_radius", 0.0)))]})
	elif float(stats.get("splash_radius", 0.0)) > 0.0 and float(stats.get("damage", 0.0)) > 0.0:
		result.append({"name": "范围炮击", "description": "普通攻击命中后，对目标周围%s（%.2f格）范围造成同等伤害。" % [format_number(float(stats.get("splash_radius", 0.0))), float(stats.get("splash_radius", 0.0)) / TILE_SIZE]})
	if stats.has("pre_deploy_sweep_damage"):
		result.append({
			"name": "登场冲击波",
			"description": "从落点后方%s格滑向落点，半径%s像素，波及地面敌人时造成%s点伤害；每个目标一次。到点后才生成单位。" % [format_number(float(stats.pre_deploy_sweep_distance) / ArenaRules.TILE_SIZE), format_number(float(stats.pre_deploy_sweep_radius)), format_number(float(stats.pre_deploy_sweep_damage))]
		})
	if stats.has("deploy_sweep_radius"):
		var deploy_damage := float(stats.get("deploy_sweep_damage", 0.0))
		result.append({
			"name": String(stats.get("deploy_sweep_name", "部署横扫")),
			"description": (
				"部署时对%s半径内的地面敌人造成%s点伤害%s。"
				% [format_number(float(stats.get("deploy_sweep_radius", 0.0))), format_number(roundf(deploy_damage)), "并击退" if float(stats.get("deploy_sweep_knockback", 0.0)) > 0.0 else ""]
			),
		})
	if stats.has("heal_every_hits"):
		result.append({"name": String(stats.get("heal_on_hit_name", "无畏战吼")), "description": "每第%d次普通攻击命中回复%s点生命。" % [int(stats.get("heal_every_hits", 0)), format_number(roundf(float(stats.get("heal_amount", 0.0)))) ]})
	if float(stats.get("on_hit_max_health_ratio", 0.0)) > 0.0:
		var scope := "普攻与每次剪切" if (stats.get("active_skills", []) as Array).any(func(skill): return bool(skill.get("applies_on_hit_passive",false))) else "普通攻击命中"
		result.append({"name": String(stats.get("on_hit_passive_name", "千穿百孔")), "description": "%s附加目标最大生命值%s%%的伤害（四舍五入）；对防御塔和水晶固定附加%d点。" % [scope, format_number(float(stats.on_hit_max_health_ratio) * 100.0), roundi(float(stats.get("on_hit_tower_damage", 0.0)))]})
	if stats.has("first_strike_damage_multiplier"):
		result.append({"name": "先声夺人", "description": "对每个敌方目标的首次普通攻击造成%s倍伤害。" % format_number(float(stats.get("first_strike_damage_multiplier", 0.0)))})
	if int(stats.get("transform_after_hits", 0)) > 0:
		var transformed: Dictionary = stats.get("transformed_stats", {})
		result.append({
			"name": "狂怒基因",
			"description": "小纳尔完成%d次普攻后变大，大纳尔完成%d次普攻后变小；大形态生命上限为%s、体型为%s且只能近战地面目标。" % [
				int(stats.transform_after_hits),
				int(stats.get("revert_after_hits", 0)),
				format_number(roundf(float(transformed.get("hp", 0.0)))),
				CardDB.size_tier_name(StringName(transformed.get("size_tier", ""))),
			],
		})
	if stats.has("attack_pattern"):
		var combo_damage := float(stats.get("damage", 0.0))
		var combo_multipliers: Array = stats.get("attack_damage_multipliers", [])
		var left_damage := combo_damage
		var right_damage := combo_damage * 1.5
		if not combo_multipliers.is_empty():
			left_damage = combo_damage * float(combo_multipliers[0])
			if combo_multipliers.size() > 1:
				right_damage = combo_damage * float(combo_multipliers[1])
		var combo_pattern: Array = stats.get("attack_pattern", [])
		var punch_gap := float(combo_pattern[0]) if not combo_pattern.is_empty() else 0.0
		var pair_gap := float(stats.get("attack_interval_display", combo_pattern[1] if combo_pattern.size() > 1 else stats.get("interval", 0.0)))
		result.append({"name": "拳锋连击", "description": "左拳造成%s点伤害，右拳造成%s点伤害；两拳之间间隔%s秒，打完两拳后间隔%s秒，循环进行。" % [format_number(roundf(left_damage)), format_number(roundf(right_damage)), format_number(punch_gap), format_number(pair_gap)]})
	if String(stats.get("type", "unit")) == "building" and float(stats.get("spawn_interval", 0.0)) > 0.0:
		var spawn_id := String(stats.get("spawn_id", ""))
		var spawn_stats := CardDB.get_unit_stats(spawn_id)
		var spawn_name := String(spawn_stats.get("name", spawn_id))
		result.append({"name": "周期召唤", "description": "部署完成生成%d只%s，之后每%s秒再次生成。" % [int(stats.get("spawn_count", 0)), spawn_name, format_number(float(stats.get("spawn_interval", 0.0)))]})
	if int(stats.get("death_spawn_count", 0)) > 0 and not String(stats.get("death_spawn_id", "")).is_empty():
		var death_spawn_id := String(stats.get("death_spawn_id", ""))
		var death_spawn_stats := CardDB.get_unit_stats(death_spawn_id)
		var death_spawn_name := String(death_spawn_stats.get("name", death_spawn_id))
		result.append({"name": "亡语", "description": "被摧毁时产生%d只%s。" % [int(stats.get("death_spawn_count", 0)), death_spawn_name]})
	return result

static func active_choice_description(card_id: String, selected_index: int = 0) -> String:
	var skills := CardDB.active_skills_for(card_id)
	if skills.is_empty():
		var stats: Dictionary = CardDB.get_card(card_id)
		if String(stats.get("type", "unit")) == "spell":
			var radius := float(stats.get("radius", 0.0))
			match StringName(stats.get("spell_kind", "")):
				&"mirror":
					return "复制体携带备战选定的技能，无论原卡是否位于主动槽。技能占用镜像自己的槽；再次镜像替换旧资格，旧单位仍然存活。复制法术时启用其强化效果。技能费用、次数、冷却沿用原技能。"
				&"heal":
					return "回复半径%s（%.2f格）内友军单位%s生命（不作用于建筑）。" % [
						format_number(radius), radius / TILE_SIZE, format_number(float(stats.get("heal_amount", 0.0))),
					]
				_:
					var duration := float(stats.get("duration", 0.0))
					var slow_duration := float(stats.get("active_slow_duration", 0.0))
					if slow_duration > 0.0:
						var slow_percent := format_number(float(stats.get("active_slow_multiplier", 1.0)) * 100.0)
						return "冻结半径%s（%.2f格）内的敌方单位，持续%s秒；冰冻结束后，范围内的敌军继续减速至%s%%，持续%s秒。" % [format_number(radius), radius / TILE_SIZE, format_number(duration), slow_percent, format_number(slow_duration)]
					return "冻结半径%s（%.2f格）内的敌方单位，持续%s秒。" % [format_number(radius), radius / TILE_SIZE, format_number(duration)]
		return "该卡没有可携带的主动技能。"
	var selected := clampi(selected_index, 0, skills.size() - 1)
	return active_skill_description(skills[selected])

static func active_skill_description(skill: Dictionary) -> String:
	var configured_description := String(skill.get("description", ""))
	if not configured_description.is_empty():
		return "%s：%s" % [String(skill.get("name", "主动技能")), configured_description]
	var parts: Array[String] = []
	match String(skill.get("kind", "")):
		"nova":
			parts.append("以自身为中心，影响 %s 半径" % format_number(float(skill.get("radius", 0.0))))
			if float(skill.get("damage", 0.0)) > 0.0:
				parts.append("造成 %s 伤害" % format_number(roundf(float(skill.damage))))
			if float(skill.get("knockback", 0.0)) > 0.0:
				parts.append("击退 %s" % format_number(float(skill.knockback)))
			if float(skill.get("slow_duration", 0.0)) > 0.0:
				parts.append("减速至 %s%%，持续 %s 秒" % [format_number(float(skill.get("slow_multiplier", 1.0)) * 100.0), format_number(float(skill.slow_duration))])
		"buff":
			if float(skill.get("heal_amount", 0.0)) > 0:
				parts.append("回复 %s 点生命" % format_number(float(skill.heal_amount)))
			parts.append("持续 %s 秒" % format_number(float(skill.get("duration", 0.0))))
			if float(skill.get("speed_multiplier", 1.0)) != 1.0:
				parts.append("移速 ×%.2f" % float(skill.speed_multiplier))
			if float(skill.get("damage_multiplier", 1.0)) != 1.0:
				parts.append("伤害 ×%.2f" % float(skill.damage_multiplier))
			if float(skill.get("attack_speed_multiplier", 1.0)) != 1.0:
				parts.append("攻速 ×%.2f" % float(skill.attack_speed_multiplier))
		"summon":
			var spawn_id := String(skill.get("spawn_id", ""))
			var spawn_stats := CardDB.get_unit_stats(spawn_id)
			parts.append("在自身周围立即召唤 %d 个%s" % [int(skill.get("spawn_count", 1)), String(spawn_stats.get("name", spawn_id))])
		"timed_form":
			parts.append("切换为限时强化形态；击杀敌方单位刷新持续时间与攻击循环")
		"dual_form":
			parts.append("变形并朝前方 %s×%s 区域造成 %s 伤害，眩晕 %s 秒" % [
				format_number(float(skill.get("width", 0.0))),
				format_number(float(skill.get("length", 0.0))),
				format_number(roundf(float(skill.get("damage", 0.0)))),
				format_number(float(skill.get("stun_duration", 0.0))),
			])
		"continuous_area":
			parts.append("以自身当前位置为中心，影响 %s 半径" % format_number(float(skill.get("radius", 0.0))))
			if float(skill.get("damage", 0.0)) > 0.0:
				parts.append("每 %s 秒造成 %s 伤害" % [
					format_number(float(skill.get("tick_interval", 1.0))),
					format_number(roundf(float(skill.get("damage", 0.0)))),
				])
			if float(skill.get("duration", 0.0)) > 0.0:
				parts.append("持续 %s 秒并跟随移动" % format_number(float(skill.get("duration", 0.0))))
		"restoration_shield":
			parts.append("同次部署的存活成员各自获得护盾；到期仍未破盾的成员回复至满血")
		"spell_heal":
			var heal_multiplier := maxf(float(skill.get("heal_multiplier", 1.0)), 1.0)
			var scope := "全图普通单位" if bool(skill.get("global_heal", false)) else "范围内普通单位"
			parts.append("%s治疗量 ×%.2f" % [scope, heal_multiplier])
			if bool(skill.get("global_heal", false)):
				parts.append("落点范围内额外提高治疗量")
			var shield_ratio := clampf(float(skill.get("overheal_shield_ratio", 0.0)), 0.0, 1.0)
			if shield_ratio > 0.0:
				parts.append("溢出治疗量的 %.0f%% 转为护盾，持续 %s 秒" % [shield_ratio * 100.0, format_number(float(skill.get("shield_duration", 0.0)))])
	if float(skill.get("shield", 0.0)) > 0.0:
		parts.append("获得 %s 点护盾，持续 %s 秒" % [format_number(float(skill.shield)), format_number(float(skill.get("shield_duration", 0.0)))])
	return "%s：%s。" % [String(skill.get("name", "主动技能")), "；".join(parts)]

static func format_number(value: float) -> String:
	return BattleNumbers.format_value(value)
