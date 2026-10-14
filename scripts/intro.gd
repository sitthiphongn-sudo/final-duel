extends Control
## คลิปเปิดเกม (video/intro.ogv) เล่นตอนเปิดเกม กดปุ่มไหนก็ได้/คลิกเพื่อข้าม จบแล้วเข้าเมนู
## บนเว็บ: เบราว์เซอร์ไม่ให้เล่นเสียงจนกว่าผู้เล่นจะกดอะไรสักอย่าง เลยมีหน้า "PRESS ANY KEY" คั่นก่อน

const VIDEO := "res://video/intro.ogv"
const MENU := "res://scenes/menu.tscn"

var player: VideoStreamPlayer
var gate: Label
var started := false
var finished := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	player = VideoStreamPlayer.new()
	player.set_anchors_preset(Control.PRESET_FULL_RECT)
	player.expand = true
	player.stream = load(VIDEO)
	player.finished.connect(_done)
	add_child(player)
	gate = Label.new()
	gate.set_anchors_preset(Control.PRESET_FULL_RECT)
	gate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gate.add_theme_font_size_override("font_size", 28)
	gate.text = "FINAL DUEL\n\nPRESS ANY KEY"
	gate.visible = false
	add_child(gate)
	if OS.has_feature("web"):
		gate.visible = true
	else:
		_start()


func _start() -> void:
	started = true
	gate.visible = false
	player.play()
	var hint := Label.new()
	hint.text = "Press any key to skip"
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(1, 1, 1, 0.45)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position = Vector2(-190, -34)
	add_child(hint)


func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if not pressed:
		return
	if not started:
		_start()
	else:
		_done()


func _done() -> void:
	if finished:
		return
	finished = true
	player.stop()
	get_tree().change_scene_to_file.call_deferred(MENU)
