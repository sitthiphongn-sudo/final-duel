extends Node
## อัลติเมต "Inferno Rush" — คัทซีนสดในเกม (~12 วินาที)
##   1) Intro     : เกมค้าง ศัตรูหยุดนิ่ง ผู้เล่นเดินช้าๆ เข้าหา กล้องแพนจากหาง ไล่ขึ้นหลัง ถึงหัว (มุมข้ามไหล่)
##   2) Charge    : ซูมเข้าดวงตาใกล้สุด กล้องสั่นแรงขึ้นเรื่อยๆ -> คำราม กล้องกระชากออก จอวาบ
##   3) Dash      : พุ่งเข้าหาทิ้งหางไฟ
##   4) Warp Rush : วาร์ปไปต่อยรอบตัวศัตรู หน้า-ข้าง-หลัง-ข้าง... ตัดกล้องทุกครั้ง มีไฟระเบิดตรงจุดวาร์ปและจุดโดน
##   5) Wind-up   : กลับมาด้านหน้า ย่อลึก ง้างหมัดขวาต่ำระดับเข่านานๆ ตัวสั่นเกร็ง ไฟลุกโหม กล้องมุมต่ำ
##   6) Strike    : ดันตัวขึ้นเสยหมัดจากด้านล่างขึ้นฟ้า -> hit-stop ยาว + จอขาว + ระเบิดไฟพุ่งขึ้น
##   7) Launch    : ภาพช้า ศัตรูลอยสูง ตกกระแทกพื้นแล้วล้มหงาย -> กล้องกลับหลังผู้เล่น

const HandFire := preload("res://scripts/hand_fire.gd")
const FLIPBOOK := preload("res://vfx/fire_flipbook_8x8.png")
const FLIPBOOK_ICE := preload("res://vfx/fire_flipbook_blue_8x8.png")
var ice := false          # ตัวละครธาตุน้ำแข็ง -> ไฟ/แสงในคัทซีนเป็นสีฟ้า
const SND := {
	"charge": preload("res://sounds/ult_charge.wav"),
	"dash": preload("res://sounds/ult_dash.wav"),
	"boom": preload("res://sounds/ult_boom.wav"),
	"hit": preload("res://sounds/hit_light.wav"),
	"hit_heavy": preload("res://sounds/hit_heavy.wav"),
}

@export var max_range := 7.0            ## ต้องอยู่ใกล้ศัตรูไม่เกินนี้ถึงจะกดได้
@export var intro_start_dist := 6.5     ## ตอนเริ่มฉาก ผู้เล่นอยู่ห่างศัตรูเท่านี้
@export var intro_stop_dist := 4.3      ## เดินเข้ามาหยุดห่างศัตรูเท่านี้
@export var air_punch_angle := 45.0     ## องศาที่เอียงตัวทิ่มหมัดลงตอนต่อยจากกลางอากาศ
@export var eye_height := 0.13          ## ตำแหน่งตาเหนือกระดูกหัว (ใช้ตอนซูมตา)
@export var eye_forward := 0.12         ## ตาอยู่หน้ากระดูกหัวเท่าไร

var player
var enemy
var cam: Camera3D
var active := false

# ---- UI ----
var ui: CanvasLayer
var bar_top: ColorRect
var bar_bot: ColorRect
var dim_rect: ColorRect
var flash_rect: ColorRect
var letterbox := 0.0     # 0..1
var dim := 0.0
var flash := 0.0
var flash_color := Color.WHITE

# ---- กล้อง ----
var cam_shake := 0.0
var shake_amp := 0.12
var track_target: Node3D = null
var fwd := Vector3.FORWARD
var right := Vector3.RIGHT
var charging := false
var aura: Node3D


func setup(p) -> void:
	player = p
	ice = "char_data" in p and p.char_data.get("element", "fire") == "ice"
	cam = Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	_build_ui()


func can_start() -> bool:
	var e := _find_enemy()
	return e != null and player.global_position.distance_to(e.global_position) <= max_range


# ======================================================================
var cam_fn: Callable            # ถ้าตั้งไว้ จะคำนวณตำแหน่งกล้องทุกเฟรม (ช็อตที่ตามตัวละคร)
var shot_t := 0.0               # 0..1 ความคืบหน้าของช็อตที่ขยับ

