extends Node3D
## ฉากโชว์สำหรับอัดคลิปไปใส่สไลด์ (ไม่มี HUD / ไม่มีการต่อสู้)
##
## วิธีใช้: เปิด scenes/showcase.tscn แล้วกด F6 (Run Current Scene)
##   1 = Emberclaw หมุน 360°      2 = Frostfang หมุน 360°      3 = บินกล้องรอบแมพ
##   B = สลับพื้นหลังตัวละคร (สตูดิโอมืด / ในแมพจริง)
##   C = ซ่อน/โชว์ตัวละครในโหมดแมพ     N = โชว์/ซ่อนชื่อตัวละคร
##   Space = หยุด/เล่นต่อ     R = เริ่มหมุนใหม่จากด้านหน้า     ← → = ช้าลง / เร็วขึ้น
##   H = โชว์/ซ่อนคำแนะนำ     Esc = ออก
##
## อัดเป็นไฟล์วิดีโอได้เลยด้วย Movie Maker ของ Godot (ภาพลื่น ไม่ตกเฟรม):
##   godot --path . --write-movie clip.avi --fixed-fps 30 --resolution 1920x1080 res://scenes/showcase.tscn -- --mode=ember --once
##   (--mode = ember | frost | map,  --bg = studio | arena,  --once = จบเองเมื่อหมุนครบ 1 รอบ)

const GameState := preload("res://scripts/game_state.gd")
const FighterRig := preload("res://scripts/fighter_rig.gd")
const HandFire := preload("res://scripts/hand_fire.gd")
const MAP_SCENE := preload("res://lite/map/skyborne_ruins.tscn")
const SKY_SHADER := preload("res://vfx/sky_clouds.gdshader")
const FONT_TITLE := preload("res://fonts/BarlowCondensed-BoldItalic.woff2")
const FONT_BODY := preload("res://fonts/MPLUSRounded1c-Medium.woff2")

const ANIM_LEN := {"Punch1": 0.26, "Punch2": 0.26, "Punch3": 0.47, "JumpKick": 0.45, "Land": 0.18,
	"Hit": 0.35, "HitHeavy": 0.6, "JumpPrep": 0.08, "BlockHit": 0.25, "DashF": 0.3, "DashB": 0.28}

@export var turn_time := 12.0          ## วินาทีต่อการหมุนตัวละคร 1 รอบ
@export var map_orbit_time := 24.0     ## วินาทีต่อการบินกล้องรอบแมพ 1 รอบ
@export var map_orbit_radius := 15.0
@export var map_orbit_height := 6.5
@export var map_brightness := 0.476    ## ให้สีแมพเหมือนในฉากต่อสู้

var mode := "ember"                    # ember | frost | map
var bg := "studio"                     # studio | arena (พื้นหลังตอนโชว์ตัวละคร)
var once := false
var paused := false
var speed := 1.0
var angle := 0.0                       # องศาที่หมุนไปแล้ว (0-360)
var start_t := 0.0

var cam: Camera3D
var env_studio: Environment
var env_arena: Environment
var world_env: WorldEnvironment
var studio_root: Node3D
var arena_root: Node3D
var sun: DirectionalLight3D
var rim_light: OmniLight3D
var floor_glow: MeshInstance3D
var floor_mat: StandardMaterial3D
var turntable: Node3D                  # ตัวละครที่หมุนอยู่บนนี้
var models := {}                       # id -> Node3D (โมเดลสำหรับหมุน)
var duo := []                          # ตัวละครยืนกลางแมพ (โหมด map)
var floor_y := 0.0
var floor_found := false

var help: Label
var name_box: VBoxContainer
var name_lbl: Label
var title_lbl: Label
var show_name := false
var studio_bg: CanvasLayer
const HOLD := 0.6                      ## ค้างหน้าตรงก่อนเริ่มหมุน (วินาที)
var hold_t := 0.0


func _ready() -> void:
	GameState.setup_fonts()
	_parse_args()
	_build_envs()
	_build_studio()
	_build_arena()
	turntable = Node3D.new()
	add_child(turntable)
	for id in ["emberclaw", "frostfang"]:
		models[id] = _make_fighter(id, turntable)
	_build_duo()
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	_build_ui()
	_apply_mode()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.get_slice("=", 1)
		elif a.begins_with("--bg="):
			bg = a.get_slice("=", 1)
		elif a == "--once":
			once = true
	if not mode in ["ember", "frost", "map"]:
		mode = "ember"


