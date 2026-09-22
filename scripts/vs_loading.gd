extends Control
## หน้า VS ระหว่างโหลดแมพ (สไตล์ Jump Force แบบ 1v1)
## - พื้นหลัง = ภาพแมพที่กำลังจะไปสู้ + ขอบมืด
## - แผงตัวละครเอียงแบบมีมิติ 2 แผง (ซ้าย = P1, ขวา = CPU) ขอบเรืองแสงฟ้า
## - ตัวอักษร VS ใหญ่เรืองแสงกระแทกลงตรงกลาง + แถบชื่อแมพด้านล่าง
## - ตัวเลขโหลด 1-100 มุมขวาล่าง ผูกกับการโหลดจริงทุกขั้น:
##     0-70  โหลดไฟล์ฉากแบบ background thread
##     70-90 สร้างฉากเกม + _ready (สร้างแอนิเมชัน/ชนแมพ) ใต้หน้า VS
##     90-100 เรนเดอร์ฉากเกมจริงอยู่ข้างหลังหน้า VS สักพัก (คอมไพล์ shader) ขณะเกมยังหยุดนิ่ง
##   ถึง 100 แล้วค่อยเปิดให้เกมเดิน + จางหน้า VS ออก -> ไม่มีจอเทาค้าง

const GameState := preload("res://scripts/game_state.gd")
const FONT_FILE := preload("res://fonts/MPLUSRounded1c-Medium.woff2")
const SFX_WHOOSH := preload("res://sounds/whoosh_heavy.wav")
const SFX_SLAM := preload("res://sounds/ult_boom.wav")

@export var min_time := 3.4          ## โชว์หน้านี้อย่างน้อยกี่วินาที (ถึงโหลดเสร็จก่อนก็รอให้ครบ)
@export var hold_at_100 := 0.35      ## ค้างที่ 100 ก่อนเข้าเกม
@export var warmup_frames := 30      ## เรนเดอร์ฉากเกมอยู่ข้างหลังกี่เฟรมก่อนเปิดให้เห็น

const BASE := Vector2(1152, 648)     # ออกแบบที่ความละเอียดนี้ แล้วย่อ/ขยายให้พอดีจอ

var stage: Control
var bg: TextureRect
var panels: Array = []
var vs_root: Control
var map_bar: Control
var count_label: Label
var pct_label: Label
var load_label: Label
var fade: ColorRect
var t := 0.0
var shown := 0.0
var loaded: PackedScene = null
var load_failed := false
var done := false
var ov: Control                       # ทุกอย่างของหน้า VS อยู่ในนี้ (CanvasLayer บนสุด ทับฉากเกมที่กำลังเตรียม)
var state := 0                        # 0 โหลดไฟล์, 1 รอตัวเลข, 2 สร้างฉาก, 3 ใส่ฉากเข้า tree, 4 วอร์มอัพ, 5 เสร็จ
var game: Node
var warm := 0
var target := 0.0
var font_bold: Font
var path: String


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.init_settings()
	path = GameState.BATTLE_SCENE
	var fv := FontVariation.new()
	fv.base_font = FONT_FILE
	fv.variation_embolden = 0.55
	font_bold = fv
	ResourceLoader.load_threaded_request(path)
	var top := CanvasLayer.new()
	top.layer = 100
	add_child(top)
	ov = Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(ov)
	_build()
	_intro()


# ---------------- สร้างหน้าจอ ----------------

