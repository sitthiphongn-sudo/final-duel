extends Node
## เสียงพูดญี่ปุ่น + ซับไตเติลด้านล่างจอ
## เสียงสังเคราะห์จาก VOICEVOX (เสียง 青山龍星) ไฟล์อยู่ในโฟลเดอร์ voice/

const LINES := {
	"start": {
		"stream": preload("res://voice/voice_start.mp3"),
		"jp": "いくぞ！",
		"romaji": "Ikuzo!",
		"en": "Let's go!",
	},
	"walk": {
		"stream": preload("res://voice/voice_walk.mp3"),
		"jp": "燃え尽きろ！",
		"romaji": "Moetsukiro!",
		"en": "Burn to ashes!",
	},
	"ult": {
		"stream": preload("res://voice/voice_ult.mp3"),
		"jp": "これで終わりだ！",
		"romaji": "Kore de owari da!",
		"en": "This ends now!",
	},
}

## ฟอนต์ระบบของ Windows (ฟอนต์เริ่มต้นของ Godot ไม่มีตัวอักษรญี่ปุ่น/ไทย)
const JP_FONTS := ["C:/Windows/Fonts/YuGothM.ttc", "C:/Windows/Fonts/meiryo.ttc", "C:/Windows/Fonts/msgothic.ttc"]
const TH_FONTS := ["C:/Windows/Fonts/leelawui.ttf", "C:/Windows/Fonts/tahoma.ttf", "C:/Windows/Fonts/upcjl.ttf"]

@export var volume_db := 2.0
@export var show_translation := true   ## แสดงคำแปลภาษาอังกฤษต่อท้ายคำอ่าน

var ui: CanvasLayer
var box: VBoxContainer
var label_jp: Label
var label_sub: Label
var _hide_at := 0.0


func _ready() -> void:
	_build_ui()


func say(key: String, delay := 0.0) -> void:
	if not LINES.has(key):
		return
	if delay > 0.0:
		await get_tree().create_timer(delay, true, false, true).timeout
	var line: Dictionary = LINES[key]
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = line.stream
	p.volume_db = volume_db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	var dur: float = maxf(1.2, (line.stream as AudioStream).get_length() + 0.5)
	_show(line, dur)


func _show(line: Dictionary, dur: float) -> void:
	label_jp.text = line.jp
	var sub: String = line.romaji
	if show_translation:
		sub += "   ·   " + line.en
	label_sub.text = sub
	_hide_at = Time.get_ticks_msec() / 1000.0 + dur
	box.modulate.a = 0.0
	box.visible = true
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(box, "modulate:a", 1.0, 0.15)


func _process(_delta: float) -> void:
	if box.visible and Time.get_ticks_msec() / 1000.0 > _hide_at:
		box.visible = false
	# วางซับไว้เหนือเกจอัลติเมต ตรงกลางจอ
	var vs := get_viewport().get_visible_rect().size
	box.size = Vector2(vs.x * 0.8, 0)
	box.position = Vector2(vs.x * 0.1, vs.y - 148)


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 6
	add_child(ui)
	box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.visible = false
	ui.add_child(box)

	var jp_font := _load_font(JP_FONTS)
	var th_font := _load_font(TH_FONTS, jp_font)

	label_jp = Label.new()
	label_jp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_jp.add_theme_font_size_override("font_size", 34)
	label_jp.add_theme_color_override("font_color", Color(1, 0.96, 0.9))
	label_jp.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label_jp.add_theme_constant_override("outline_size", 10)
	if jp_font:
		label_jp.add_theme_font_override("font", jp_font)
	box.add_child(label_jp)

	label_sub = Label.new()
	label_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_sub.add_theme_font_size_override("font_size", 20)
	label_sub.add_theme_color_override("font_color", Color(1, 0.85, 0.6))
	label_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label_sub.add_theme_constant_override("outline_size", 8)
	if th_font:
		label_sub.add_theme_font_override("font", th_font)
	box.add_child(label_sub)


## โหลดฟอนต์จากเครื่อง (ตัวแรกที่เจอ) พร้อมฟอนต์สำรองสำหรับตัวอักษรที่ไม่มี
func _load_font(paths: Array, fallback: Font = null) -> Font:
	for p in paths:
		if FileAccess.file_exists(p):
			var f := FontFile.new()
			f.load_dynamic_font(p)
			if fallback:
				f.fallbacks = [fallback]
			return f
	return fallback
