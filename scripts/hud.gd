extends Node
## HUD สไตล์เกมต่อสู้ ใช้กรอบหลอดงานอาร์ตที่ตัดมาเป็นซ้าย/ขวา (สมมาตรกัน)
## ซ้าย = ผู้เล่น 1, ขวา = ผู้เล่น 2, ตัวนับคอมโบขึ้นฝั่งคนที่กำลังต่อย
## สีในหลอดวาดด้วยโค้ด (เลือด / สตามินา / อัลติเมต)

const GameState := preload("res://scripts/game_state.gd")

const F_HP_L := preload("res://ui/frame_hp_l.png")
const F_HP_R := preload("res://ui/frame_hp_r.png")
const F_ST_L := preload("res://ui/frame_sta_l.png")
const F_ST_R := preload("res://ui/frame_sta_r.png")
const F_EX_L := preload("res://ui/frame_ult_l.png")
const F_EX_R := preload("res://ui/frame_ult_r.png")

## ขนาดจริงของกรอบ + ช่องว่างข้างใน (x, y, w, h) + ตำแหน่งเยื้องตามงานอาร์ตต้นฉบับ
const FRAME_W := {"hp": 1012.0, "st": 689.0, "ex": 436.0}
const FRAME_H := {"hp": 187.0, "st": 102.0, "ex": 99.0}
const HOLE_L := {"hp": [97.0, 52.0, 853.0, 58.0], "st": [75.0, 28.0, 566.0, 37.0], "ex": [78.0, 28.0, 319.0, 37.0]}
const HOLE_R := {"hp": [62.0, 52.0, 853.0, 58.0], "st": [48.0, 28.0, 566.0, 37.0], "ex": [39.0, 28.0, 319.0, 37.0]}
const OFF_X := {"hp": 0.0, "st": 129.0, "ex": 200.0}
const OFF_Y := {"hp": 0.0, "st": 140.0, "ex": 232.0}

const UI_SCALE := 0.40                    ## ย่อกรอบลงมาให้พอดีจอ
const POR := 84.0                         ## ขนาดรูปตัวละคร
const GROUP_X := 92.0                    ## กรอบหลอดเริ่มถัดจากรูป
const GROUP_Y := 24.0

const C_HP_FIRE := Color(0.90, 0.16, 0.10)
const C_HP_ICE := Color(0.16, 0.48, 0.95)
const C_STAMINA := Color(0.95, 0.78, 0.25)
const C_FURY := Color(1.0, 0.52, 0.10)
const C_MAGIC := Color(0.35, 0.82, 1.0)

var player
var enemy
var ui: CanvasLayer
var root: Control

var hp_fill := {}
var hp_ghost := {}
var hp_text := {}
var st_fill := {}
var ex_fill := {}
var ex_label := {}
var name_label := {}
var portrait_node := {}
var side_panel := {}

var combo_box: VBoxContainer
var combo_num: Label
var combo_hit: Label
var ko_label: Label

var combo := 0
var combo_timer := 0.0
var combo_owner := 0
var banner: Label
var hint_box: VBoxContainer

var _ftex: GradientTexture2D = null
var _panel_w := 0.0
var _panel_h := 0.0
var _last_ms := 0
var _cur_ice := false        # กรอบหลอดของฝั่งที่กำลังสร้างเป็นลายน้ำแข็งไหม


func setup(p, e) -> void:
	player = p
	enemy = e
	_panel_w = GROUP_X + FRAME_W["hp"] * UI_SCALE
	_panel_h = GROUP_Y + (OFF_Y["ex"] + FRAME_H["ex"]) * UI_SCALE
	_build()


# ---------- สร้าง UI ----------