func _build() -> void:
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(back)

	# พื้นหลังภาพแมพ (เต็มจอเสมอ)
	bg = TextureRect.new()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = load(GameState.MAP_BG)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.95, 0.98, 1.0)
	ov.add_child(bg)
	# ขอบจอมืด (radial gradient: กลางใส ขอบเข้ม)
	var vg := Gradient.new()
	vg.offsets = PackedFloat32Array([0.0, 0.5, 0.82, 1.0])
	vg.colors = PackedColorArray([Color(0.0, 0.03, 0.06, 0.08), Color(0.0, 0.03, 0.06, 0.14), Color(0.0, 0.03, 0.06, 0.6), Color(0.0, 0.02, 0.04, 0.92)])
	var vt := GradientTexture2D.new()
	vt.gradient = vg
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(1.08, 0.5)
	vt.width = 256
	vt.height = 256
	var vig := TextureRect.new()
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.texture = vt
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(vig)

	# เวทีขนาดคงที่ อยู่กลางจอ (ย่อ/ขยายตามความสูงจอ)
	stage = Control.new()
	stage.size = BASE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(stage)

	# ประกายแสงลอย
	var dust := CPUParticles2D.new()
	dust.amount = 40
	dust.lifetime = 5.0
	dust.preprocess = 5.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(560, 300)
	dust.position = BASE * 0.5
	dust.direction = Vector2(0, -1)
	dust.spread = 30.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 6.0
	dust.initial_velocity_max = 22.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.6
	var dg := Gradient.new()
	dg.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	dg.colors = PackedColorArray([Color(0.7, 0.95, 1, 0), Color(0.7, 0.95, 1, 0.9), Color(0.7, 0.95, 1, 0)])
	dust.color_ramp = dg
	stage.add_child(dust)

	# ---- แผงตัวละคร 2 แผง (มุมเอียงแบบภาพอ้างอิง: ขอบด้านในสูงกว่า) ----
	var d1: Dictionary = GameState.data(GameState.p1)
	var d2: Dictionary = GameState.data(GameState.p2)
	var left_pts := PackedVector2Array([Vector2(306, 74), Vector2(546, 38), Vector2(552, 576), Vector2(312, 540)])
	var right_pts := PackedVector2Array()
	for i in [1, 0, 3, 2]:                         # กระจกซ้าย-ขวา (เรียง TL, TR, BR, BL)
		right_pts.append(Vector2(BASE.x - left_pts[i].x, left_pts[i].y))
	for k in 2:
		var p := VsPanel.new()
		p.pts = left_pts if k == 0 else right_pts
		p.tex = load(d1["vs_l"] if k == 0 else d2["vs_r"])
		p.accent = (d1 if k == 0 else d2)["color"]
		p.size = BASE
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(p)
		panels.append(p)

	# ---- ตัวอักษร VS (ชั้นเรืองแสงหลายชั้น) ----
	vs_root = Control.new()
	vs_root.size = Vector2(420, 220)
	vs_root.position = Vector2(BASE.x * 0.5 - 210, 318)
	vs_root.pivot_offset = vs_root.size * 0.5
	vs_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(vs_root)
	for layer in [[34, Color(0.3, 0.8, 1.0, 0.16)], [18, Color(0.45, 0.88, 1.0, 0.35)], [7, Color(0.75, 0.96, 1.0, 0.9)], [0, Color.WHITE]]:
		var l := Label.new()
		l.text = "VS"
		l.add_theme_font_override("font", font_bold)
		l.add_theme_font_size_override("font_size", 190)
		l.add_theme_constant_override("outline_size", layer[0])
		if layer[0] > 0:
			l.add_theme_color_override("font_color", Color(0, 0, 0, 0))
			l.add_theme_color_override("font_outline_color", layer[1])
		else:
			l.add_theme_color_override("font_color", Color(0.93, 0.99, 1.0, 0.92))
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vs_root.add_child(l)

	# ---- แถบชื่อแมพ ----
	map_bar = MapBar.new()
	map_bar.text = GameState.MAP_NAME
	map_bar.font = FONT_FILE
	map_bar.position = Vector2(BASE.x * 0.5 - 150, 556)
	map_bar.size = Vector2(300, 28)
	map_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(map_bar)

	# ---- ตัวเลขโหลด 1-100 (มุมขวาล่าง ยึดขอบจอจริง) ----
	var box := Control.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.position = Vector2(-230, -78)
	box.size = Vector2(210, 64)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(box)
	load_label = _lbl("LOADING", 13, Color(0.75, 0.93, 1.0, 0.9), false)
	load_label.position = Vector2(0, 8)
	load_label.size = Vector2(118, 20)
	load_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(load_label)
	count_label = _lbl("1", 44, Color.WHITE, true)
	count_label.position = Vector2(118, -8)
	count_label.size = Vector2(70, 60)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(count_label)
	pct_label = _lbl("%", 18, Color(0.75, 0.93, 1.0), true)
	pct_label.position = Vector2(190, 20)
	box.add_child(pct_label)

	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(fade)
	_layout()
	get_viewport().size_changed.connect(_layout)


