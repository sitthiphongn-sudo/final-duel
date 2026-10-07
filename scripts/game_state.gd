extends RefCounted
## ข้อมูลตัวละครทั้งหมด + ตัวที่ถูกเลือก (ใช้ร่วมกันระหว่างฉากเลือกตัวละครกับฉากต่อสู้)
## ใช้แบบ: const GameState := preload("res://scripts/game_state.gd") แล้วเรียก GameState.p1 / GameState.data(id)
## เพิ่มตัวละครใหม่ = เพิ่ม entry ใน CHARACTERS แล้วจะโผล่ในฉากเลือกตัวละครเอง

static var p1 := "emberclaw"          ## ตัวที่ผู้เล่นเลือก
static var p2 := "frostfang"          ## คู่ต่อสู้ (บอท)
static var game_live := true         ## false = ฉากเกมกำลังถูกเตรียมอยู่ใต้หน้า VS (ยังไม่เปิดเสียง/เสียงพูด)

const ORDER := ["emberclaw", "frostfang"]

## ฉากต่อสู้ + ชื่อแมพ (แสดงในหน้า VS ตอนโหลด)
const BATTLE_SCENE := "res://scenes/main.tscn"
const MAP_NAME := "Skyborne Ruins"
const MAP_BG := "res://ui/vs/bg_skyborne.jpg"

## ข้อมูลแมพ (หน้า MAPS ในเมนู)
const MAPS := [
	{
		"name": "SKYBORNE RUINS",
		"image": "res://ui/vs/bg_skyborne.jpg",
		"location": "Floating isles above the Cloud Sea",
		"mode": "1v1 Duel",
		"size": "Medium · Circular stone arena",
		"time": "Golden afternoon",
		"hazards": "Open edges · Fall and you respawn",
		"desc": "An ancient temple ring that drifted into the sky long ago. Broken pillars circle a carved seal where the guardians settle their duels, high above an endless sea of clouds.",
	},
]

const CHARACTERS := {
	"emberclaw": {
		"name": "EMBERCLAW",
		"title": "Guardian of the Flame",
		"desc": "Born in the heart of a dying volcano, Emberclaw fights up close and never backs down. He chains blazing five-hit combos into a sky-splitting air rush, then drives his foes back into the stone.",
		"style": "Rushdown · Close range",
		"element": "fire",
		"walk_glb": "res://lite/characters/emberclaw.tscn",
		"run_glb": "res://lite/characters/emberclaw_run_anim.res",
		"portrait": "res://ui/portrait_fire.png",
		"card": "res://ui/card_emberclaw.png",
		"vs_l": "res://ui/vs/emberclaw_l.png", "vs_r": "res://ui/vs/emberclaw_r.png",
		"hp": 2000, "atk": 23,
		"color": Color(1.0, 0.45, 0.18),
		"vfx_color": Color(1.0, 0.62, 0.25),
		"hp_color": Color(0.90, 0.16, 0.10),
		"ex_name": "FURY", "ex_color": Color(1.0, 0.52, 0.10),
		"flipbook": "res://vfx/fire_flipbook_8x8.png",
		"fire": [Color(1.0, 0.95, 0.75), Color(1.0, 0.55, 0.12), Color(0.85, 0.2, 0.03), Color(1.0, 0.8, 0.4), Color(1.0, 0.52, 0.18)],
		"abilities": [
			["J", "×5", "Blazing Five-Strike"],
			["K", "", "Rising Flame Kick"],
			["Q", "", "Ember Warp"],
			["R", "", "Inferno Rush"],
		],
		"physical": [95, 90, 100],
		"elemental": [50, 120, 100, 100, 95, 115],
	},
	"frostfang": {
		"name": "FROSTFANG",
		"title": "Guardian of the Glacier",
		"desc": "The silent keeper of the frozen peaks. Frostfang is patient and cold, blocking more often than he strikes and punishing every mistake with a storm of ice-blue fists.",
		"style": "Counter · Defensive",
		"element": "ice",
		"walk_glb": "res://lite/characters/frostfang.tscn",
		"run_glb": "res://lite/characters/frostfang_run_anim.res",
		"portrait": "res://ui/portrait_ice.png",
		"card": "res://ui/card_frostfang.png",
		"vs_l": "res://ui/vs/frostfang_l.png", "vs_r": "res://ui/vs/frostfang_r.png",
		"hp": 2200, "atk": 21,
		"color": Color(0.35, 0.72, 1.0),
		"vfx_color": Color(0.35, 0.72, 1.0),
		"hp_color": Color(0.16, 0.48, 0.95),
		"ex_name": "MAGIC", "ex_color": Color(0.35, 0.82, 1.0),
		"flipbook": "res://vfx/fire_flipbook_blue_8x8.png",
		"fire": [Color(0.85, 0.97, 1.0), Color(0.18, 0.62, 1.0), Color(0.06, 0.22, 0.75), Color(0.6, 0.92, 1.0), Color(0.25, 0.6, 1.0)],
		"abilities": [
			["J", "×5", "Frost Fang Barrage"],
			["K", "", "Glacier Kick"],
			["Q", "", "Blizzard Warp"],
			["R", "", "Absolute Zero Rush"],
		],
		"physical": [100, 95, 95],
		"elemental": [120, 50, 105, 100, 100, 90],
	},
}

