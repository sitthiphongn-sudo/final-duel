extends Node3D
## ฉากต่อสู้ 2 คนจอเดียว: ปรับสีแมพ, HUD, ประกาศผู้ชนะแล้วเริ่มยกใหม่, พักเกม (Esc)

@export_range(0.2, 1.0) var map_brightness := 1.0   ## คูณสี texture แมพ (1 = สีเดิม)
@export var music: AudioStream = preload("res://s_b.wav")   ## เพลงประกอบตอนเล่น (วนซ้ำ)
@export_range(0.0, 1.0) var music_volume := 0.75            ## ความดังเพลง (0.75 = 75%)
@export_file("*.tscn") var menu_scene := "res://scenes/menu.tscn"
@export var round_restart_delay := 4.5   ## วินาทีหลัง K.O. ก่อนเริ่มยกใหม่
@export var arena_floor_y := -0.04       ## ความสูงพื้นลานเรียบที่ตัวละครยืน (พื้นแมพจริงขรุขระ ±5 ซม.)

const Hud := preload("res://scripts/hud.gd")
const GameState := preload("res://scripts/game_state.gd")

signal started      ## ปล่อยตอนฉากเกมเริ่มจริง (หลังหน้า VS จางออก)

var music_player: AudioStreamPlayer
var hud
var round_over := false
var wins := {1: 0, 2: 0}
var pause_layer: CanvasLayer
var pause_btn_layer: CanvasLayer


## หน้า VS เรียกเมื่อพร้อมเปิดฉากเกม
func begin() -> void:
	GameState.game_live = true
	started.emit()


func _ready() -> void:
	_setup_hud.call_deferred()
	GameState.init_settings()
	GameState.setup_inputs()
	if music:
		music_player = AudioStreamPlayer.new()
		music_player.bus = "Music"
		music_player.stream = music
		music_player.volume_db = linear_to_db(music_volume)
		add_child(music_player)
		music_player.finished.connect(music_player.play)   # วนเพลง
		if GameState.game_live:
			music_player.play()
		else:
			started.connect(music_player.play, CONNECT_ONE_SHOT)   # รอหน้า VS จางออกก่อนค่อยเปิดเพลง
	var t := Time.get_ticks_msec()
	_swap_map()
	var map := $Map
	var baked := map.has_node("Collision")     # แมพเวอร์ชันเบามี collision ทำไว้แล้ว
	for mi in map.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not baked:
			m.create_trimesh_collision()
		if map.has_meta("keep_colors"):
			continue                               # แมพที่ใช้สีเดิมของโมเดล (ไม่ย้อมมืด)
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i)
			if mat is BaseMaterial3D:
				var dark := mat.duplicate() as BaseMaterial3D
				dark.albedo_color = Color(map_brightness, map_brightness, map_brightness)
				dark.metallic = 0.0
				dark.metallic_specular = 0.25   # ลดแสงสะท้อนฟ้า (ต้นเหตุสีขาวอมฟ้า)
				dark.roughness_texture = null
				dark.roughness = 1.0
				dark.normal_scale = 0.6         # ลดความขรุขระของพื้น
				m.set_surface_override_material(i, dark)
		if GameState.gfx == 0:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # แมพไม่ต้องวาดลงเงาซ้ำ (เงาตัวละครยังอยู่)
	_build_arena_floor()
	GameState.apply_scene_graphics(self)
	print("เตรียมแมพเสร็จใน %d ms (กราฟิก %s)" % [Time.get_ticks_msec() - t, GameState.GFX_NAMES[GameState.gfx]])
	_build_pause()
	_build_fps()


## แมพที่เลือกในเมนู (ถ้าไม่ใช่แมพเริ่มต้น -> เอาแมพ Skyborne ออกแล้วสร้างแมพใหม่แทน)
func _swap_map() -> void:
	var path: String = GameState.map()["scene"]
	if path == "":
		return
	var old := $Map
	old.name = "OldMap"
	var nm: Node3D = (load(path) as GDScript).new()
	nm.name = "Map"
	nm.position.y = arena_floor_y
	add_child(nm)
	move_child(nm, old.get_index())
	old.queue_free()


## พื้นเรียบล่องหน (เลเยอร์ 3) ให้ตัวละครเดิน: collision แมพที่ลดรายละเอียดมีรอยต่อ/หลุมเล็กๆ ทำให้เดินสะดุด
func _build_arena_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "ArenaFloor"
	body.collision_layer = 4
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	cs.shape = box
	body.add_child(cs)
	body.position = Vector3(0, arena_floor_y - 0.5, 0)
	add_child(body)