# ================= ฉาก =================

func _build_envs() -> void:
	env_studio = Environment.new()
	env_studio.background_mode = Environment.BG_CANVAS        # ใช้พื้นหลังไล่สีจาก CanvasLayer -1 (สีเดียวกับสไลด์)
	env_studio.background_canvas_max_layer = -1
	env_studio.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_studio.ambient_light_color = Color(0.55, 0.62, 0.72)
	env_studio.ambient_light_energy = 0.65
	env_studio.tonemap_mode = Environment.TONE_MAPPER_AGX
	env_studio.glow_enabled = true
	env_studio.glow_intensity = 0.35
	env_studio.glow_bloom = 0.05

	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var p := {
		"zenith_color": Color(0.16, 0.34, 0.66), "horizon_color": Color(0.74, 0.72, 0.66),
		"sun_glow_color": Color(1, 0.72, 0.42), "horizon_softness": 0.35, "sun_size": 0.9994,
		"sun_glow": 6.0, "exposure": 1.0, "cloud_color": Color(1, 0.98, 0.95),
		"cloud_shadow_color": Color(0.42, 0.46, 0.56), "cloud_coverage": 0.48, "cloud_softness": 0.18,
		"cloud_scale": 0.9, "cloud_speed": 0.012, "wind_dir": Vector2(1, 0.35), "cloud_sea": true,
		"sea_coverage": 0.55, "sea_scale": 0.6, "sea_depth_color": Color(0.26, 0.32, 0.46),
	}
	for k in p:
		sky_mat.set_shader_parameter(k, p[k])
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env_arena = Environment.new()
	env_arena.background_mode = Environment.BG_SKY
	env_arena.sky = sky
	env_arena.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_arena.ambient_light_color = Color(0.6, 0.6, 0.64)
	env_arena.ambient_light_sky_contribution = 0.55
	env_arena.ambient_light_energy = 0.7
	env_arena.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env_arena.tonemap_mode = Environment.TONE_MAPPER_AGX
	env_arena.tonemap_exposure = 1.1
	env_arena.glow_enabled = true
	env_arena.glow_intensity = 0.4
	env_arena.glow_bloom = 0.05
	env_arena.fog_enabled = true
	env_arena.fog_light_color = Color(0.74, 0.72, 0.68)
	env_arena.fog_light_energy = 0.8
	env_arena.fog_sun_scatter = 0.25
	env_arena.fog_density = 0.004
	env_arena.fog_aerial_perspective = 0.4
	env_arena.fog_sky_affect = 0.15
	env_arena.adjustment_enabled = true
	env_arena.adjustment_contrast = 1.08
	env_arena.adjustment_saturation = 1.05

	world_env = WorldEnvironment.new()
	add_child(world_env)


func _build_studio() -> void:
	studio_root = Node3D.new()
	add_child(studio_root)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-24, 28, 0)
	key.light_color = Color(1.0, 0.95, 0.88)
	key.light_energy = 1.35
	studio_root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-8, -45, 0)
	fill.light_color = Color(0.6, 0.75, 0.95)
	fill.light_energy = 0.45
	studio_root.add_child(fill)
	rim_light = OmniLight3D.new()                      # แสงขอบด้านหลัง (สีตามธาตุ)
	rim_light.position = Vector3(0.2, 2.2, -1.4)
	rim_light.omni_range = 4.5
	rim_light.light_energy = 2.2
	studio_root.add_child(rim_light)

	# วงแสงบนพื้นใต้ตัวละคร
	floor_glow = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3.4, 3.4)
	floor_mat = StandardMaterial3D.new()
	floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	floor_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	floor_mat.albedo_texture = gt
	pm.material = floor_mat
	floor_glow.mesh = pm
	floor_glow.position = Vector3(0, 0.01, 0)
	studio_root.add_child(floor_glow)