## ชื่อไอคอนในแผงสถานะ (ui/icons/<name>.png)
const PHYSICAL_ICONS := ["strike", "slash", "guard"]
const ELEMENT_ICONS := ["fire", "ice", "bolt", "wind", "earth", "water"]

## ชื่อปุ่ม (แสดงบนจอ) ของผู้เล่นแต่ละคน
const CONTROLS_TEXT := {
	1: "P1   WASD move · Space jump · J punch · K kick · L block · Q dash · R ultimate · Shift run",
	2: "P2   Arrows move · Num0 jump · Num1 punch · Num2 kick · Num3 block · Num4 dash · Num5 ultimate · NumEnter run",
}


static func data(id: String) -> Dictionary:
	return CHARACTERS.get(id, CHARACTERS["emberclaw"])


## ปุ่มของผู้เล่น 2 คน (คีย์บอร์ดเดียวกัน + จอยคนละตัว) สร้างครั้งเดียว
##   P1: WASD เดิน | Space กระโดด | J ต่อย | K เตะ | L บล็อก | Q Dash | R อัลติเมต | Shift ซ้าย วิ่ง
##   P2: ลูกศร เดิน | Num0 กระโดด | Num1 ต่อย | Num2 เตะ | Num3 บล็อก | Num4 Dash | Num5 อัลติเมต | Num Enter วิ่ง
##       (โน้ตบุ๊กไม่มี Numpad: Ctrl ขวา กระโดด | , ต่อย | . เตะ | / บล็อก | ; Dash | ' อัลติเมต | Shift ขวา วิ่ง)
##   จอย: ตัวแรก = P1, ตัวที่สอง = P2 (A กระโดด, X ต่อย, Y เตะ, RB บล็อก, B Dash, RT อัลติเมต, LB วิ่ง)
static func setup_inputs() -> void:
	if InputMap.has_action("p1_punch"):
		return
	var L := KEY_LOCATION_LEFT
	var R := KEY_LOCATION_RIGHT
	var keys := {
		1: {
			"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
			"run": [[KEY_SHIFT, L]], "jump": [KEY_SPACE], "punch": [KEY_J], "kick": [KEY_K],
			"block": [KEY_L], "dash": [KEY_Q], "ultimate": [KEY_R],
		},
		2: {
			"move_forward": [KEY_UP], "move_back": [KEY_DOWN], "move_left": [KEY_LEFT], "move_right": [KEY_RIGHT],
			"run": [KEY_KP_ENTER, [KEY_SHIFT, R]], "jump": [KEY_KP_0, [KEY_CTRL, R]],
			"punch": [KEY_KP_1, KEY_COMMA], "kick": [KEY_KP_2, KEY_PERIOD], "block": [KEY_KP_3, KEY_SLASH],
			"dash": [KEY_KP_4, KEY_SEMICOLON], "ultimate": [KEY_KP_5, KEY_APOSTROPHE],
		},
	}
	var pads := {
		"jump": JOY_BUTTON_A, "punch": JOY_BUTTON_X, "kick": JOY_BUTTON_Y, "dash": JOY_BUTTON_B,
		"block": JOY_BUTTON_RIGHT_SHOULDER, "run": JOY_BUTTON_LEFT_SHOULDER,
		"move_forward": JOY_BUTTON_DPAD_UP, "move_back": JOY_BUTTON_DPAD_DOWN,
		"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT,
	}
	var sticks := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
		"ultimate": [JOY_AXIS_TRIGGER_RIGHT, 1.0]}
	for pi in keys:
		var dev: int = pi - 1
		for a in keys[pi]:
			var act := "p%d_%s" % [pi, a]
			InputMap.add_action(act, 0.3)
			for k in keys[pi][a]:
				var ev := InputEventKey.new()
				if k is Array:
					ev.physical_keycode = k[0]
					ev.location = k[1]
				else:
					ev.physical_keycode = k
				InputMap.action_add_event(act, ev)
			if pads.has(a):
				var jb := InputEventJoypadButton.new()
				jb.device = dev
				jb.button_index = pads[a]
				InputMap.action_add_event(act, jb)
			if sticks.has(a):
				var jm := InputEventJoypadMotion.new()
				jm.device = dev
				jm.axis = sticks[a][0]
				jm.axis_value = sticks[a][1]
				InputMap.action_add_event(act, jm)