func _build() -> void:
	ui = CanvasLayer.new()
	ui.layer = 4
	add_child(ui)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	# แต่ละฝั่งใช้ข้อมูลตัวละครที่ถูกเลือก (รูป ชื่อ สีหลอด กรอบธาตุไฟ/น้ำแข็ง)
	for side in ["p", "e"]:
		var d: Dictionary = GameState.data(GameState.p1 if side == "p" else GameState.p2)
		_cur_ice = d["element"] == "ice"
		_build_side(side, side == "p", d["name"], load(d["portrait"]), d["hp_color"], d["ex_name"], d["ex_color"], "1" if side == "p" else "2")
	_build_combo()

	ko_label = _label("", 84, Color(1, 0.9, 0.7), 14)
	ko_label.set_anchors_preset(Control.PRESET_CENTER)
	ko_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ko_label.visible = false
	root.add_child(ko_label)

	# ป้ายผู้ชนะ (ใต้ K.O.)
	banner = _label("", 46, Color(1, 0.95, 0.8), 10)
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.position.y += 70
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.visible = false
	root.add_child(banner)

	# ปุ่มของทั้งสองคน โชว์ช่วงแรกของเกมแล้วค่อยๆ จางหาย
	hint_box = VBoxContainer.new()
	hint_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_box.position = Vector2(-560, -56)
	hint_box.size = Vector2(1120, 60)
	hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint_box)
	for i in [1, 2]:
		var h := _label(GameState.CONTROLS_TEXT[i], 15, Color(1, 1, 1, 0.9), 5)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_box.add_child(h)
	var ht := create_tween()
	ht.tween_interval(9.0)
	ht.tween_property(hint_box, "modulate:a", 0.0, 1.5)


func _label(txt: String, size: int, col: Color, outline := 8) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## ไล่เฉดบนลงล่างให้หลอดดูมีมิติ (สีจริงใส่ผ่าน modulate)
func _fill_tex() -> GradientTexture2D:
	if _ftex != null:
		return _ftex
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.18, 0.52, 0.56, 1.0])
	gr.colors = PackedColorArray([
		Color(1.35, 1.35, 1.35, 1.0),
		Color(1.10, 1.10, 1.10, 1.0),
		Color(0.80, 0.80, 0.80, 1.0),
		Color(0.55, 0.55, 0.55, 1.0),
		Color(0.85, 0.85, 0.85, 1.0)])
	var t := GradientTexture2D.new()
	t.gradient = gr
	t.width = 8
	t.height = 64
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	_ftex = t
	return _ftex