func start() -> void:
	if active:
		return
	enemy = _find_enemy()
	if enemy == null:
		return
	active = true
	player.in_ult = true
	player.action = ""
	player.velocity = Vector3.ZERO
	enemy.frozen = true
	enemy.block_time = 0.0
	enemy.is_blocking = false
	enemy.velocity = Vector3.ZERO
	enemy.anim_player.speed_scale = 0.0            # ศัตรูค้างท่า (เหมือนเวลาหยุด)
	_update_frame()
	player.model.rotation.y = atan2(fwd.x, fwd.z)
	enemy.model.rotation.y = atan2(-fwd.x, -fwd.z)
	cam.current = true
	_tw(self, "letterbox", 1.0, 0.25)
	_tw(self, "dim", 0.22, 0.25)
	_flash(_tc(Color(1.0, 0.75, 0.4)), 0.45, 0.35)
	_sfx(SND.hit_heavy, -4.0)

	# ---------- 1) Intro: เดินช้าๆ + กล้องแพนจากหางขึ้นถึงหัว ----------
	# ถอยผู้เล่นไปตั้งต้นไกลๆ (ซ่อนด้วยจอวาบ) แล้วเดินเข้ามาหยุดห่างศัตรูพอดี
	var e0: Vector3 = enemy.global_position
	var start_walk: Vector3 = e0 - fwd * intro_start_dist
	start_walk.y = player.global_position.y
	player.global_position = start_walk
	var walk_target: Vector3 = e0 - fwd * intro_stop_dist
	walk_target.y = start_walk.y
	player._play(player.walk_anim, 0.2, 0.55)
	if player.voice:
		player.voice.say("walk", 0.6)      # 「燃え尽きろ！」 ระหว่างเดินเข้าหา
	_tw(player, "global_position", walk_target, 2.8, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
	shot_t = 0.0
	_tw(self, "shot_t", 1.0, 2.8, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
	cam.fov = 50.0
	cam_fn = func() -> Transform3D:
		var pp: Vector3 = player.global_position
		var head: Vector3 = _bone_pos(player, "Head")
		var tail := pp - fwd * 0.75 + Vector3.UP * 0.35          # ปลายหาง (ต่ำ ด้านหลัง)
		var k := shot_t
		# ตำแหน่งกล้อง: ต่ำหลังหาง -> ไล่ขึ้นตามแผ่นหลัง -> ข้ามไหล่ขวามองศัตรู
		var p_a := tail - fwd * 0.7 + right * 0.35 + Vector3.DOWN * 0.15
		var p_b := pp - fwd * 1.1 + right * 0.55 + Vector3.UP * 1.0
		var p_c := head - fwd * 0.95 + right * 0.45 + Vector3.UP * 0.2
		var pos := _bez(p_a, p_b, p_c, k)
		var look_a := tail
		var look_b := pp + Vector3.UP * 1.0
		var look_c: Vector3 = enemy.global_position + Vector3.UP * 1.3
		var look := _bez(look_a, look_b, look_c, k)
		return Transform3D(Basis(), pos).looking_at(look, Vector3.UP)
	await _wait(2.9)
	cam_fn = Callable()

	# ---------- 2) Charge: ซูมเข้าที่ดวงตา กล้องสั่นหนักขึ้นเรื่อยๆ ----------
	player._play("UltCharge", 0.1, 1.0, true)
	_sfx(SND.charge, 2.0)
	charging = true
	_tw(self, "dim", 0.35, 0.3)
	shot_t = 0.0
	_tw(self, "shot_t", 1.0, 1.1, Tween.EASE_IN, Tween.TRANS_QUAD)
	cam.fov = 36.0
	shake_amp = 0.035                                   # กล้องอยู่ใกล้มาก สั่นเป็นระยะน้อยก็พอ
	_tw(cam, "fov", 27.0, 0.75, Tween.EASE_IN)
	cam_fn = func() -> Transform3D:
		var eye := _eye_pos(player)
		var cam_d := lerpf(1.15, 0.8, shot_t)                   # ดันกล้องเข้าหาตา
		var pos := eye + fwd * cam_d + right * 0.06 + Vector3.DOWN * 0.03
		return Transform3D(Basis(), pos).looking_at(eye, Vector3.UP)
	var t_roar := Time.get_ticks_msec() + 750
	while Time.get_ticks_msec() < t_roar:
		# สั่นแรงขึ้นเรื่อยๆ ตามพลังที่รวม
		cam_shake = maxf(cam_shake, lerpf(0.25, 0.7, shot_t))
		await get_tree().process_frame
	# คำราม: กล้องกระชากถอยออก + สั่นแรง + จอวาบ
	cam_shake = 1.1
	_flash(_tc(Color(1.0, 0.8, 0.5)), 0.5, 0.2)
	_tw(cam, "fov", 48.0, 0.25, Tween.EASE_OUT, Tween.TRANS_EXPO)
	await _wait(0.4)
	cam_fn = Callable()
	shake_amp = 0.12
	_flash(Color.WHITE, 0.8, 0.18)
	charging = false

	# ---------- 3) Dash ----------
	var start_pos: Vector3 = player.global_position
	var target: Vector3 = enemy.global_position - fwd * 1.0
	target.y = start_pos.y
	var mid := (start_pos + target) * 0.5
	cam.fov = 62.0
	cam.global_transform = _pose(mid, Vector3(2.8, 0.4, -0.6), mid + Vector3.UP * 0.9)
	_tw(cam, "global_transform", _pose(mid, Vector3(2.4, 0.5, 0.6), target + Vector3.UP * 1.0), 0.4)
	player._play("DashF", 0.02, 1.3, true)
	_sfx(SND.dash, 0.0)
	_tw(player, "global_position", target, 0.28, Tween.EASE_OUT)
	await _wait(0.32)
	enemy.anim_player.speed_scale = 1.0

	# ---------- 4) Warp Rush: วาร์ปต่อยรอบตัว สลับพื้น/กลางอากาศ (อากาศ = ทิ่มหมัดลง 45° แบบ Dragon Ball) ----------
	var ep: Vector3 = enemy.global_position
	var ground_y: float = player.global_position.y
	# [ทิศที่ผู้เล่นไปอยู่ (เทียบศัตรู), ลอยหรือไม่]
	var spots := [
		[-fwd, false], [right, true], [fwd, true], [-right, false],
		[(fwd + right).normalized(), true], [(-fwd - right).normalized(), false],
		[(fwd - right).normalized(), true], [(-fwd + right).normalized(), true],
	]
	var tilt := deg_to_rad(air_punch_angle)
	for i in spots.size():
		var d: Vector3 = spots[i][0]
		var air: bool = spots[i][1]
		var old: Vector3 = player.global_position
		if i > 0:
			_burst(old + Vector3.UP * 1.0, 0.8)                 # ไฟตรงจุดที่หายไป
			_sfx(SND.dash, -6.0, randf_range(1.2, 1.5))
			_flash(_tc(Color(1.0, 0.6, 0.3)), 0.25, 0.1)
		var yaw := atan2(-d.x, -d.z)                            # หันหน้าหาศัตรู
		var np: Vector3
		var hit_pt: Vector3
		if air:
			# ลอยเหนือศัตรูด้านข้าง/หลัง เอียงตัวลง ให้หมัดทิ่มลงเฉียงไปที่หัว-ไหล่
			var hip := ep + d * 0.85 + Vector3.UP * 1.65
			var face := -d
			np = hip - (face * sin(tilt) + Vector3.UP * cos(tilt)) * 0.73   # หมุนรอบเท้า -> ชดเชยให้สะโพกอยู่ที่ hip
			player.model.rotation = Vector3(tilt, yaw, 0.0)
			hit_pt = ep + d * 0.15 + Vector3.UP * 1.5
		else:
			np = ep + d * 0.95
			np.y = ground_y
			player.model.rotation = Vector3(0.0, yaw, 0.0)
			hit_pt = ep + d * 0.25 + Vector3.UP * 1.25
		player.global_position = np
		_burst(np + (Vector3.UP * 1.0 if not air else Vector3.ZERO) + (hit_pt - np) * (0.4 if air else 0.0), 0.6)
		# กล้อง: มองจากด้านข้างของแนวต่อย สลับซ้าย/ขวา (ช็อตกลางอากาศยกกล้องสูงขึ้น)
		var side_dir: Vector3 = d.cross(Vector3.UP).normalized() * (1.0 if i % 2 == 0 else -1.0)
		var cpos: Vector3
		var look: Vector3
		if air:
			cpos = ep + side_dir * 3.0 + d * 0.4 + Vector3.UP * 1.5
			look = ep + d * 0.5 + Vector3.UP * 1.7
		else:
			cpos = ep + side_dir * 2.6 + d * 0.3 + Vector3.UP * 0.9
			look = ep + d * 0.45 + Vector3.UP * 1.15
		cam.fov = 58.0
		cam.global_transform = Transform3D(Basis(), cpos).looking_at(look, Vector3.UP)
		var a := ("AirPunch" if air else "Punch") + ("1" if i % 2 == 0 else "2")
		player._play(a, 0.02, 1.6, true)
		(player.fire_l if i % 2 == 0 else player.fire_r).boost(1.8)
		await _wait(0.26 * 0.3 / 1.6)
		_rush_hit(i, -d, hit_pt)
		await _wait(0.16)
	player.model.rotation = Vector3(0.0, player.model.rotation.y, 0.0)

	# ---------- 5) Wind-up: ง้างหมัดนานๆ ----------
	var front := ep - fwd * 1.05
	front.y = ground_y
	_burst(player.global_position + Vector3.UP, 0.8)
	player.global_position = front
	player.model.rotation.y = atan2(fwd.x, fwd.z)
	_burst(front + Vector3.UP, 0.8)
	enemy.model.rotation.y = atan2(-fwd.x, -fwd.z)
	enemy.anim_player.play("Hit", 0.1)
	player._play("UltWindup", 0.08, 1.0, true)
	_sfx(SND.charge, 0.0)
	# มุมต่ำด้านหน้าขวา มองขึ้น เห็นหมัดที่ง้างต่ำอยู่ระดับเข่า -> ค่อยๆ ดันเข้าและลดต่ำลง
	var fist_low := front + right * 0.35 + fwd * 0.1 + Vector3.UP * 0.55
	cam.fov = 58.0
	cam.global_transform = Transform3D(Basis(), front + fwd * 1.4 + right * 1.5 + Vector3.UP * 0.5).looking_at(front + Vector3.UP * 0.9, Vector3.UP)
	_tw(cam, "global_transform", Transform3D(Basis(), front + fwd * 0.9 + right * 1.0 + Vector3.UP * 0.2).looking_at(fist_low.lerp(front + Vector3.UP * 1.3, 0.45), Vector3.UP), 1.5, Tween.EASE_IN_OUT)
	_tw(cam, "fov", 50.0, 1.5)
	_tw(self, "dim", 0.45, 1.5)
	var t_end := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < t_end:
		player.fire_r.boost(4.0)
		cam_shake = maxf(cam_shake, 0.15)
		await get_tree().process_frame

	# ---------- 6) Strike: เสยขึ้นจากด้านล่าง ----------
	_tw(self, "dim", 0.2, 0.2)
	cam.fov = 66.0
	var mid2: Vector3 = (front + ep) * 0.5
	var low := mid2 + right * 2.3 - fwd * 0.3
	low.y = front.y + 0.2
	cam.global_transform = Transform3D(Basis(), low).looking_at(mid2 + Vector3.UP * 1.3, Vector3.UP)
	_tw(cam, "global_transform", Transform3D(Basis(), low + Vector3.DOWN * 0.05).looking_at(mid2 + Vector3.UP * 2.3, Vector3.UP), 0.6)
	if player.voice:
		player.voice.say("ult")      # 「これで終わりだ！」
	player._play("UltStrike", 0.02, 1.0, true)
	_sfx(SND.dash, 0.0, 0.8)
	await _wait(0.5 * 0.28)
	_finisher_hit()
	await _wait(0.4)                                   # hit-stop (เวลาจริง ขณะเกมเกือบหยุด)

	# ---------- 7) Launch + ล้ม ----------
	Engine.time_scale = 0.35
	enemy.frozen = false
	enemy.knockdown_pending = true
	enemy.knockback = fwd * 6.0                        # เสยขึ้น: ลอยสูง ถอยไปหลังนิดหน่อย
	enemy.velocity.y = 10.5
	var wide := mid2 + right * 5.5 + fwd * 2.5 + Vector3.UP * 1.6
	cam.fov = 60.0
	cam.global_transform = Transform3D(Basis(), wide).looking_at(enemy.global_position + Vector3.UP, Vector3.UP)
	track_target = enemy
	await _wait(1.3)
	Engine.time_scale = 1.0
	await _wait(1.3)                                    # ดูศัตรูล้มหงายกระแทกพื้น
	track_target = null

	# ---------- กลับเข้าเกม ----------
	var back: Transform3D = player.camera.global_transform
	_tw(cam, "global_transform", back, 0.6, Tween.EASE_IN_OUT)
	_tw(cam, "fov", player.camera.fov, 0.6)
	_tw(self, "letterbox", 0.0, 0.45)
	_tw(self, "dim", 0.0, 0.35)
	await _wait(0.6)
	player.camera.current = true
	player.in_ult = false
	active = false


## สลับโทนสีไฟส้ม -> ฟ้า สำหรับตัวละครธาตุน้ำแข็ง
func _tc(c: Color) -> Color:
	return Color(c.b, c.g, c.r, c.a) if ice else c


## เส้นโค้ง Bezier 3 จุด (ให้กล้องเคลื่อนนุ่มนวล)
func _bez(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


# ---------- จังหวะโดน ----------

func _rush_hit(i: int, dir: Vector3, at: Vector3) -> void:
	enemy.take_hit(dir, false, 16.0)                 # หมัดรัวในคัทซีน
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.add_combo()
	enemy.velocity = Vector3.ZERO
	enemy.knockback = Vector3.ZERO
	cam_shake = maxf(cam_shake, 0.35)
	_burst(at, 0.7)
	# hit-stop สั้นๆ ทุกหมัด
	Engine.time_scale = 0.05
	get_tree().create_timer(0.045, true, false, true).timeout.connect(func():
		if active and Engine.time_scale < 0.1:
			Engine.time_scale = 1.0)


func _finisher_hit() -> void:
	Engine.time_scale = 0.02
	enemy.take_hit(fwd, true, 90.0)                  # หมัดปิดท้าย
	enemy.velocity = Vector3.ZERO
	enemy.knockback = Vector3.ZERO
	_sfx(SND.boom, 3.0)
	_flash(Color.WHITE, 1.0, 0.35)
	cam_shake = 1.3
	var pos: Vector3 = enemy.global_position + Vector3.UP * 1.3 - fwd * 0.2
	_burst(pos, 2.4)
	_burst(pos + Vector3.UP * 0.8 + fwd * 0.3, 1.8)
	_burst(pos + Vector3.UP * 1.7 + fwd * 0.5, 1.2)     # ไฟพุ่งขึ้นตามแนวหมัดเสย
	var l := OmniLight3D.new()
	l.light_color = _tc(Color(1.0, 0.55, 0.2))
	l.light_energy = 10.0
	l.omni_range = 9.0
	get_tree().current_scene.add_child(l)
	l.global_position = pos
	var tw := l.create_tween().set_ignore_time_scale(true)
	tw.tween_property(l, "light_energy", 0.0, 0.9)
	tw.tween_callback(l.queue_free)


## ระเบิดไฟ: เปลวไฟ flipbook กระจายออกทุกทิศแล้วลอยขึ้น
func _burst(pos: Vector3, power: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = int(18 * power) + 6
	p.lifetime = 0.55 + 0.15 * power
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.08 * power
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.0 * power
	p.initial_velocity_max = 3.2 * power
	p.damping_min = 4.0
	p.damping_max = 7.0
	p.gravity = Vector3(0, 1.5, 0)
	p.angle_min = -30.0
	p.angle_max = 30.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.4))
	c.add_point(Vector2(0.15, 1.0))
	c.add_point(Vector2(1.0, 0.5))
	p.scale_amount_curve = c
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.6, 1.0])
	g.colors = PackedColorArray([_tc(Color(1, 1, 0.9, 1)), _tc(Color(1, 0.8, 0.5, 1)), _tc(Color(1, 0.5, 0.25, 0.6)), _tc(Color(0.3, 0.1, 0.05, 0))])
	p.color_ramp = g
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.35, 0.45) * power
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = FLIPBOOK_ICE if ice else FLIPBOOK
	m.particles_anim_h_frames = 8
	m.particles_anim_v_frames = 8
	m.particles_anim_loop = false
	mesh.material = m
	p.mesh = mesh
	p.anim_speed_min = 1.0
	p.anim_speed_max = 1.0
	p.anim_offset_max = 0.3
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	p.position = pos                 # ตั้งตำแหน่งก่อนเข้า scene ไม่ให้ไฟพ่นที่จุดกำเนิดโลก
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.restart()
	get_tree().create_timer(2.5, true, false, true).timeout.connect(p.queue_free)