## เลือกคู่ต่อสู้ให้อัตโนมัติ (ตัวอื่นที่ไม่ใช่ตัวที่เลือก, สุ่มถ้ามีหลายตัว)
static func pick_opponent(me: String) -> String:
	var pool: Array = []
	for id in ORDER:
		if id != me:
			pool.append(id)
	return pool.pick_random() if not pool.is_empty() else me


## เปลี่ยนโมเดลของตัวละคร (node ชื่อ Model) ให้เป็นตัวที่ต้องการ ก่อนสร้างแอนิเมชัน
static func swap_model(owner: Node3D, old_model: Node3D, id: String) -> Node3D:
	var d := data(id)
	var scene_path: String = old_model.scene_file_path
	if scene_path == d["walk_glb"]:
		return old_model
	var ps := load(d["walk_glb"]) as PackedScene
	if ps == null:
		return old_model
	var m := ps.instantiate() as Node3D
	var idx := old_model.get_index()
	m.transform = old_model.transform
	owner.remove_child(old_model)
	old_model.queue_free()
	m.name = "Model"
	owner.add_child(m)
	owner.move_child(m, idx)
	return m

# ================= ตั้งค่าเสียง (บันทึกใน user://settings.cfg) =================

const SETTINGS_PATH := "user://settings.cfg"
const AUDIO_DEFAULTS := {"master": 0.8, "music": 0.75, "sfx": 0.9}
static var audio := {"master": 0.8, "music": 0.75, "sfx": 0.9}
static var _settings_ready := false

## คุณภาพกราฟิก: 0 = LOW (ลื่นสุด, ค่าเริ่มต้นบนเว็บ), 1 = MEDIUM, 2 = HIGH (ค่าเริ่มต้นบนคอม)
const GFX_NAMES := ["LOW", "MEDIUM", "HIGH"]
static var gfx := 2
static var show_fps := false


## เรียกตอนเริ่มฉากใดก็ได้ (ครั้งแรกจะโหลดค่าจากไฟล์ + สร้าง bus + ใช้ค่า)
static func init_settings() -> void:
	setup_fonts()
	ensure_audio_buses()
	if not _settings_ready:
		_settings_ready = true
		gfx = default_gfx()
		var cfg := ConfigFile.new()
		if cfg.load(SETTINGS_PATH) == OK:
			for k in AUDIO_DEFAULTS:
				audio[k] = clampf(float(cfg.get_value("audio", k, AUDIO_DEFAULTS[k])), 0.0, 1.0)
		gfx = clampi(int(cfg.get_value("video", "quality", default_gfx())), 0, 2)
		show_fps = bool(cfg.get_value("video", "show_fps", false))
	apply_audio()
	apply_graphics()