func _tex_rect(parent: Control, tex: Texture2D, pos: Vector2, size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE        # ต้องตั้งก่อนกำหนดขนาดเสมอ
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture = tex
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## วางหลอดหนึ่งอัน: พื้นมืด -> แถบผี -> แถบสี -> กรอบอาร์ตทับข้างบน
func _frame_bar(panel: Control, key: String, left: bool, color: Color, ghost: bool) -> Array:
	# กรอบลายไฟ = อาร์ตฝั่งซ้าย, ลายน้ำแข็ง = อาร์ตฝั่งขวา -> ถ้าอยู่คนละฝั่งกับจอก็กลับด้าน (สมมาตรพอดี)
	var tex: Texture2D
	if not _cur_ice:
		tex = F_HP_L if key == "hp" else (F_ST_L if key == "st" else F_EX_L)
	else:
		tex = F_HP_R if key == "hp" else (F_ST_R if key == "st" else F_EX_R)
	var flip: bool = _cur_ice == left
	var fw: float = FRAME_W[key] * UI_SCALE
	var fh: float = FRAME_H[key] * UI_SCALE
	var hp_w: float = FRAME_W["hp"] * UI_SCALE
	var gx: float = 0.0
	if left:
		gx = GROUP_X + OFF_X[key] * UI_SCALE
	else:
		gx = hp_w - OFF_X[key] * UI_SCALE - fw
	var pos := Vector2(gx, GROUP_Y + OFF_Y[key] * UI_SCALE)

	var hole: Array = (HOLE_L[key] if left else HOLE_R[key])
	var hpos := pos + Vector2(float(hole[0]) * UI_SCALE, float(hole[1]) * UI_SCALE)
	var hsize := Vector2(float(hole[2]) * UI_SCALE, float(hole[3]) * UI_SCALE)

	var back := ColorRect.new()
	back.color = Color(0.03, 0.03, 0.05, 0.72)
	back.position = hpos
	back.size = hsize
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(back)

	var g: TextureRect = null
	if ghost:
		g = _tex_rect(panel, _fill_tex(), hpos, hsize)
		g.modulate = Color(1, 1, 1, 0.5)
		g.pivot_offset = Vector2(hsize.x if not left else 0.0, 0.0)

	var f := _tex_rect(panel, _fill_tex(), hpos, hsize)
	f.modulate = color
	f.pivot_offset = Vector2(hsize.x if not left else 0.0, 0.0)

	var fr := _tex_rect(panel, tex, pos, Vector2(fw, fh))
	fr.flip_h = flip
	return [f, g, hpos, hsize]


func _build_side(side: String, left: bool, disp_name: String, portrait: Texture2D,
		hp_col: Color, ex_name: String, ex_color: Color, number: String) -> void:
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(18, 14)
	panel.size = Vector2(_panel_w, _panel_h)
	root.add_child(panel)
	side_panel[side] = panel

	var hp_w: float = FRAME_W["hp"] * UI_SCALE
	var por_x: float = 2.0 if left else _panel_w - POR - 2.0
	var por := _tex_rect(panel, portrait, Vector2(por_x, GROUP_Y + 6.0), Vector2(POR, POR))
	por.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_node[side] = por

	var num := _label(number, 17, Color(1, 0.95, 0.85), 6)
	num.position = Vector2(por_x + 34, GROUP_Y + POR - 16)
	panel.add_child(num)

	var gx0: float = GROUP_X if left else 0.0
	var nm := _label(disp_name, 18, Color(1, 0.96, 0.9), 7)
	nm.position = Vector2(gx0 + 6, 0) if left else Vector2(gx0 + hp_w - 246, 0)
	nm.size = Vector2(240, 22)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(nm)
	name_label[side] = nm

	var hp := _frame_bar(panel, "hp", left, hp_col, true)
	hp_fill[side] = hp[0]
	hp_ghost[side] = hp[1]
	var hpos: Vector2 = hp[2]
	var hsize: Vector2 = hp[3]
	var ht := _label("500/500", 14, Color(1, 1, 1, 0.92), 6)
	ht.position = Vector2(hpos.x + hsize.x - 96, hpos.y + hsize.y * 0.5 - 11) if left else Vector2(hpos.x + 6, hpos.y + hsize.y * 0.5 - 11)
	ht.size = Vector2(90, 20)
	ht.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if left else HORIZONTAL_ALIGNMENT_LEFT
	panel.add_child(ht)
	hp_text[side] = ht

	var st := _frame_bar(panel, "st", left, C_STAMINA, false)
	st_fill[side] = st[0]
	var sp: Vector2 = st[2]
	var ss: Vector2 = st[3]
	var stl := _label("STAMINA", 10, Color(0.15, 0.1, 0.02, 0.9), 0)
	stl.position = Vector2(sp.x + 8, sp.y + ss.y * 0.5 - 9) if left else Vector2(sp.x + ss.x - 88, sp.y + ss.y * 0.5 - 9)
	stl.size = Vector2(80, 18)
	stl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(stl)

	var ex := _frame_bar(panel, "ex", left, ex_color, false)
	ex_fill[side] = ex[0]
	var ep: Vector2 = ex[2]
	var es: Vector2 = ex[3]
	var exl := _label(ex_name, 11, Color(1, 0.98, 0.92), 5)
	exl.position = Vector2(ep.x + 8, ep.y + es.y * 0.5 - 10) if left else Vector2(ep.x + es.x - 88, ep.y + es.y * 0.5 - 10)
	exl.size = Vector2(80, 20)
	exl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(exl)
	ex_label[side] = exl


func _build_combo() -> void:
	combo_box = VBoxContainer.new()
	combo_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	combo_box.position = Vector2(-230, -40)
	combo_box.size = Vector2(200, 100)
	combo_box.alignment = BoxContainer.ALIGNMENT_CENTER
	combo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_box.visible = false
	root.add_child(combo_box)
	combo_num = _label("0", 64, Color(1, 0.85, 0.3), 12)
	combo_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_box.add_child(combo_num)
	combo_hit = _label("HITS", 24, Color(1, 0.95, 0.85), 8)
	combo_hit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_box.add_child(combo_hit)


# ---------- อัปเดตทุกเฟรม ----------

func _process(delta: float) -> void:
	if root == null:
		return                                   # ยังไม่ได้เรียก setup()
	# ใช้เวลาจริงจากนาฬิกา (delta หารด้วย time_scale พลาดตอน hit-stop เปลี่ยนกลางเฟรม)
	var now := Time.get_ticks_msec()
	var real_delta := clampf((now - _last_ms) / 1000.0, 0.0, 0.1) if _last_ms > 0 else delta
	_last_ms = now
	var vs := get_viewport().get_visible_rect().size
	if side_panel.has("p"):
		side_panel["p"].position = Vector2(18, 14)
	if side_panel.has("e"):
		side_panel["e"].position = Vector2(vs.x - _panel_w - 18.0, 14)
	_update_side("p", player)
	_update_side("e", enemy)

	if combo > 0:
		combo_timer -= real_delta
		if combo_timer <= 0.0:
			combo = 0
			combo_box.visible = false
		# คอมโบขึ้นฝั่งของคนที่ต่อย (P1 ซ้าย / P2 ขวา)
		combo_box.position = Vector2(40.0 if combo_owner == 1 else vs.x - 240.0, vs.y * 0.5 - 50.0)


func _update_side(side: String, ch) -> void:
	if ch == null or not is_instance_valid(ch):
		return
	var hp_ratio: float = clampf(float(ch.hp) / float(ch.hp_max), 0.0, 1.0)
	hp_fill[side].scale.x = hp_ratio
	hp_text[side].text = "%d/%d" % [int(ceil(ch.hp)), int(ch.hp_max)]
	var g: TextureRect = hp_ghost[side]
	if g:
		g.scale.x = maxf(hp_ratio, lerpf(g.scale.x, hp_ratio, 0.06))
	st_fill[side].scale.x = clampf(ch.stamina / ch.stamina_max, 0.0, 1.0)
	ex_fill[side].scale.x = clampf(ch.ult_gauge / 100.0, 0.0, 1.0)
	if ch.ult_gauge >= 100.0:
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 110.0)
		ex_fill[side].modulate.a = pulse
		ex_label[side].modulate.a = pulse
	else:
		ex_fill[side].modulate.a = 1.0
		ex_label[side].modulate.a = 1.0