func _build_arena() -> void:
	arena_root = Node3D.new()
	add_child(arena_root)
	sun = DirectionalLight3D.new()
	sun.transform = Transform3D(Basis(Vector3(-0.8192, 0, -0.5736), Vector3(-0.3039, 0.848, 0.4341),
		Vector3(0.4864, 0.5299, -0.6947)), Vector3(0, 30, 0))
	sun.light_color = Color(1, 0.86, 0.68)
	sun.light_energy = 1.7
	sun.light_angular_distance = 1.0
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 60.0
	arena_root.add_child(sun)
	var map := MAP_SCENE.instantiate() as Node3D
	map.transform = Transform3D(Basis().scaled(Vector3(30, 30, 30)), Vector3(0, -3.95, 0))
	arena_root.add_child(map)
	# ปรับวัสดุแมพให้เหมือนในฉากต่อสู้ + ทำ collision ไว้หาความสูงพื้น
	for mi in map.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not map.has_node("Collision"):
			m.create_trimesh_collision()
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i)
			if mat is BaseMaterial3D:
				var dark := mat.duplicate() as BaseMaterial3D
				dark.albedo_color = Color(map_brightness, map_brightness, map_brightness)
				dark.metallic = 0.0
				dark.metallic_specular = 0.25
				dark.roughness_texture = null
				dark.roughness = 1.0
				dark.normal_scale = 0.6
				m.set_surface_override_material(i, dark)


## โมเดลตัวละครพร้อมท่ายืนตั้งการ์ด + ไฟที่มือ
func _make_fighter(id: String, parent: Node3D) -> Node3D:
	var d: Dictionary = GameState.data(id)
	var m := (load(d["walk_glb"]) as PackedScene).instantiate() as Node3D
	parent.add_child(m)
	var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var rig = FighterRig.new()
	if ap and rig.setup(m, ap):
		rig.build_all(ANIM_LEN)
		ap.play("FightIdle")
		if rig._skel:
			for side in [1, -1]:
				_attach_fire(rig, side, d)
	return m


func _attach_fire(rig, side: int, d: Dictionary) -> void:
	var skel: Skeleton3D = rig._skel
	var att := BoneAttachment3D.new()
	att.bone_name = skel.get_bone_name(rig._b(side, "Hand"))
	skel.add_child(att)
	var fx := HandFire.new()
	fx.size = 1.4
	var fc: Array = d["fire"]
	fx.flipbook = load(d["flipbook"])
	fx.color_core = fc[0]
	fx.color_mid = fc[1]
	fx.color_tail = fc[2]
	fx.color_ember = fc[3]
	fx.color_light = fc[4]
	fx.position = Vector3(0, 0.12, 0)
	att.add_child(fx)


## ตัวละครสองตัวยืนเผชิญหน้ากันกลางลานวิหาร (โหมดแมพ)
func _build_duo() -> void:
	var holder := Node3D.new()
	arena_root.add_child(holder)
	var a := _make_fighter("emberclaw", holder)
	var b := _make_fighter("frostfang", holder)
	a.position = Vector3(-1.3, 0, 0)
	a.rotation.y = PI / 2.0
	b.position = Vector3(1.3, 0, 0)
	b.rotation.y = -PI / 2.0
	duo = [holder, a, b]


## หาความสูงพื้นลานตรงกลาง (ยิง ray ลงจากด้านบน) ให้ตัวละครยืนบนพื้นพอดี
func _find_floor() -> void:
	var q := PhysicsRayQueryParameters3D.create(Vector3(0, 20, 0), Vector3(0, -20, 0))
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		floor_y = hit.position.y
	duo[0].position.y = floor_y
	if bg == "arena":
		turntable.position.y = floor_y


# ================= UI =================

func _build_ui() -> void:
	# พื้นหลังสตูดิโอ: ไล่สีจากกลางจอ (สว่างนิด) ออกไปขอบ (สีพื้นสไลด์ #0E131C)
	studio_bg = CanvasLayer.new()
	studio_bg.layer = -1
	add_child(studio_bg)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color("222c3c"), Color("0e131c")])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.55)
	gt.fill_to = Vector2(1.05, 0.55)
	gt.width = 512
	gt.height = 512
	var tr := TextureRect.new()
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	studio_bg.add_child(tr)

	var layer := CanvasLayer.new()
	add_child(layer)
	help = Label.new()
	help.text = "1 Emberclaw   2 Frostfang   3 แมพ   ·   B พื้นหลัง   C ตัวละครในแมพ   N ชื่อ   ·   Space หยุด   R เริ่มใหม่   ซ้าย/ขวา ความเร็ว   ·   H ซ่อนข้อความนี้"
	help.add_theme_font_override("font", FONT_BODY)
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	help.add_theme_constant_override("outline_size", 6)
	help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	help.position.y -= 40
	help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(help)
	if once:
		help.visible = false          # อัดด้วย Movie Maker = ภาพสะอาด
	else:
		var tw := create_tween()
		tw.tween_interval(5.0)
		tw.tween_property(help, "modulate:a", 0.0, 1.0)

	name_box = VBoxContainer.new()
	name_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	name_box.position = Vector2(70, -190)
	name_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(name_box)
	name_lbl = Label.new()
	var fv := FontVariation.new()
	fv.base_font = FONT_TITLE
	fv.variation_embolden = 0.4
	name_lbl.add_theme_font_override("font", fv)
	name_lbl.add_theme_font_size_override("font_size", 96)
	name_box.add_child(name_lbl)
	title_lbl = Label.new()
	title_lbl.add_theme_font_override("font", FONT_BODY)
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.94))
	name_box.add_child(title_lbl)
	name_box.visible = false


