extends Camera3D
## กล้องรวมสำหรับเล่น 2 คนจอเดียว: มองจากด้านข้างของแนวที่ผู้เล่นทั้งสองยืน
## ซูมออกเมื่อยืนห่างกัน / ลอยสูง, ซูมเข้าเมื่อประชิด, ไม่สลับฝั่งเองตอนตัวละครกระโดดข้ามกัน
## ตัวละครสั่งกล้องสั่นผ่าน shake และขยายมุมกล้องชั่วขณะผ่าน fov_kick()

@export var base_fov := 48.0
@export var min_distance := 5.2        ## ระยะกล้องตอนยืนประชิด
@export var max_distance := 14.0
@export var distance_per_meter := 0.9  ## ยิ่งห่างกันกล้องยิ่งถอย
@export var height := 1.9              ## ความสูงกล้องเหนือจุดกึ่งกลาง
@export var look_height := 1.05
@export var follow_speed := 4.0
@export var avoid_obstacles := true    ## หมุน/ดึงกล้องเข้ามาเมื่อเสาหรือหินบังตัวละคร
@export var max_fov := 78.0
@export var camera_limit := 12.5       ## กล้องอยู่ในรัศมีนี้จากกลางแมพ (ด้านนอกมีเสา/ซากหิน)

const MAP_MASK := 1                    # เลเยอร์ของ collision แมพ
const YAW_STEPS := [0.0, 14.0, -14.0, 28.0, -28.0, 42.0, -42.0, 56.0, -56.0]

var shake := 0.0
var _fov_extra := 0.0
var _line := Vector3.RIGHT             # ทิศจาก P1 ไป P2 ล่าสุด
var _side := 1.0                        # กล้องอยู่ฝั่งไหนของแนวเส้น
var _look := Vector3.ZERO
var _started := false
var _yaw := 0.0                         # มุมหมุนหลบสิ่งกีดขวาง (องศา) ที่ใช้อยู่
var _yaw_goal := 0.0
var _fov_fit := 0.0                     # มุมกล้องที่ต้องใช้เมื่อถูกดึงเข้ามาใกล้


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
	var h := height + sep * 0.07 + dy * 0.25
	var look := mid + Vector3.UP * look_height
	# จุดที่ต้องมองเห็น: ตลอดแนวระหว่างสองคน ทั้งระดับเท้าและระดับหัว (เสาจะได้ไม่ขวางกลางจอ)
	var eyes: Array = [look]
	for t in [0.0, 0.33, 0.67, 1.0]:
		var p: Vector3 = a.lerp(b, t)
		eyes.append(p + Vector3.UP * 0.35)
		eyes.append(p + Vector3.UP * 1.6)
	var out := perp * _side
	if avoid_obstacles and _started:
		# 1) หามุมใกล้มุมเดิมที่สุดที่ไม่มีอะไรบัง และกล้องยังอยู่ในลานโล่ง
		if _clear(eyes, _cam_pos(mid, out, 0.0, dist, h)):
			_yaw_goal = 0.0
		elif not _clear(eyes, _cam_pos(mid, out, _yaw_goal, dist, h)):
			var found := false
			for y in YAW_STEPS:
				if _clear(eyes, _cam_pos(mid, out, y, dist, h)):
					_yaw_goal = y
					found = true
					break
			if not found:
				_yaw_goal = 0.0
	var pos := _cam_pos(mid, out, _yaw, dist, h)
	# 2) ยังโดนบัง/ออกนอกลาน -> ดึงกล้องเข้ามา ยกสูงขึ้น และขยายมุมกล้องให้ยังเห็นครบสองคน
	if avoid_obstacles and _started:
		var dir := out.rotated(Vector3.UP, deg_to_rad(_yaw))
		var dmin := minf(dist, _dist_to_limit(mid, dir))
		for e in eyes:
			var hit := _ray(e, pos)
			if not hit.is_empty():
				var rel: Vector3 = hit.position - mid
				dmin = minf(dmin, rel.x * dir.x + rel.z * dir.z - 0.6)
		if dmin < dist:
			var d2 := maxf(2.8, dmin)
			var h2 := h + (dist - d2) * 0.3
			pos = _cam_pos(mid, out, _yaw, d2, h2)
	return [pos, look]


## มุมกล้อง (แนวตั้ง) ที่ต้องใช้เพื่อให้เห็นตัวละครทั้งสองครบทั้งตัว จากตำแหน่งกล้องตอนนี้
func _fit_fov() -> float:
	var pr := _pair()
	if pr.is_empty():
		return 0.0
	var inv := global_transform.affine_inverse()
	var aspect := maxf(get_viewport().get_visible_rect().size.aspect(), 0.5)
	var need := 0.0
	for f in pr:
		for hgt in [0.1, 1.9]:
			var lp: Vector3 = inv * ((f as Node3D).global_position + Vector3.UP * hgt)
			var z := -lp.z
			if z < 0.8:
				continue
			var tx := (absf(lp.x) / z) * 1.18 / aspect    # เผื่อขอบซ้ายขวา
			var ty := (absf(lp.y) / z) * 1.12
			need = maxf(need, maxf(tx, ty))
	return rad_to_deg(2.0 * atan(need))


func _cam_pos(mid: Vector3, out: Vector3, yaw_deg: float, dist: float, h: float) -> Vector3:
	return mid + out.rotated(Vector3.UP, deg_to_rad(yaw_deg)) * dist + Vector3.UP * h


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, MAP_MASK)
	return get_world_3d().direct_space_state.intersect_ray(q)


## ระยะจาก mid ตามทิศ dir จนถึงขอบเขตที่กล้องอยู่ได้ (วงกลมรัศมี camera_limit)
func _dist_to_limit(mid: Vector3, dir: Vector3) -> float:
	var m := Vector2(mid.x, mid.z)
	var o := Vector2(dir.x, dir.z).normalized()
	var mo := m.dot(o)
	var disc := mo * mo - m.length_squared() + camera_limit * camera_limit
	if disc < 0.0:
		return 0.0
	return -mo + sqrt(disc)


func _clear(eyes: Array, pos: Vector3) -> bool:
	if Vector2(pos.x, pos.z).length() > camera_limit:
		return false
	for e in eyes:
		if not _ray(e, pos).is_empty():
			return false
	return true


func _process(delta: float) -> void:
	# เวลาจริง (ไม่ช้าลงตอน hit-stop)
	var rd := delta / maxf(Engine.time_scale, 0.001)
	rd = minf(rd, 0.1)
	_yaw = lerpf(_yaw, _yaw_goal, 1.0 - exp(-3.0 * rd))
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
		_fov_fit = _fit_fov()
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
	var want := clampf(maxf(base_fov, _fov_fit), base_fov, max_fov) + _fov_extra
	fov = lerpf(fov, want, clampf(rd * (10.0 if want > fov else 4.0), 0.0, 1.0))
