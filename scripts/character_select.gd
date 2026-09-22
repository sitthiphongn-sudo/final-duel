extends Node3D
## ฉากเลือกตัวละคร (สไตล์ Jump Force): โมเดล 3D ตรงกลาง, แผงสถานะขวา, ช่องทีมซ้าย (1 ช่อง = 1v1),
## แถบรูปตัวละครด้านล่าง (+ช่องสุ่ม), ปุ่ม EXIT กลับเมนู
## ควบคุม: เมาส์ชี้/คลิก หรือ ←/→ (A/D) เลือก | Enter/Space หรือคลิกซ้ำ = ยืนยัน | Esc = ออก | ลากเมาส์บนตัวละคร = หมุนดู

const GameState := preload("res://scripts/game_state.gd")
const FighterRig := preload("res://scripts/fighter_rig.gd")
const HandFire := preload("res://scripts/hand_fire.gd")
const FONT_FILE := preload("res://fonts/MPLUSRounded1c-Medium.woff2")
const RANDOM_CARD := preload("res://ui/card_random.png")
const BG_SHADER := preload("res://vfx/select_bg.gdshader")
const SFX_MOVE := preload("res://sounds/whoosh_light.wav")
const SFX_CONFIRM := preload("res://sounds/ult_boom.wav")
const SFX_BACK := preload("res://sounds/block.wav")

@export_file("*.tscn") var battle_scene := "res://scenes/vs_loading.tscn"   ## หน้า VS (โหลดแมพ) แล้วค่อยเข้าเกม
@export_file("*.tscn") var menu_scene := "res://scenes/menu.tscn"   ## ยังไม่ได้สร้าง -> กด EXIT จะแจ้งเตือนแทน
@export var music: AudioStream = preload("res://s_b.wav")
@export_range(0.0, 1.0) var music_volume := 0.55

const ANIM_LEN := {"Punch1": 0.26, "Punch2": 0.26, "Punch3": 0.47, "JumpKick": 0.45, "Land": 0.18,
	"Hit": 0.35, "HitHeavy": 0.6, "JumpPrep": 0.08, "BlockHit": 0.25, "DashF": 0.3, "DashB": 0.28}

# ---- สี UI (โทนฟ้าอมเขียวแบบภาพอ้างอิง) ----
const C_PANEL := Color(0.03, 0.12, 0.16, 0.78)
const C_PANEL_HEAD := Color(0.09, 0.27, 0.32, 0.85)
const C_LINE := Color(0.45, 0.8, 0.85, 0.28)
const C_TEXT := Color(0.9, 0.97, 1.0)
const C_TEXT_DIM := Color(0.62, 0.8, 0.84)
const C_CYAN := Color(0.35, 0.95, 1.0)
const C_GOLD := Color(1.0, 0.84, 0.25)

var ids: Array = []                 # ลำดับการ์ดด้านล่าง (ตัวละคร + "random")
var cursor := 0
var locked := false
var font_reg: Font
var font_bold: Font

var cam: Camera3D
var stage: Node3D
var models := {}                    # id -> {node, anim, fire_l, fire_r}
var shown_id := ""
var drag_yaw := 0.0
var dragging := false
var t := 0.0
var floor_glow: MeshInstance3D
var rim_light: OmniLight3D

var ui: Control
var bg_mat: ShaderMaterial
var cards: Array = []
var stats_box: VBoxContainer
var name_label: Label
var title_label: Label
var element_label: Label
var diamond
var vs_label: Label
var toast: Label
var fade: ColorRect
var bgm: AudioStreamPlayer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.init_settings()
	Engine.time_scale = 1.0
	ids = GameState.ORDER.duplicate()
	ids.append("random")
	cursor = maxi(0, ids.find(GameState.p1))
	_build_fonts()
	_build_world()
	_build_ui()
	for id in GameState.ORDER:
		_build_model(id)
	_show_character(true)
	if music:
		bgm = AudioStreamPlayer.new()
		bgm.bus = "Music"
		bgm.stream = music
		bgm.volume_db = linear_to_db(music_volume)
		add_child(bgm)
		bgm.finished.connect(bgm.play)
		bgm.play()