# ================= โหมด =================

func _char_id() -> String:
	return "emberclaw" if mode == "ember" else "frostfang"


func _apply_mode() -> void:
	angle = 0.0
	start_t = 0.0
	var is_map := mode == "map"
	var in_arena := is_map or bg == "arena"
	world_env.environment = env_arena if in_arena else env_studio
	arena_root.visible = in_arena
	studio_root.visible = not in_arena
	turntable.visible = not is_map
	if studio_bg:
		studio_bg.visible = not in_arena
	hold_t = 0.0
	get_tree().create_timer(0.25).timeout.connect(_restart_fx)
	duo[0].visible = is_map and (duo[0].get_meta("show", true))
	if not is_map:
		var id := _char_id()
		for k in models:
			models[k].visible = k == id
		var d: Dictionary = GameState.data(id)
		rim_light.light_color = d["color"]
		floor_mat.albedo_color = d["color"]
		turntable.position = Vector3(0, floor_y if in_arena else 0.0, 0)
		turntable.rotation.y = 0.0
		cam.fov = 32.0 if not in_arena else 34.0
		cam.global_transform = Transform3D(Basis(), Vector3(0, turntable.position.y + 1.12, 4.6)) \
			.looking_at(Vector3(0, turntable.position.y + 0.9, 0), Vector3.UP)
		name_lbl.text = d["name"]
		name_lbl.add_theme_color_override("font_color", d["color"])
		title_lbl.text = d["title"]
	name_box.visible = show_name and not is_map
	_update_map_cam(0.0)


func _update_map_cam(t: float) -> void:
	if mode != "map":
		return
	var a := TAU * t / map_orbit_time
	var r := map_orbit_radius + sin(a * 2.0) * 1.5
	var h := map_orbit_height + sin(a * 3.0) * 0.8
	cam.fov = 55.0
	var pos := Vector3(sin(a) * r, floor_y + h, cos(a) * r)
	cam.global_transform = Transform3D(Basis(), pos).looking_at(Vector3(0, floor_y + 1.2, 0), Vector3.UP)


func _physics_process(_d: float) -> void:
	if not floor_found and Engine.get_physics_frames() >= 3:
		floor_found = true
		_find_floor()
		_apply_mode()


func _process(delta: float) -> void:
	if paused:
		return
	var dt := delta * speed
	if mode == "map":
		start_t += dt
		_update_map_cam(start_t)
		if once and start_t >= map_orbit_time:
			get_tree().quit()
	else:
		if hold_t < HOLD:
			hold_t += delta
			return
		angle += 360.0 * dt / turn_time
		turntable.rotation.y = deg_to_rad(angle)
		if once and angle >= 360.0:
			get_tree().quit()


## ล้างอนุภาคไฟที่ค้างจากตอนโมเดลยังเป็นท่า T (เฟรมแรกๆ)
func _restart_fx() -> void:
	for n in find_children("*", "CPUParticles3D", true, false):
		(n as CPUParticles3D).restart()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1:
			mode = "ember"
			_apply_mode()
		KEY_2:
			mode = "frost"
			_apply_mode()
		KEY_3:
			mode = "map"
			_apply_mode()
		KEY_B:
			bg = "arena" if bg == "studio" else "studio"
			_apply_mode()
		KEY_C:
			duo[0].set_meta("show", not duo[0].get_meta("show", true))
			_apply_mode()
		KEY_N:
			show_name = not show_name
			name_box.visible = show_name and mode != "map"
		KEY_SPACE:
			paused = not paused
		KEY_R:
			_apply_mode()
		KEY_LEFT:
			speed = maxf(0.25, speed - 0.25)
		KEY_RIGHT:
			speed = minf(3.0, speed + 0.25)
		KEY_H:
			help.visible = not help.visible
			help.modulate.a = 1.0
		KEY_ESCAPE:
			get_tree().quit()