# ---------- เรียกจากเกม ----------

func add_combo(owner := 1) -> void:
	if owner != combo_owner:
		combo = 0                     # อีกฝ่ายเริ่มต่อย = เริ่มนับใหม่
		combo_owner = owner
	combo += 1
	combo_timer = 1.6
	combo_num.text = str(combo)
	combo_hit.text = "HIT" if combo == 1 else "HITS"
	combo_box.visible = true
	combo_box.scale = Vector2(1.35, 1.35)
	combo_box.pivot_offset = combo_box.size * 0.5
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(combo_box, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## ป้ายผู้ชนะ
func show_banner(text: String, col: Color, hold := 2.0) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", col)
	banner.visible = true
	banner.modulate.a = 0.0
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(banner, "modulate:a", 1.0, 0.25)
	t.tween_interval(hold)
	t.tween_property(banner, "modulate:a", 0.0, 0.4)
	t.tween_callback(func(): banner.visible = false)


func show_ko(text := "K.O.") -> void:
	ko_label.text = text
	ko_label.visible = true
	ko_label.scale = Vector2(2.2, 2.2)
	ko_label.pivot_offset = ko_label.size * 0.5
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(ko_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(1.6)
	t.tween_property(ko_label, "modulate:a", 0.0, 0.5)
	t.tween_callback(func():
		ko_label.visible = false
		ko_label.modulate.a = 1.0)
