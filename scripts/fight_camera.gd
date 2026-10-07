extends Camera3D
## กล้องรวมสำหรับเล่น 2 คนจอเดียว: มองจากด้านข้างของแนวที่ผู้เล่นทั้งสองยืน
## ซูมออกเมื่อยืนห่างกัน / ลอยสูง, ซูมเข้าเมื่อประชิด, ไม่สลับฝั่งเองตอนตัวละครกระโดดข้ามกัน
## ตัวละครสั่งกล้องสั่นผ่าน shake และขยายมุมกล้องชั่วขณะผ่าน fov_kick()

@export var base_fov := 48.0
@export var min_distance := 5.2        ## ระยะกล้องตอนยืนประชิด
@export var max_distance := 17.0
@export var distance_per_meter := 0.9  ## ยิ่งห่างกันกล้องยิ่งถอย
@export var height := 1.9              ## ความสูงกล้องเหนือจุดกึ่งกลาง
@export var look_height := 1.05
@export var follow_speed := 4.0

var shake := 0.0
var _fov_extra := 0.0
var _line := Vector3.RIGHT             # ทิศจาก P1 ไป P2 ล่าสุด
var _side := 1.0                        # กล้องอยู่ฝั่งไหนของแนวเส้น
var _look := Vector3.ZERO
var _started := false


func _ready() -> void:
	add_to_group("fight_camera")
	fov = base_fov
	current = true


func fov_kick(amount: float) -> void:
	_fov_extra = maxf(_fov_extra, amount)


func _pair() -> Array:
	var a = get_tree().get_first_node_in_group("p1")
	var b = get_tree().get_first_node_in_group("p2")
	if a == null or b == null:
		return []
	return [a, b]


## ตำแหน่ง/จุดมองที่ต้องการในเฟรมนี้
func _target() -> Array:
	var pr := _pair()
	if pr.is_empty():
		return []
	var a: Vector3 = pr[0].global_position
	var b: Vector3 = pr[1].global_position
	var d := b - a
	d.y = 0.0
	var sep := d.length()
	if sep > 0.4:
		var nl := d / sep
		# ตัวละครข้ามกัน -> แนวเส้นกลับทิศ แต่กล้องยังอยู่ฝั่งเดิม
		_line = nl
	var perp := _line.cross(Vector3.UP).normalized()
	if _started:
		var rel := global_position - (a + b) * 0.5
		rel.y = 0.0
		_side = 1.0 if rel.dot(perp) >= 0.0 else -1.0
	var mid := (a + b) * 0.5
	var dy := absf(a.y - b.y)
	var dist := clampf(min_distance + sep * distance_per_meter + dy * 0.8, min_distance, max_distance)
	var pos := mid + perp * _side * dist + Vector3.UP * (height + sep * 0.07 + dy * 0.25)
	var look := mid + Vector3.UP * look_height
	return [pos, look]


func _process(delta: float) -> void:
	# เวลาจริง (ไม่ช้าลงตอน hit-stop)
	var rd := delta / maxf(Engine.time_scale, 0.001)
	rd = minf(rd, 0.1)
	var tg := _target()
	if not tg.is_empty():
		if not _started:
			_started = true
			global_position = tg[0]
			_look = tg[1]
		else:
			var k := 1.0 - exp(-follow_speed * rd)
			global_position = global_position.lerp(tg[0], k)
			_look = _look.lerp(tg[1], 1.0 - exp(-follow_speed * 1.5 * rd))
		if global_position.distance_to(_look) > 0.1:
			look_at(_look, Vector3.UP)
	# กล้องสั่น
	if shake > 0.0:
		var s2 := shake * shake
		h_offset = randf_range(-1.0, 1.0) * 0.4 * s2
		v_offset = randf_range(-1.0, 1.0) * 0.4 * s2
		shake = move_toward(shake, 0.0, rd * 2.2)
	else:
		h_offset = 0.0
		v_offset = 0.0
	_fov_extra = move_toward(_fov_extra, 0.0, rd * 30.0)
	fov = lerpf(fov, base_fov + _fov_extra, clampf(rd * 8.0, 0.0, 1.0))