func _fighter(i: int) -> Node:
	return get_tree().get_first_node_in_group("p%d" % i)


func _setup_hud() -> void:
	var p := _fighter(1)
	var e := _fighter(2)
	if p == null or e == null:
		return
	hud = Hud.new()
	hud.add_to_group("hud")
	add_child(hud)
	hud.setup(p, e)


# ================= จบยก =================

## ตัวละครเรียกเมื่อเลือดหมด
func on_fighter_ko(loser) -> void:
	if round_over:
		return
	round_over = true
	var winner_i: int = 3 - int(loser.player_index)
	wins[winner_i] += 1
	for i in [1, 2]:
		var f = _fighter(i)
		if f:
			f.controls_locked = true
	if hud:
		hud.show_ko("K.O.")
	await get_tree().create_timer(1.6, true, false, true).timeout
	var w = _fighter(winner_i)
	var col: Color = GameState.data(w.char_id)["color"] if w else Color.WHITE
	if hud:
		hud.show_banner("PLAYER %d WINS   ( %d - %d )" % [winner_i, wins[1], wins[2]], col, 2.2)
	await get_tree().create_timer(maxf(0.5, round_restart_delay - 1.6), true, false, true).timeout
	# รออัลติเมต (คัทซีน) จบก่อน
	while (_fighter(1) and _fighter(1).in_ult) or (_fighter(2) and _fighter(2).in_ult):
		await get_tree().process_frame
	for i in [1, 2]:
		var f = _fighter(i)
		if f:
			f.reset_round()
			f.controls_locked = false
	round_over = false


# ================= พักเกม =================

const PAUSE_FONT := preload("res://fonts/BarlowCondensed-BoldItalic.woff2")
const PAUSE_ORANGE := Color(1.0, 0.62, 0.12)
const CHAR_SELECT_SCENE := "res://scenes/character_select.tscn"
var pause_items: Array = []        ## [{label, bar, id}]
var pause_sel := 0
var pause_sub: Label


func _pl(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", PAUSE_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_pause() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 20
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_layer.visible = false
	add_child(pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.30)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_layer.add_child(dim)
	# แผงมืดไล่เฉดจากซ้าย
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.03, 0.06, 0.92))
	grad.set_color(1, Color(0.02, 0.03, 0.06, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	var panel := TextureRect.new()
	panel.texture = gt
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.anchor_right = 0.62
	panel.offset_right = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.anchor_left = 0.07
	box.anchor_right = 0.6
	box.anchor_top = 0.2
	box.anchor_bottom = 0.95
	box.offset_left = 0
	box.offset_right = 0
	box.offset_top = 0
	box.offset_bottom = 0
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_layer.add_child(box)
	var H := get_viewport().get_visible_rect().size.y
	var line := ColorRect.new()
	line.color = PAUSE_ORANGE
	line.custom_minimum_size = Vector2(54, 4)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)
	box.add_child(_pl("GAME PAUSED", int(H * 0.032), PAUSE_ORANGE))
	var title := _pl("PAUSED", int(H * 0.15), Color.WHITE)
	title.add_theme_color_override("font_shadow_color", PAUSE_ORANGE)
	title.add_theme_constant_override("shadow_offset_x", 6)
	title.add_theme_constant_override("shadow_offset_y", 6)
	box.add_child(title)
	pause_sub = _pl("ROUND 1  ·  P1  0 - 0  P2", int(H * 0.03), Color(0.78, 0.8, 0.85))
	box.add_child(pause_sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, H * 0.03)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap)
	pause_items.clear()
	for item in [["RESUME", "resume"], ["CHARACTER SELECT", "chars"], ["MAIN MENU", "menu"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var bar := ColorRect.new()
		bar.color = PAUSE_ORANGE
		bar.custom_minimum_size = Vector2(5, H * 0.065)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bar)
		var lab := _pl(item[0], int(H * 0.08), Color.WHITE)
		row.add_child(lab)
		var idx := pause_items.size()
		row.mouse_entered.connect(func(): pause_select(idx))
		row.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				pause_select(idx)
				_pause_action(item[1]))
		box.add_child(row)
		pause_items.append({"label": lab, "bar": bar, "id": item[1]})
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sp)
	box.add_child(_pl("W / S · UP / DOWN select     ENTER / J / NUM1 confirm     or click", int(H * 0.026), Color(0.62, 0.64, 0.7)))
	pause_select(0)
	# ปุ่ม II มุมขวาบน ไว้กดด้วยเมาส์ (เผื่อเว็บที่ Esc ถูกเบราว์เซอร์ใช้)
	var pb := Button.new()
	pb.text = "II"
	pb.tooltip_text = "Pause (Esc / P)"
	pb.focus_mode = Control.FOCUS_NONE
	pb.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pb.position = Vector2(-22, 8)
	pb.custom_minimum_size = Vector2(44, 36)
	pb.pressed.connect(toggle_pause)
	pb.process_mode = Node.PROCESS_MODE_ALWAYS
	var pl := CanvasLayer.new()
	pl.layer = 19
	pl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pl)
	pl.add_child(pb)
	pause_btn_layer = pl
	var handler := PauseInput.new()
	handler.main = self
	pause_layer.add_child(handler)


