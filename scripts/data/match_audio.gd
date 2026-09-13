extends RefCounted
## 中文默认播报，仅这三种事件进入实战。
const EVENTS = {
	"victory": {
		"pool": [
			"res://assets/audio/announcer/victory_r1.wav"
		],
		"volume_db": 0.0
	},
	"defeat": {
		"pool": [
			"res://assets/audio/announcer/defeat_r1.wav"
		],
		"volume_db": 0.0
	},
	"minions_spawn": {
		"pool": [
			"res://assets/audio/announcer/minions_spawn_r1.wav"
		],
		"volume_db": 0.0
	}
}