func _lbl(txt: String, size: int, col: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", font_bold if bold else FONT_FILE)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0.08, 0.12, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _layout() -> void:
	var vs := get_viewport_rect().size
	var s := minf(vs.x / BASE.x, vs.y / BASE.y)
	stage.scale = Vector2(s, s)
	stage.position = (vs - BASE * s) * 0.5


# ---------------- แอนิเมชันเปิด ----------------

func _intro() -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.35)
	# แผงพุ่งเข้ามาจากสองข้าง
	panels[0].offset = Vector2(-700, 0)
	panels[1].offset = Vector2(700, 0)
	vs_root.scale = Vector2(3.0, 3.0)
	vs_root.modulate.a = 0.0
	map_bar.modulate.a = 0.0
	for i in 2:
		var p = panels[i]
		var pt := create_tween()
		pt.tween_interval(0.12 + i * 0.1)
		pt.tween_callback(func(): _sfx(SFX_WHOOSH, -6.0, 1.1 - i * 0.12))
		pt.tween_property(p, "offset", Vector2.ZERO, 0.38).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var vt := create_tween()
	vt.tween_interval(0.62)
	vt.tween_callback(func(): _sfx(SFX_SLAM, -5.0, 1.15))
	vt.tween_property(vs_root, "modulate:a", 1.0, 0.06)
	vt.parallel().tween_property(vs_root, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	vt.tween_callback(_slam_flash)
	vt.tween_property(map_bar, "modulate:a", 1.0, 0.3)


func _slam_flash() -> void:
	for p in panels:
		p.flash = 1.0
	var f := ColorRect.new()
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.color = Color(0.8, 0.95, 1.0, 0.55)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(f)
	ov.move_child(f, fade.get_index())
	var tw := create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.35)
	tw.tween_callback(f.queue_free)


# ---------------- โหลด + ตัวนับ ----------------

func _process(delta: float) -> void:
	t += delta
	# กล้องดันเข้าช้าๆ ให้ภาพมีชีวิต
	bg.scale = Vector2.ONE * (1.0 + t * 0.012)
	bg.pivot_offset = bg.size * 0.5
	for p in panels:
		p.flash = maxf(0.0, p.flash - delta * 2.5)
		p.t = t
		p.queue_redraw()

	match state:
		0:
			var real := 1.0
			if loaded == null and not load_failed:      # ถามสถานะจนกว่าจะได้ไฟล์ (ได้แล้วห้ามถามซ้ำ)
				var prog: Array = []
				var st := ResourceLoader.load_threaded_get_status(path, prog)
				match st:
					ResourceLoader.THREAD_LOAD_LOADED:
						loaded = ResourceLoader.load_threaded_get(path) as PackedScene
						load_failed = loaded == null
					ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
						load_failed = true
					_:
						real = float(prog[0]) if prog.size() > 0 else 0.0
			var by_time := clampf(t / (min_time * 0.7), 0.0, 1.0)
			by_time = 1.0 - pow(1.0 - by_time, 1.6)
			target = minf(by_time, real) * 70.0
			if (loaded or load_failed) and shown >= 69.5:
				if load_failed:
					state = 5
					_finish()
				else:
					target = 75.0
					state = 1
		1:
			if shown >= 74.5:
				state = 2
		2:
			game = loaded.instantiate()            # (ค้างนิดหนึ่ง) สร้างฉากเกม
			target = 82.0
			shown = 82.0
			state = 3
		3:
			game.process_mode = Node.PROCESS_MODE_DISABLED   # ยังไม่ให้เกมเดิน
			GameState.game_live = false                      # ยังไม่เปิดเพลง/เสียงพูด
			get_tree().root.add_child(game)        # (ค้างนิดหนึ่ง) _ready: สร้างแอนิเมชัน ชนแมพ ฯลฯ
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			target = 90.0
			shown = 90.0
			warm = 0
			state = 4
		4:
			warm += 1                              # ฉากเกมถูกเรนเดอร์อยู่ข้างหลังจริงแล้ว
			var k := clampf(float(warm) / warmup_frames, 0.0, 1.0)
			target = 90.0 + 10.0 * k
			if warm >= warmup_frames and t >= min_time and shown >= 99.9:
				state = 5
				_finish()
	shown = move_toward(shown, target, delta * 90.0)
	count_label.text = str(clampi(int(round(shown)), 1, 100))


## ถึง 100: ค้างแป๊บ -> ปลุกฉากเกมให้เดิน -> จางหน้า VS ออก
func _finish() -> void:
	if done:
		return
	done = true
	count_label.text = "100"
	load_label.text = "READY"
	var tw := create_tween()
	tw.tween_interval(hold_at_100)
	tw.tween_callback(_go)


func _go() -> void:
	if game == null:
		get_tree().change_scene_to_file(path)       # สำรอง: โหลดแบบปกติ
		return
	game.process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().current_scene = game
	if game.has_method("begin"):
		game.begin()                                 # เปิดเพลง + เสียงพูดเริ่มเกม
	else:
		GameState.game_live = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var tw := create_tween()
	tw.tween_property(ov, "modulate:a", 0.0, 0.45)
	tw.tween_callback(queue_free)


