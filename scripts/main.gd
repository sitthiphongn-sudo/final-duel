extends Node3D
## สร้าง collision ให้แมพอัตโนมัติ + ลดความสว่าง texture แมพ

@export_range(0.2, 1.0) var map_brightness := 1.0   ## คูณสี texture แมพ (1 = สีเดิม)
@export var music: AudioStream = preload("res://s_b.wav")   ## เพลงประกอบตอนเล่น (วนซ้ำ)
@export_range(0.0, 1.0) var music_volume := 0.75            ## ความดังเพลง (0.75 = 75%)

const Hud := preload("res://scripts/hud.gd")
const GameState := preload("res://scripts/game_state.gd")

signal started      ## ปล่อยตอนฉากเกมเริ่มจริง (หลังหน้า VS จางออก)

var music_player: AudioStreamPlayer
var hud

## หน้า VS เรียกเมื่อพร้อมเปิดฉากเกม
func begin() -> void:
	GameState.game_live = true
	started.emit()


func _ready() -> void:
	_setup_hud.call_deferred()
	GameState.init_settings()
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
	for mi in $Map.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
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


func _setup_hud() -> void:
	var p := get_tree().get_first_node_in_group("player")
	var e := get_tree().get_first_node_in_group("enemy")
	if p == null or e == null:
		return
	hud = Hud.new()
	hud.add_to_group("hud")
	add_child(hud)
	hud.setup(p, e)