# ---------- ทุกเฟรม ----------

func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	if charging and player.fire_l:
		player.fire_l.boost(3.0)
		player.fire_r.boost(3.0)
	if active and cam_fn.is_valid():
		cam.global_transform = cam_fn.call()
	if active and track_target and is_instance_valid(track_target):
		var tgt: Vector3 = track_target.global_position + Vector3.UP
		var xf := cam.global_transform
		if xf.origin.distance_to(tgt) > 0.1:
			cam.global_transform = xf.looking_at(tgt, Vector3.UP)
	if cam_shake > 0.0:
		var s2 := cam_shake * cam_shake
		cam.h_offset = randf_range(-1, 1) * shake_amp * s2
		cam.v_offset = randf_range(-1, 1) * shake_amp * s2
		cam_shake = move_toward(cam_shake, 0.0, real_delta * 2.5)
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	_update_ui()


# ---------- ตัวช่วย ----------

## ตำแหน่งดวงตาโดยประมาณ: เหนือกระดูกหัว และยื่นไปทางหน้าของหัว
func _eye_pos(ch) -> Vector3:
	var sk: Skeleton3D = ch.rig._skel
	var hp: Transform3D = sk.global_transform * sk.get_bone_global_pose(ch.rig.B["Head"])
	var face_fwd: Vector3 = ch.model.global_basis.z.normalized()
	return hp.origin + hp.basis.y.normalized() * eye_height + face_fwd * eye_forward