func _sfx(stream: AudioStream, vol := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = stream
	p.volume_db = vol
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# ---------------- แผงตัวละครเอียง (วาดเอง) ----------------

class VsPanel extends Control:
	var pts := PackedVector2Array()
	var tex: Texture2D
	var accent := Color.WHITE
	var offset := Vector2.ZERO
	var flash := 0.0
	var t := 0.0
	var zoom := 1.18               # ขยายภาพตัวละครให้เห็นหัวถึงต้นขา (แบบภาพอ้างอิง)

	func _draw() -> void:
		var p := PackedVector2Array()
		for v in pts:
			p.append(v + offset)
		var mn := p[0]
		var mx := p[0]
		for v in p:
			mn = mn.min(v)
			mx = mx.max(v)
		var box := mx - mn
		# พื้นในแผง: ฟ้าอมเทาด้านบน -> เขียวน้ำทะเลเข้มด้านล่าง
		var top := Color(0.55, 0.72, 0.76)
		var bot := Color(0.12, 0.38, 0.42)
		var cols := PackedColorArray()
		for v in p:
			cols.append(top.lerp(bot, (v.y - mn.y) / box.y))
		draw_polygon(p, cols)
		# ตัวละคร: ครอปแบบ cover ยึดด้านบน
		if tex:
			var ts := tex.get_size()
			var s := maxf(box.x / ts.x, box.y / ts.y) * zoom
			var draw_w := ts.x * s
			var ox := (draw_w - box.x) * 0.5
			var uvs := PackedVector2Array()
			for v in p:
				uvs.append(Vector2((v.x - mn.x + ox) / draw_w, (v.y - mn.y + 4.0) / (ts.y * s)))
			draw_polygon(p, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), uvs, tex)
		# เงามืดด้านล่าง + แสงสีประจำตัวบางๆ
		var shade := PackedColorArray()
		for v in p:
			var k := (v.y - mn.y) / box.y
			shade.append(Color(0.0, 0.05, 0.08, clampf((k - 0.55) * 1.6, 0.0, 0.7)))
		draw_polygon(p, shade)
		if flash > 0.0:
			draw_polygon(p, PackedColorArray([Color(1, 1, 1, flash * 0.6), Color(1, 1, 1, flash * 0.6), Color(1, 1, 1, flash * 0.6), Color(1, 1, 1, flash * 0.6)]))
		# ขอบเรืองแสง (ฟ้าขาว) + ประกายไล่ตามขอบ
		var loop := PackedVector2Array(p)
		loop.append(p[0])
		var pulse := 0.8 + 0.2 * sin(t * 2.4)
		draw_polyline(loop, Color(0.55, 0.9, 1.0, 0.1 * pulse), 16.0, true)
		draw_polyline(loop, Color(0.6, 0.93, 1.0, 0.22 * pulse), 8.0, true)
		draw_polyline(loop, Color(0.85, 0.98, 1.0, 0.95), 2.5, true)
		var edge_t := fmod(t * 0.35, 1.0)
		var per := 0.0
		var lens: Array = []
		for i in 4:
			var l := p[i].distance_to(p[(i + 1) % 4])
			lens.append(l)
			per += l
		var dist := edge_t * per
		for i in 4:
			if dist <= lens[i]:
				var sp := p[i].lerp(p[(i + 1) % 4], dist / lens[i])
				draw_circle(sp, 7.0, Color(0.8, 0.97, 1.0, 0.25))
				draw_circle(sp, 3.0, Color(1, 1, 1, 0.95))
				break
			dist -= lens[i]


## แถบชื่อแมพ: พื้นมืดจางที่ขอบ + ชื่อแมพกลาง
class MapBar extends Control:
	var text := ""
	var font: Font
	var _grad: GradientTexture2D

	func _draw() -> void:
		if _grad == null:
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
			g.colors = PackedColorArray([Color(0.02, 0.06, 0.08, 0.0), Color(0.02, 0.06, 0.08, 0.8), Color(0.02, 0.06, 0.08, 0.8), Color(0.02, 0.06, 0.08, 0.0)])
			_grad = GradientTexture2D.new()
			_grad.gradient = g
			_grad.width = 256
			_grad.height = 4
		draw_texture_rect(_grad, Rect2(Vector2.ZERO, size), false)
		draw_line(Vector2(size.x * 0.15, 0), Vector2(size.x * 0.85, 0), Color(0.6, 0.9, 1.0, 0.35), 1.0)
		if font:
			var fs := 13
			var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, Vector2((size.x - tw) * 0.5, size.y * 0.5 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.9, 0.97, 1.0))