# ================= ฟอนต์ =================

func _build_fonts() -> void:
	font_reg = FONT_FILE
	var fv := FontVariation.new()
	fv.base_font = FONT_FILE
	fv.variation_embolden = 0.9              # ทำตัวหนาจากฟอนต์เดียว
	font_bold = fv


# ================= โลก 3D =================

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS     # ใช้พื้นหลังจาก CanvasLayer -1 (shader)
	env.background_canvas_max_layer = -1
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.72, 0.78)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-24, 28, 0)
	key.light_color = Color(1.0, 0.95, 0.88)
	key.light_energy = 1.35
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-8, -45, 0)
	fill.light_color = Color(0.55, 0.85, 0.95)
	fill.light_energy = 0.45
	add_child(fill)
	rim_light = OmniLight3D.new()                     # แสงขอบด้านหลัง (สีตามธาตุ)
	rim_light.position = Vector3(0.2, 2.2, -1.4)
	rim_light.omni_range = 4.5
	rim_light.light_energy = 2.2
	add_child(rim_light)
	var rim2 := OmniLight3D.new()
	rim2.position = Vector3(-1.3, 1.5, -1.0)
	rim2.light_color = Color(0.4, 0.95, 1.0)
	rim2.omni_range = 4.0
	rim2.light_energy = 1.4
	add_child(rim2)

	# แสงบนพื้นใต้ตัวละคร
	floor_glow = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3.4, 3.4)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	fm.albedo_texture = gt
	fm.albedo_color = Color(0.4, 0.9, 1.0)
	pm.material = fm
	floor_glow.mesh = pm
	floor_glow.position = Vector3(0, 0.01, 0)
	add_child(floor_glow)

	stage = Node3D.new()
	add_child(stage)

	cam = Camera3D.new()
	cam.fov = 32.0
	add_child(cam)
	cam.global_transform = Transform3D(Basis(), Vector3(0.0, 1.22, 4.7)).looking_at(Vector3(0.0, 1.02, 0.0), Vector3.UP)
	cam.current = true

	# พื้นหลัง shader
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_mat = ShaderMaterial.new()
	bg_mat.shader = BG_SHADER
	bg.material = bg_mat
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(bg)


## สร้างโมเดลตัวละครไว้ล่วงหน้า (ท่า idle ตั้งการ์ด + ไฟที่มือ) แล้วซ่อนไว้
func _build_model(id: String) -> void:
	var d: Dictionary = GameState.data(id)
	var ps := load(d["walk_glb"]) as PackedScene
	if ps == null:
		return
	var m := ps.instantiate() as Node3D
	stage.add_child(m)
	m.visible = false
	var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var rig = FighterRig.new()
	var entry := {"node": m, "anim": ap, "rig": rig, "fire_l": null, "fire_r": null}
	if ap and rig.setup(m, ap):
		rig.build_all(ANIM_LEN)
		ap.play("FightIdle")
		if rig._skel:
			entry["fire_l"] = _attach_fire(rig, 1, d)
			entry["fire_r"] = _attach_fire(rig, -1, d)
	models[id] = entry


func _attach_fire(rig, side: int, d: Dictionary) -> Node3D:
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
	return fx


# ================= UI =================

func _style(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


func _label(txt: String, size: int, col := C_TEXT, bold := false, outline := 0) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", font_bold if bold else font_reg)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0, 0.05, 0.08, 0.9))
		l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(ui)
	ui.gui_input.connect(_on_ui_input)

	_build_exit()
	_build_team()
	_build_name()
	_build_stats()
	_build_strip()

	toast = _label("", 15, C_TEXT, true, 6)
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.position = Vector2(-300, 70)
	toast.size = Vector2(600, 30)
	toast.modulate.a = 0.0
	ui.add_child(toast)

	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 0.5)