## ตำแหน่งกระดูก (โลก) ของตัวละคร เช่น "Head"
func _bone_pos(ch, bone: String) -> Vector3:
	var sk: Skeleton3D = ch.rig._skel
	return sk.global_transform * sk.get_bone_global_pose(ch.rig.B[bone]).origin


func _find_enemy() -> Node3D:
	return get_tree().get_first_node_in_group("enemy") as Node3D


func _update_frame() -> void:
	var to: Vector3 = enemy.global_position - player.global_position
	to.y = 0
	fwd = to.normalized() if to.length() > 0.01 else Vector3.FORWARD
	right = fwd.cross(Vector3.UP).normalized()


## ตำแหน่งกล้องในกรอบของผู้เล่น: local = (ขวา, สูง, หน้า) มองไปที่ look
func _pose(origin: Vector3, local: Vector3, look: Vector3) -> Transform3D:
	var pos := origin + right * local.x + Vector3.UP * local.y + fwd * local.z
	return Transform3D(Basis(), pos).looking_at(look, Vector3.UP)


func _tw(obj: Object, prop: String, value, dur: float, ease := Tween.EASE_OUT, trans := Tween.TRANS_CUBIC) -> void:
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(obj, prop, value, dur).set_trans(trans).set_ease(ease)


func _wait(sec: float, _real := true) -> Signal:
	return get_tree().create_timer(sec, true, false, true).timeout


