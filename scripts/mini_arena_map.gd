extends Node3D
## แมพ "Colosseum Yard" ประกอบสดจากชิ้นส่วน Kenney Mini Arena (CC0) — ไฟล์รวมไม่ถึง 0.5 MB
## ลานกลมกว้าง ~9 ม. มีกำแพงเตี้ยล้อม เสา แบนเนอร์ รูปปั้น และประตูใหญ่ด้านหลังศัตรู
## main.gd จะไม่ย้อมสีแมพนี้ (meta keep_colors) และไม่สร้าง collision ให้ (ใช้พื้นล่องหนของ main)

const DIR := "res://lite/map/mini_arena/"
const S := 2.0                 ## ขยายชิ้นส่วน (1 ชิ้น = 1 ม. -> 2 ม.)
const WALL_R := 9.4            ## รัศมีกำแพง

var _cache := {}


func _ready() -> void:
	set_meta("keep_colors", true)
	var col := StaticBody3D.new()
	col.name = "Collision"                      # ให้ main.gd รู้ว่ามี collision แล้ว (ว่างเปล่า)
	col.collision_layer = 0
	col.collision_mask = 0
	add_child(col)
	_floor()
	_walls()
	_props()
	_outside()


## ชิ้นที่บังกล้อง: เมื่อมาอยู่ระหว่างกล้องกับนักสู้ (หรือชิดกล้อง) จะจมลงพื้นช้าๆ แล้วโผล่กลับเมื่อพ้น
var _occ: Array = []            ## [{n: Node3D, y: float, h: float}]
var _min_h := 0.0


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _occ.is_empty():
		return
	var a := cam.global_position
	var tgt := Vector3.ZERO
	var cnt := 0
	for g in ["p1", "p2"]:
		var f := get_tree().get_first_node_in_group(g) as Node3D
		if f:
			tgt += f.global_position
			cnt += 1
	if cnt == 0:
		return
	tgt /= cnt
	var ab := Vector2(tgt.x - a.x, tgt.z - a.z)
	var len2 := maxf(ab.length_squared(), 0.001)
	for o in _occ:
		var n: Node3D = o["n"]
		var gp := n.global_position
		var ap := Vector2(gp.x - a.x, gp.z - a.z)
		var t := ap.dot(ab) / len2
		var perp := (ap - ab * t).length()
		var hide := (t > -0.15 and t < 1.0 and perp < 2.6) or ap.length() < 3.2
		var want: float = (float(o["y"]) - float(o["h"]) - 0.1) if hide else float(o["y"])
		n.position.y = move_toward(n.position.y, want, delta * 6.0)


func _reg(n: Node3D, h: float) -> void:
	_occ.append({"n": n, "y": n.position.y, "h": h})


func _piece(file: String, pos: Vector3, yaw := 0.0, sc := Vector3.ONE) -> Node3D:
	if not _cache.has(file):
		_cache[file] = load(DIR + file + ".glb")
	var n := (_cache[file] as PackedScene).instantiate() as Node3D
	n.position = pos
	n.rotation.y = yaw
	n.scale = sc * S
	add_child(n)
	return n


func _floor() -> void:
	var n := 5
	for ix in range(-n, n + 1):
		for iz in range(-n, n + 1):
			var p := Vector3(ix, 0, iz) * S
			if Vector2(p.x, p.z).length() > WALL_R - 0.4:
				continue
			var detail := (ix * 7 + iz * 13) % 5 == 0
			_piece("floor-detail" if detail else "floor", p)


func _walls() -> void:
	var count := 30
	for i in count:
		var a := TAU * float(i) / count
		var p := Vector3(cos(a), 0, sin(a)) * WALL_R
		var yaw := -a + PI * 0.5                     # หน้ากำแพงหันเข้าหาศูนย์กลาง
		var gate := i == 0
		_reg(_piece("wall-gate" if gate else "wall", p, yaw, Vector3(1.05, 0.8, 1.0)), 1.7)
		if i % 5 == 2 and not gate:
			_reg(_piece("banner", p + Vector3(-cos(a), 0, -sin(a)) * 0.2 + Vector3.UP * 0.55, yaw, Vector3(1.0, 1.0, 1.0)), 2.6)
	for i in 10:                                       # เสาคั่นกำแพง
		var a := TAU * (float(i) + 0.5) / 10.0
		var p := Vector3(cos(a), 0, sin(a)) * (WALL_R + 0.1)
		_reg(_piece("column" if i % 3 != 1 else "column-damaged", p, -a, Vector3(1.0, 1.9 if i % 3 != 1 else 1.7, 1.0)), 3.8)


func _props() -> void:
	for k in 4:                                        # รูปปั้นนอกกำแพง
		var a := TAU * (float(k) + 0.5) / 4.0 + PI * 0.25
		_reg(_piece("statue", Vector3(cos(a), 0, sin(a)) * (WALL_R + 2.6), -a - PI * 0.5, Vector3(1.8, 1.8, 1.8)), 5.0)
	_piece("trophy", Vector3(-4.0, 0, -5.0) , 0.6, Vector3(1.0, 1.0, 1.0))
	_piece("weapon-rack", Vector3(5.6, 0, -4.9), -0.8)
	_piece("weapon-rack", Vector3(-5.8, 0, 4.7), 2.4)
	_piece("bricks", Vector3(6.4, 0, 3.6), 0.3)
	_piece("bricks", Vector3(-6.6, 0, -2.4), 1.1)
	# อัฒจันทร์ขั้นบันไดรอบนอก (ครึ่งหลังเท่านั้น กล้องอยู่ฝั่งหน้า)
	for i in 14:
		var a := PI * 1.05 + PI * 0.9 * float(i) / 13.0
		var p := Vector3(cos(a), 0, sin(a))
		_reg(_piece("block", p * (WALL_R + 1.7) + Vector3.UP * 0.0, -a, Vector3(1.0, 1.6, 1.6)), 1.7)
		_reg(_piece("block", p * (WALL_R + 3.1), -a, Vector3(1.0, 3.2, 1.6)), 3.3)


func _outside() -> void:
	# พื้นดินด้านนอก ไม่ให้เห็นความว่างเปล่านอกลาน
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 60.0
	cm.bottom_radius = 60.0
	cm.height = 0.6
	cm.radial_segments = 32
	cm.rings = 1
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.52, 0.38)
	m.roughness = 1.0
	mi.material_override = m
	mi.position = Vector3(0, -0.32, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