## ปุ่ม EXIT มุมซ้ายบน (กลับหน้าเมนู)
func _build_exit() -> void:
	var b := Button.new()
	b.text = "◀  EXIT"
	b.position = Vector2(20, 16)
	b.custom_minimum_size = Vector2(118, 32)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", Color(0.05, 0.12, 0.15))
	b.add_theme_stylebox_override("normal", _style(C_PANEL, C_LINE, 1, 2))
	b.add_theme_stylebox_override("hover", _style(C_CYAN, C_CYAN, 1, 2))
	b.add_theme_stylebox_override("pressed", _style(C_CYAN.darkened(0.2), C_CYAN, 1, 2))
	b.pressed.connect(_exit)
	ui.add_child(b)
	var hint := _label("Esc", 11, C_TEXT_DIM)
	hint.position = Vector2(146, 24)
	ui.add_child(hint)


## ช่องทีมซ้ายบน: หัวข้อ Team + ช่องเพชร 1 ช่อง (เกม 1v1)
func _build_team() -> void:
	var head := Panel.new()
	head.position = Vector2(20, 70)
	head.size = Vector2(250, 30)
	head.add_theme_stylebox_override("panel", _style(C_PANEL, C_LINE, 1))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(head)
	var ht := _label("Team", 16, C_TEXT)
	ht.set_anchors_preset(Control.PRESET_FULL_RECT)
	ht.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ht.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(ht)

	diamond = DiamondSlot.new()
	diamond.position = Vector2(20 + 125 - 42, 112)
	diamond.size = Vector2(84, 84)
	ui.add_child(diamond)
	var p1 := _label("P1", 17, C_TEXT, true, 4)
	p1.position = Vector2(20 + 125 - 40, 198)
	p1.size = Vector2(80, 24)
	p1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(p1)
	vs_label = _label("", 12, C_TEXT_DIM)
	vs_label.position = Vector2(20, 226)
	vs_label.size = Vector2(250, 20)
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(vs_label)


## ชื่อตัวละครตัวใหญ่ด้านซ้าย
func _build_name() -> void:
	name_label = _label("", 40, C_TEXT, true, 8)
	name_label.position = Vector2(26, 290)
	ui.add_child(name_label)
	title_label = _label("", 15, C_TEXT_DIM, false, 4)
	title_label.position = Vector2(30, 342)
	ui.add_child(title_label)
	element_label = _label("", 13, C_TEXT, true, 4)
	element_label.position = Vector2(30, 366)
	ui.add_child(element_label)


## แผงสถานะด้านขวา (Health / ATK / Abilities / Resistances / Elemental)
func _build_stats() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(C_PANEL, C_LINE, 1))
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-318, 8)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(panel)
	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 0)
	panel.add_child(stats_box)