func _flash(col: Color, strength: float, dur: float) -> void:
	flash_color = col
	flash = strength
	_tw(self, "flash", 0.0, dur)


func _sfx(stream: AudioStream, vol := 0.0, pitch := 1.0) -> void:
	var a := AudioStreamPlayer.new()
	a.bus = "SFX"
	a.stream = stream
	a.volume_db = vol
	a.pitch_scale = pitch
	add_child(a)
	a.finished.connect(a.queue_free)
	a.play()


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	dim_rect = ColorRect.new()
	dim_rect.color = Color(0, 0, 0, 0)
	dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(dim_rect)
	bar_top = ColorRect.new()
	bar_top.color = Color.BLACK
	ui.add_child(bar_top)
	bar_bot = ColorRect.new()
	bar_bot.color = Color.BLACK
	ui.add_child(bar_bot)
	flash_rect = ColorRect.new()
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash_rect)
	for c in [dim_rect, bar_top, bar_bot, flash_rect]:
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _update_ui() -> void:
	var vs := get_viewport().get_visible_rect().size
	var bh := vs.y * 0.12 * letterbox
	bar_top.position = Vector2.ZERO
	bar_top.size = Vector2(vs.x, bh)
	bar_bot.position = Vector2(0, vs.y - bh)
	bar_bot.size = Vector2(vs.x, bh)
	dim_rect.position = Vector2.ZERO
	dim_rect.size = vs
	dim_rect.color = Color(0.05, 0.0, 0.0, dim)
	flash_rect.position = Vector2.ZERO
	flash_rect.size = vs
	flash_rect.color = Color(flash_color.r, flash_color.g, flash_color.b, flash)