func _pause_action(what: String) -> void:
	match what:
		"resume":
			toggle_pause()
		"chars":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().paused = false
			Engine.time_scale = 1.0
			get_tree().change_scene_to_file(CHAR_SELECT_SCENE)
		"menu":
			to_menu()


func pause_select(i: int) -> void:
	if pause_items.is_empty():
		return
	pause_sel = posmod(i, pause_items.size())
	for k in pause_items.size():
		var on := k == pause_sel
		var it: Dictionary = pause_items[k]
		(it.label as Label).add_theme_color_override("font_color", PAUSE_ORANGE if on else Color.WHITE)
		(it.bar as ColorRect).modulate.a = 1.0 if on else 0.0


func pause_confirm() -> void:
	if not pause_items.is_empty():
		_pause_action(pause_items[pause_sel].id)


var _mouse_before := Input.MOUSE_MODE_VISIBLE


func toggle_pause() -> void:
	var p := not get_tree().paused
	if p:
		_mouse_before = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE      # เปิดเคอร์เซอร์ให้คลิกเมนูได้ (ในเกมเมาส์ถูกล็อกอยู่)
	else:
		Input.mouse_mode = _mouse_before
	if p and pause_sub:
		pause_sub.text = "ROUND %d  ·  P1  %d - %d  P2" % [wins[1] + wins[2] + 1, wins[1], wins[2]]
		pause_select(0)
	get_tree().paused = p
	pause_layer.visible = p
	if pause_btn_layer:
		pause_btn_layer.visible = not p
	Engine.time_scale = 1.0


func to_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(menu_scene)


# ================= ตัวนับ FPS (กด F3) =================

var fps_label: Label

func _build_fps() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 21
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	fps_label = Label.new()
	fps_label.position = Vector2(12, 8)
	fps_label.add_theme_font_size_override("font_size", 16)
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.add_theme_constant_override("outline_size", 5)
	fps_label.visible = GameState.show_fps
	layer.add_child(fps_label)
	var tm := Timer.new()
	tm.wait_time = 0.5
	tm.autostart = true
	tm.ignore_time_scale = true
	tm.timeout.connect(func():
		if fps_label.visible:
			fps_label.text = "%d FPS  ·  %s" % [Engine.get_frames_per_second(), GameState.GFX_NAMES[GameState.gfx]])
	layer.add_child(tm)


func toggle_fps() -> void:
	GameState.show_fps = not GameState.show_fps
	fps_label.visible = GameState.show_fps
	fps_label.text = "-- FPS"
	GameState.save_settings()


## รับปุ่มตอนเกมหยุด (ต้องทำงานตลอดแม้ตอน pause)
class PauseInput extends Node:
	var main
	func _unhandled_input(event: InputEvent) -> void:
		if not (event is InputEventKey and event.pressed and not event.echo):
			return
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			main.toggle_pause()
		elif event.keycode == KEY_F3:
			main.toggle_fps()
		elif not main.get_tree().paused:
			return
		elif event.keycode == KEY_M:
			main.to_menu()
		elif event.keycode in [KEY_W, KEY_UP]:
			main.pause_select(main.pause_sel - 1)
		elif event.keycode in [KEY_S, KEY_DOWN]:
			main.pause_select(main.pause_sel + 1)
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_J, KEY_KP_1]:
			main.pause_confirm()