## ฟอนต์หลักไม่มีตัวอักษรไทย -> ใช้ Loma เป็นฟอนต์สำรอง (ชื่อผู้พัฒนาในเครดิต ฯลฯ)
static func setup_fonts() -> void:
	var thai := load("res://fonts/Loma.otf") as Font
	if thai == null:
		return
	for path in ["res://fonts/MPLUSRounded1c-Medium.woff2", "res://fonts/BarlowCondensed-BoldItalic.woff2"]:
		var f := load(path) as Font
		if f and not f.fallbacks.has(thai):
			var fb := f.fallbacks.duplicate()
			fb.append(thai)
			f.fallbacks = fb


## bus เสียง: Master > Music (เพลง), SFX (เอฟเฟกต์ + เสียงพูด)
static func ensure_audio_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")


static func apply_audio() -> void:
	var map := {"master": "Master", "music": "Music", "sfx": "SFX"}
	for k in map:
		var i := AudioServer.get_bus_index(map[k])
		if i >= 0:
			var v: float = audio[k]
			AudioServer.set_bus_mute(i, v <= 0.001)
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


static func set_volume(key: String, v: float) -> void:
	audio[key] = clampf(v, 0.0, 1.0)
	apply_audio()


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in audio:
		cfg.set_value("audio", k, audio[k])
	cfg.set_value("video", "quality", gfx)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.save(SETTINGS_PATH)


# ================= กราฟิก =================

static func default_gfx() -> int:
	return 0 if OS.has_feature("web") else 2


## ค่ารวมทั้งเกม (ใช้กับทุกฉาก): ความละเอียดภาพ 3D + คุณภาพเงา
static func apply_graphics() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var vp := tree.root
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = [0.7, 0.85, 1.0][gfx]          # เรนเดอร์ 3D เล็กลงแล้วขยาย (UI ยังคมเหมือนเดิม)
	RenderingServer.directional_soft_shadow_filter_set_quality([0, 1, 2][gfx])
	RenderingServer.directional_shadow_atlas_set_size([2048, 2048, 4096][gfx], true)


static func set_gfx(level: int) -> void:
	gfx = clampi(level, 0, 2)
	apply_graphics()


## ปรับฉากต่อสู้/ฉากโชว์ตามระดับกราฟิก (ท้องฟ้า, glow, เงา, แสง)
static func apply_scene_graphics(scene: Node) -> void:
	for we in scene.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (we as WorldEnvironment).environment
		if env == null:
			continue
		env = env.duplicate(true)          # อย่าแก้ resource ต้นฉบับที่แคชไว้ (เผื่อเปลี่ยนระดับกลางเกม)
		(we as WorldEnvironment).environment = env
		env.glow_enabled = env.glow_enabled and gfx >= 2
		if env.sky:
			env.sky.radiance_size = Sky.RADIANCE_SIZE_32 if gfx < 2 else Sky.RADIANCE_SIZE_64
			var sm := env.sky.sky_material as ShaderMaterial
			if sm:
				sm.set_shader_parameter("octaves", [3, 4, 6][gfx])
				sm.set_shader_parameter("cheap", gfx < 2)
	for l in scene.find_children("*", "DirectionalLight3D", true, false):
		var sun := l as DirectionalLight3D
		if gfx == 0:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			sun.directional_shadow_max_distance = minf(sun.directional_shadow_max_distance, 24.0)
		elif gfx == 1:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = minf(sun.directional_shadow_max_distance, 30.0)


## ตัวคูณจำนวนอนุภาค/เศษหิน
static func fx_scale() -> float:
	return [0.5, 0.75, 1.0][gfx]