func _row(h := 22.0, head := false) -> PanelContainer:
	var r := PanelContainer.new()
	var sb := _style(C_PANEL_HEAD if head else Color(0, 0, 0, 0))
	sb.border_color = C_LINE
	sb.border_width_bottom = 1
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	r.add_theme_stylebox_override("panel", sb)
	r.custom_minimum_size = Vector2(0, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_box.add_child(r)
	return r


## ปุ่มกด (วงกลม/สี่เหลี่ยมมนมีตัวอักษร) เหมือนไอคอนปุ่มจอยในภาพอ้างอิง
func _key_badge(txt: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _style(Color(0.85, 0.95, 1.0, 0.92), Color(1, 1, 1, 0.6), 1, 9)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(18, 16)
	var l := _label(txt, 10, Color(0.05, 0.15, 0.2), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func _icon_value(icon: String, value: int) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(16, 16)
	var p := "res://ui/icons/%s.png" % icon
	if ResourceLoader.exists(p):
		tr.texture = load(p)
	hb.add_child(tr)
	var col := C_TEXT
	if value < 0:
		col = C_TEXT_DIM
	elif value > 100:
		col = Color(1.0, 0.6, 0.55)          # แพ้ทาง (โดนแรงกว่าปกติ)
	elif value < 100:
		col = Color(0.6, 1.0, 0.7)           # ต้านทาน
	var l := _label("?" if value < 0 else str(value), 13, col)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(l)
	return hb


func _fill_stats(d: Dictionary, masked := false) -> void:
	for c in stats_box.get_children():
		c.queue_free()
	# Health | ATK
	var r := _row(26)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	r.add_child(hb)
	for pair in [["Health", "????" if masked else str(d["hp"])], ["ATK", "??" if masked else str(d["atk"])]]:
		var a := _label(pair[0], 13, C_TEXT_DIM)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(a)
		var b := _label(pair[1], 14, C_TEXT, true)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.custom_minimum_size = Vector2(52, 0)
		hb.add_child(b)
		if pair[0] == "Health":
			var sep := VSeparator.new()
			hb.add_child(sep)
	# Abilities
	var h := _row(20, true)
	h.add_child(_label("Abilities", 12, C_TEXT))
	for ab in d["abilities"]:
		var kr := _row(22)
		var kb := HBoxContainer.new()
		kb.add_theme_constant_override("separation", 4)
		kb.alignment = BoxContainer.ALIGNMENT_BEGIN
		kr.add_child(kb)
		var badge := _key_badge(ab[0])
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		kb.add_child(badge)
		if ab[1] != "":
			kb.add_child(_label(ab[1], 12, C_TEXT_DIM))
		var nr := _row(22)
		nr.add_child(_label("? ? ?" if masked else ab[2], 13, C_TEXT))
	# Physical Resistances
	h = _row(20, true)
	h.add_child(_label("Physical Resistances", 12, C_TEXT))
	var pr := _row(24)
	var phb := HBoxContainer.new()
	phb.add_theme_constant_override("separation", 14)
	pr.add_child(phb)
	for i in 3:
		phb.add_child(_icon_value(GameState.PHYSICAL_ICONS[i], -1 if masked else d["physical"][i]))
	# Elemental Types
	h = _row(20, true)
	h.add_child(_label("Elemental Types", 12, C_TEXT))
	for rr in 2:
		var er := _row(24)
		var ehb := HBoxContainer.new()
		ehb.add_theme_constant_override("separation", 14)
		er.add_child(ehb)
		for i in 3:
			var k := rr * 3 + i
			ehb.add_child(_icon_value(GameState.ELEMENT_ICONS[k], -1 if masked else d["elemental"][k]))


## แถบการ์ดตัวละครด้านล่าง
func _build_strip() -> void:
	var band := ColorRect.new()
	band.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	band.offset_top = -124
	band.color = Color(0.01, 0.05, 0.07, 0.55)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(band)
	var line := ColorRect.new()
	line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -125
	line.offset_bottom = -124
	line.color = C_LINE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(line)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_bottom = -12
	row.offset_top = -12 - 104
	ui.add_child(row)
	for i in ids.size():
		var id: String = ids[i]
		var c := CharCard.new()
		c.custom_minimum_size = Vector2(88, 104)
		if id == "random":
			c.tex = RANDOM_CARD
			c.accent = C_CYAN
		else:
			var d: Dictionary = GameState.data(id)
			c.tex = load(d["card"]) if ResourceLoader.exists(d["card"]) else load(d["portrait"])
			c.accent = d["color"]
		c.index = i
		c.hovered_card.connect(_on_card_hover)
		c.clicked_card.connect(_on_card_click)
		row.add_child(c)
		cards.append(c)

	var hint := _label("←/→  เลือก      Enter  ยืนยัน      Esc  ออก", 12, C_TEXT_DIM)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position = Vector2(-330, -30)
	hint.size = Vector2(310, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui.add_child(hint)


# ================= การเลือก =================

func _current_id() -> String:
	var id: String = ids[cursor]
	return shown_id if id == "random" else id


func _move(to: int) -> void:
	if locked:
		return
	to = posmod(to, ids.size())
	if to == cursor:
		return
	cursor = to
	_sfx(SFX_MOVE, -8.0, 1.5)
	_show_character(false)


func _show_character(instant: bool) -> void:
	var id: String = ids[cursor]
	var real := id
	if id == "random":
		real = shown_id if shown_id != "" else GameState.ORDER[0]
	for i in cards.size():
		cards[i].selected = i == cursor
		cards[i].queue_redraw()
	var d: Dictionary = GameState.data(real)
	if id == "random":
		name_label.text = "RANDOM"
		title_label.text = "สุ่มตัวละคร"
		element_label.text = "?"
		element_label.add_theme_color_override("font_color", C_CYAN)
	else:
		name_label.text = d["name"]
		title_label.text = d["title"]
		element_label.text = "◆ " + ("FIRE" if d["element"] == "fire" else "ICE")
		element_label.add_theme_color_override("font_color", d["color"])
	_fill_stats(d, id == "random")
	diamond.tex = null if id == "random" else load(d["portrait"])
	diamond.queue_redraw()
	vs_label.text = "VS  %s  (CPU)" % GameState.data(GameState.pick_opponent(real))["name"] if id != "random" else "VS  ???  (CPU)"
	rim_light.light_color = d["color"]
	(floor_glow.mesh.material as StandardMaterial3D).albedo_color = d["color"].lerp(Color(0.4, 0.9, 1.0), 0.5)
	bg_mat.set_shader_parameter("accent", d["color"])
	if real != shown_id:
		_swap_model(real, instant)
	if id == "random" and models.has(real):
		models[real]["node"].visible = true


func _swap_model(id: String, instant: bool) -> void:
	for k in models:
		models[k]["node"].visible = false
	shown_id = id
	if not models.has(id):
		return
	var m: Node3D = models[id]["node"]
	m.visible = true
	drag_yaw = 0.0
	if not instant:
		# เข้าฉากแบบสไลด์ + เด้ง + วงแสงที่พื้น
		m.position = Vector3(0.35, 0, 0)
		m.scale = Vector3.ONE * 0.94
		var tw := create_tween().set_parallel(true)
		tw.tween_property(m, "position", Vector3.ZERO, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(m, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for f in ["fire_l", "fire_r"]:
			if models[id][f]:
				models[id][f].boost(2.0)


func _confirm() -> void:
	if locked:
		return
	locked = true
	var id: String = ids[cursor]
	if id == "random":
		id = GameState.ORDER.pick_random()
		_swap_model(id, false)
		for i in cards.size():
			cards[i].selected = i == ids.find(id)
			cards[i].queue_redraw()
	GameState.p1 = id
	GameState.p2 = GameState.pick_opponent(id)
	var d: Dictionary = GameState.data(id)
	diamond.tex = load(d["portrait"])
	diamond.locked = true
	diamond.queue_redraw()
	name_label.text = d["name"]
	vs_label.text = "VS  %s  (CPU)" % GameState.data(GameState.p2)["name"]
	_sfx(SFX_CONFIRM, -4.0, 1.1)
	# ท่าโพสยืนยัน: เสยหมัด + ไฟลุก + จอวาบ
	var e: Dictionary = models[id]
	if e["anim"] and e["anim"].has_animation("Punch3"):
		e["anim"].play("Punch3", 0.05)
		e["anim"].queue("FightIdle")
	for f in ["fire_l", "fire_r"]:
		if e[f]:
			e[f].boost(1.5)
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(d["color"].r, d["color"].g, d["color"].b, 0.45)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.4)
	tw.tween_callback(flash.queue_free)
	var tc := create_tween()
	tc.tween_property(cam, "fov", 27.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tc.tween_interval(0.3)
	tc.tween_property(fade, "color:a", 1.0, 0.45)
	if bgm:
		tc.parallel().tween_property(bgm, "volume_db", -40.0, 0.45)
	tc.tween_callback(func(): get_tree().change_scene_to_file(battle_scene))


func _exit() -> void:
	if locked:
		return
	_sfx(SFX_BACK, -6.0, 1.2)
	if menu_scene != "" and ResourceLoader.exists(menu_scene):
		locked = true
		var tw := create_tween()
		tw.tween_property(fade, "color:a", 1.0, 0.35)
		tw.tween_callback(func(): get_tree().change_scene_to_file(menu_scene))
	else:
		_toast("Menu not created yet  (%s)" % menu_scene)


func _toast(msg: String) -> void:
	toast.text = msg
	var tw := create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.6)
	tw.tween_property(toast, "modulate:a", 0.0, 0.4)


func _on_card_hover(i: int) -> void:
	_move(i)


func _on_card_click(i: int) -> void:
	if i == cursor:
		_confirm()
	else:
		_move(i)


# ================= อินพุต =================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_move(cursor - 1)
			KEY_RIGHT, KEY_D:
				_move(cursor + 1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_confirm()
			KEY_ESCAPE:
				_exit()


## ลากเมาส์บนพื้นที่ว่าง = หมุนดูตัวละคร
func _on_ui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		drag_yaw += event.relative.x * 0.01


func _process(delta: float) -> void:
	t += delta
	if shown_id != "" and models.has(shown_id):
		var m: Node3D = models[shown_id]["node"]
		if not dragging:
			drag_yaw = lerpf(drag_yaw, 0.0, clampf(delta * 1.5, 0.0, 1.0))
		m.rotation.y = 0.22 + sin(t * 0.45) * 0.1 + drag_yaw
	if bg_mat:
		bg_mat.set_shader_parameter("time_s", t)


func _sfx(stream: AudioStream, vol := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = stream
	p.volume_db = vol
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# ================= คอนโทรลวาดเอง =================

## ช่องทีมรูปเพชร: ขอบฟ้าเรืองแสง, ใส่รูปตัวละครเมื่อยืนยันแล้ว
class DiamondSlot extends Control:
	var tex: Texture2D
	var locked := false
	var t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.46
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		draw_colored_polygon(pts, Color(0.04, 0.18, 0.22, 0.85))
		if tex:
			var ri := r * 0.86
			var inner := PackedVector2Array([c + Vector2(0, -ri), c + Vector2(ri, 0), c + Vector2(0, ri), c + Vector2(-ri, 0)])
			# UV: ครอบรูปให้เต็มเพชร (ครอปส่วนหัว)
			var uvs := PackedVector2Array([Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 1.0), Vector2(0.0, 0.5)])
			draw_polygon(inner, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), uvs, tex)
		var pulse := 0.65 + 0.35 * sin(t * 3.0)
		var col := Color(1.0, 0.84, 0.25) if locked else Color(0.35, 0.95, 1.0)
		var loop := PackedVector2Array(pts)
		loop.append(pts[0])
		for i in 3:                                   # เรืองแสงหลายชั้น
			draw_polyline(loop, Color(col.r, col.g, col.b, 0.12 * pulse), 10.0 - i * 3.0, true)
		draw_polyline(loop, Color(col.r, col.g, col.b, 0.95), 3.0, true)


## การ์ดตัวละครแถบล่าง: ชี้ = เลือก, คลิกตัวที่เลือกอยู่ = ยืนยัน, ขอบทองตอนถูกเลือก
class CharCard extends Control:
	signal hovered_card(i: int)
	signal clicked_card(i: int)
	var tex: Texture2D
	var accent := Color.WHITE
	var index := 0
	var selected := false
	var _hover := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func():
			_hover = true
			hovered_card.emit(index)
			queue_redraw())
		mouse_exited.connect(func():
			_hover = false
			queue_redraw())

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked_card.emit(index)
			accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if selected:
			r = r.grow(3)
		# พื้นการ์ดไล่เฉด + แสงสีประจำตัวจากด้านล่าง
		draw_rect(r, Color(0.05, 0.16, 0.2, 0.95))
		var glow := Rect2(r.position + Vector2(0, r.size.y * 0.45), Vector2(r.size.x, r.size.y * 0.55))
		draw_rect(glow, Color(accent.r, accent.g, accent.b, 0.22 if selected else 0.1))
		if tex:
			# ครอปให้เต็มการ์ด (cover)
			var ts := tex.get_size()
			var s := maxf(r.size.x / ts.x, r.size.y / ts.y)
			var src_size := r.size / s
			var src := Rect2((ts - src_size) * Vector2(0.5, 0.25), src_size)
			draw_texture_rect_region(tex, r, src, Color(1, 1, 1, 1.0 if (selected or _hover) else 0.62))
		if selected:
			draw_rect(r, Color(1.0, 0.84, 0.25), false, 3.0)
			draw_rect(r.grow(2), Color(1.0, 0.84, 0.25, 0.3), false, 2.0)
		else:
			draw_rect(r, Color(0.45, 0.8, 0.85, 0.45 if _hover else 0.25), false, 1.0)
