extends Node3D
## ฉากต่อสู้ 2 คนจอเดียว: ปรับสีแมพ, HUD, ประกาศผู้ชนะแล้วเริ่มยกใหม่, พักเกม (Esc)

@export_range(0.2, 1.0) var map_brightness := 1.0   ## คูณสี texture แมพ (1 = สีเดิม)
@export var music: AudioStream = preload("res://s_b.wav")   ## เพลงประกอบตอนเล่น (วนซ้ำ)
@export_range(0.0, 1.0) var music_volume := 0.75            ## ความดังเพลง (0.75 = 75%)
@export_file("*.tscn") var menu_scene := "res://scenes/menu.tscn"
@export var round_restart_delay := 4.5   ## วินาทีหลัง K.O. ก่อนเริ่มยกใหม่

const Hud := preload("res://scripts/hud.gd")
const GameState := preload("res://scripts/game_state.gd")

signal started      ## ปล่อยตอนฉากเกมเริ่มจริง (หลังหน้า VS จางออก)

var music_player: AudioStreamPlayer
var hud
var round_over := false
var wins := {1: 0, 2: 0}
var pause_layer: CanvasLayer


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
	var map := $Map
	var baked := map.has_node("Collision")     # แมพเวอร์ชันเบามี collision ทำไว้แล้ว
	for mi in map.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not baked:
			m.create_trimesh_collision()
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
	print("เตรียมแมพเสร็จใน %d ms" % (Time.get_ticks_msec() - t))
	_build_pause()


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

func _build_pause() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 20
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_layer.visible = false
	add_child(pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(dim)
	var l := Label.new()
	l.text = "PAUSED\n\nEsc  —  Resume\nM  —  Main Menu"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	pause_layer.add_child(l)
	var handler := PauseInput.new()
	handler.main = self
	pause_layer.add_child(handler)


func toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	pause_layer.visible = p
	Engine.time_scale = 1.0


func to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(menu_scene)


## รับปุ่มตอนเกมหยุด (ต้องทำงานตลอดแม้ตอน pause)
class PauseInput extends Node:
	var main
	func _unhandled_input(event: InputEvent) -> void:
		if not (event is InputEventKey and event.pressed and not event.echo):
			return
		if event.keycode == KEY_ESCAPE:
			main.toggle_pause()
		elif event.keycode == KEY_M and main.get_tree().paused:
			main.to_menu()
