extends "res://scripts/ultimate.gd"
## อัลติเมต "Royal Decree" ของเป็ดราชา — คัทซีนสดในเกม (~11 วินาที)
##   1) Coronation : เกมค้าง กล้องวนรอบเป็ดจากมุมต่ำ มงกุฎเรืองทอง ปีกพลังงานกางออก พลังรวมตัว
##   2) Ascension  : เป็ดทะยานขึ้นฟ้า เสาแสงทองยกศัตรูลอย
##   3) Torpedo x3 : ทิ้งตัวท้องไถลแบบเพนกวิน พุ่งทะลุศัตรู 3 ทิศ (ตัดกล้องทุกครั้ง)
##   4) Crown Call : ลอยสูงเหนือศัตรู ปีกยักษ์ วงแหวนทองบนพื้นหดเข้า
##   5) Royal Stomp: ดิ่งทับศัตรูเต็มแรง พื้นแตก หินกระเด็น
##   6) Slide      : ศัตรูไถลไปตามพื้นพร้อมหิน/ฝุ่นจนชนขอบลาน

const Vfx := preload("res://scripts/vfx.gd")
const GroundImpact := preload("res://scripts/ground_impact.gd")
const BRAAM_SND := preload("res://sounds/ult_duck_braam.mp3")
const GOLD := Color(1.0, 0.82, 0.3)
const GOLD_SOFT := Color(1.0, 0.9, 0.55, 0.9)

var pillar: MeshInstance3D
var glow: OmniLight3D


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
	enemy.anim_player.speed_scale = 0.0
	_update_frame()
	player.model.rotation = Vector3(0.0, atan2(fwd.x, fwd.z), 0.0)
	enemy.model.rotation.y = atan2(-fwd.x, -fwd.z)
	cam.current = true
	_tw(self, "letterbox", 1.0, 0.25)
	_tw(self, "dim", 0.45, 0.25)
	_flash(GOLD, 0.5, 0.35)
	_sfx(SND.hit_heavy, -4.0)
	_sfx(BRAAM_SND, 0.0)

	var ground_y: float = player.global_position.y
	var ep: Vector3 = enemy.global_position
	var e_ground: float = ep.y
	var wl = player.fire_l
	var wr = player.fire_r

	# ---------- 1) Awakening: ปีกทองกางยักษ์ กล้องไต่ขึ้นจากเท้าถึงมงกุฎ ----------
	var p0: Vector3 = player.global_position
	glow = OmniLight3D.new()
	glow.light_color = GOLD
	glow.light_energy = 0.0
	glow.omni_range = 8.0
	_scene().add_child(glow)
	glow.global_position = p0 + Vector3.UP * 1.4
	_tw(glow, "light_energy", 7.0, 1.8, Tween.EASE_IN)
	player._play("UltCharge", 0.1, 0.85, true)
	_sfx(SND.charge, 2.0)
	charging = false
	shot_t = 0.0
	_tw(self, "shot_t", 1.0, 2.1, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
	cam.fov = 40.0
	cam_fn = func() -> Transform3D:
		var pp: Vector3 = player.global_position
		var dist := lerpf(2.2, 4.4, shot_t)
		var h := lerpf(0.15, 1.5, shot_t)
		var off := (fwd * 1.0 + right * lerpf(-1.2, 1.4, shot_t)).normalized() * dist
		return Transform3D(Basis(), pp + off + Vector3.UP * h).looking_at(pp + Vector3.UP * lerpf(0.5, 1.2, shot_t), Vector3.UP)
	if wl:
		await _wait(0.5)
		wl.regal_mode(true, 2.3, 1.0)
		wr.regal_mode(true, 2.3, 1.0)
	var t_end := Time.get_ticks_msec() + 1700
	var ring_t := 0.0
	while Time.get_ticks_msec() < t_end:
		cam_shake = maxf(cam_shake, lerpf(0.1, 0.5, shot_t))
		ring_t -= get_process_delta_time()
		if ring_t <= 0.0:
			ring_t = 0.24
			Vfx.ring(player, p0 + Vector3.UP * 0.05, Vector3.UP, Color(GOLD.r, GOLD.g, GOLD.b, 0.8), 4.0, 0.45, 0.5)
			Vfx.sparks(player, p0 + Vector3.UP * 0.4, GOLD, 10, 4.5)
			Vfx.sparks(player, p0 + Vector3.UP * 1.6, Color.WHITE, 4, 2.5)
		await get_tree().process_frame
	cam_fn = Callable()
	_flash(Color.WHITE, 0.9, 0.2)
	cam_shake = 1.2
	_sfx(SND.hit_heavy, 0.0, 0.8)

	# ---------- 2) Blink Barrage: วาปรอบศัตรู 8 จุด ปีกฟันทีละจุด ตัดกล้องรัว ----------
	enemy.anim_player.speed_scale = 1.0
	enemy.anim_player.play("Hit", 0.1)
	var epl: Vector3 = ep + Vector3.UP * 1.3
	_tw(enemy, "global_position", epl, 0.3, Tween.EASE_OUT, Tween.TRANS_QUAD)
	pillar = _make_pillar(ep)
	var base_ang := atan2(fwd.z, fwd.x) + PI
	var angs := [0.0, 2.4, 4.7, 1.2, 3.6, 5.5, 0.6, 3.0]
	var hs := [0.9, 2.0, 0.3, 2.4, 1.2, 0.2, 2.2, 1.0]
	for i in 8:
		var a := base_ang + float(angs[i])
		var d := Vector3(cos(a), 0.0, sin(a))
		var old: Vector3 = player.global_position
		var at := epl + d * 2.0 + Vector3.UP * (float(hs[i]) - 1.0)
		Vfx.ring(player, old + Vector3.UP, Vector3.UP, Color(GOLD.r, GOLD.g, GOLD.b, 0.9), 0.2, 1.6, 0.2)
		Vfx.speed_lines(player, old + Vector3.UP, at + Vector3.UP, Color(1, 1, 0.8, 0.9), 10, 0.5, 0.03, 0.2)
		player.global_position = at
		var look := epl - at
		player.model.rotation = Vector3(0.0, atan2(look.x, look.z), 0.0)
		player._play("AirPunch1" if i % 2 == 0 else "AirPunch2", 0.02, 1.8, true)
		_sfx(SND.dash, -3.0, randf_range(1.0, 1.35))
		# กล้อง: สลับมุม ใกล้ / ข้าง / ต่ำ / เหนือหัว
		var cdir := Vector3(cos(a + PI * 0.5), 0.0, sin(a + PI * 0.5))
		match i % 4:
			0: cam.global_transform = Transform3D(Basis(), epl + cdir * 3.2 + Vector3.UP * 0.5).looking_at(epl, Vector3.UP)
			1: cam.global_transform = Transform3D(Basis(), epl - d * 3.0 + Vector3.UP * 1.9).looking_at(epl, Vector3.UP)
			2: cam.global_transform = Transform3D(Basis(), epl - cdir * 2.6 + Vector3.UP * -0.9).looking_at(epl + Vector3.UP * 0.4, Vector3.UP)
			3: cam.global_transform = Transform3D(Basis(), epl + d * 3.6 + Vector3.UP * 0.8).looking_at(epl, Vector3.UP)
		cam.fov = 48.0 + 4.0 * float(i % 3)
		await _wait(0.1)
		# เส้นฟันทองตัดผ่านศัตรู
		var sd := (epl - at).normalized()
		var sw := sd.cross(Vector3.UP).normalized() * (1.0 if i % 2 == 0 else -1.0)
		Vfx.streak(player, epl - sw * 1.3 + Vector3.UP * 0.6, epl + sw * 1.3 - Vector3.UP * 0.4, GOLD, 0.55, 0.25, true)
		_gold_hit(epl, sd, 9.0 + i)
		if i == 7:
			_flash(Color.WHITE, 1.0, 0.15)
		await _wait(0.2 if i < 6 else 0.3)

	# ---------- 3) Uppercut: ปีกฟาดขึ้นฟ้า พาศัตรูพุ่งทะลุเมฆ ----------
	var top := ep + Vector3.UP * 5.6
	var hi := ep + Vector3.UP * 8.8 - fwd * 0.3
	player.global_position = epl - fwd * 0.9 + Vector3.DOWN * 0.8
	player.model.rotation = Vector3(0.0, atan2(fwd.x, fwd.z), 0.0)
	player._play("JumpUp", 0.03, 1.0, true)
	_sfx(SND.hit_heavy, 0.0, 1.1)
	_flash(GOLD, 0.7, 0.25)
	cam_shake = 1.0
	Vfx.ring(player, epl, Vector3.UP, Color(1, 1, 1, 0.9), 0.4, 5.0, 0.35)
	_tw(enemy, "global_position", top, 0.55, Tween.EASE_OUT, Tween.TRANS_QUAD)
	_tw(player, "global_position", top - fwd * 0.8 + Vector3.DOWN * 0.7, 0.5, Tween.EASE_OUT, Tween.TRANS_QUAD)
	_tw(glow, "global_position", top, 0.5)
	Vfx.streak(player, epl, top, GOLD, 1.2, 0.5, true)
	cam.fov = 60.0
	cam.global_transform = _pose(p0, Vector3(3.2, 0.3, -1.4), epl)
	_tw(cam, "global_transform", _pose(p0, Vector3(3.6, 3.0, -0.8), top), 0.7, Tween.EASE_OUT)
	await _wait(0.7)

	# ---------- 4) Crown Call: ลอยสูงเหนือศัตรู ปีกเต็มบาน วงแหวนทองหดเข้า ----------
	Vfx.ring(player, player.global_position + Vector3.UP, Vector3.UP, GOLD_SOFT, 0.3, 2.4, 0.3)
	player.global_position = hi
	player.model.rotation = Vector3(0.0, atan2(fwd.x, fwd.z), 0.0)
	player._play("UltWindup", 0.08, 0.8, true)
	_sfx(SND.charge, 0.0, 0.85)
	if wl:
		wl.regal_mode(true, 3.0, 0.5)
		wr.regal_mode(true, 3.0, 0.5)
	_tw(self, "dim", 0.55, 1.0)
	_tw(glow, "global_position", hi, 0.1)
	_tw(glow, "light_energy", 10.0, 1.0)
	cam.fov = 56.0
	cam.global_transform = Transform3D(Basis(), hi + fwd * 5.0 + Vector3.DOWN * 1.2).looking_at(hi + Vector3.UP * 0.2, Vector3.UP)
	_tw(cam, "global_transform", Transform3D(Basis(), hi + fwd * 7.5 + Vector3.UP * 0.4).looking_at(hi, Vector3.UP), 1.1, Tween.EASE_IN_OUT)
	var wind_end := Time.get_ticks_msec() + 1100
	var rt := 0.0
	var rad := 5.0
	while Time.get_ticks_msec() < wind_end:
		rt -= get_process_delta_time()
		if rt <= 0.0:
			rt = 0.2
			Vfx.ring(player, Vector3(ep.x, e_ground + 0.06, ep.z), Vector3.UP, Color(GOLD.r, GOLD.g, GOLD.b, 0.9), rad, 0.5, 0.45)
			Vfx.sparks(player, hi + Vector3.UP * 0.4, GOLD, 10, 5.0)
			rad = maxf(2.0, rad - 0.5)
		cam_shake = maxf(cam_shake, 0.2)
		await get_tree().process_frame
	if wl:
		wl.regal_mode(false, 1.0, 0.25)
		wr.regal_mode(false, 1.0, 0.25)

	# ---------- 5) Royal Stomp: ดิ่งทับ ----------
	_tw(self, "dim", 0.15, 0.25)
	player._play("JumpKick", 0.02, 1.0, true)
	player.model.rotation = Vector3(deg_to_rad(55.0), atan2(fwd.x, fwd.z), 0.0)
	cam.fov = 66.0
	cam.global_transform = Transform3D(Basis(), ep + right * 5.0 - fwd * 0.5 + Vector3.UP * 4.5).looking_at(ep + Vector3.UP * 5.0, Vector3.UP)
	var land := Vector3(ep.x, ground_y, ep.z) - fwd * 0.3
	_tw(player, "global_position", land + Vector3.UP * 0.8, 0.26, Tween.EASE_IN, Tween.TRANS_QUAD)
	_tw(enemy, "global_position", Vector3(ep.x, e_ground, ep.z), 0.26, Tween.EASE_IN, Tween.TRANS_QUAD)
	_tw(cam, "global_transform", Transform3D(Basis(), ep + right * 4.2 - fwd * 0.4 + Vector3.UP * 0.8).looking_at(ep + Vector3.UP * 1.0, Vector3.UP), 0.4)
	Vfx.streak(player, hi, land + Vector3.UP, GOLD, 0.9, 0.35, true)
	_sfx(SND.dash, 0.0, 0.7)
	await _wait(0.27)
	_stomp_hit(ep)
	await _wait(0.45)                                      # hit-stop

	# ---------- 6) Slide: ศัตรูไถลไปตามพื้นชนขอบลาน ----------
	if is_instance_valid(pillar):
		pillar.queue_free()
	Engine.time_scale = 0.4
	enemy.frozen = false
	enemy.knockdown_pending = true
	enemy.knockback = fwd * 21.0
	enemy.velocity.y = 1.0
	enemy.wall_launched = true
	enemy.slide_end = true
	enemy.slide_decay = 6.0
	player.model.rotation = Vector3(0.0, atan2(fwd.x, fwd.z), 0.0)
	player.global_position = Vector3(land.x, ground_y, land.z)
	player._play("FightIdle", 0.1)
	var wide := ep + right * 6.0 - fwd * 2.5 + Vector3.UP * 2.2
	cam.fov = 58.0
	cam.global_transform = Transform3D(Basis(), wide).looking_at(ep + fwd * 2.0 + Vector3.UP * 0.8, Vector3.UP)
	track_target = enemy
	await _wait(1.0)
	Engine.time_scale = 1.0
	await _wait(1.6)
	track_target = null

	# ---------- กลับเข้าเกม ----------
	var gc: Camera3D = player.fight_cam
	if gc:
		_tw(cam, "global_transform", gc.global_transform, 0.6, Tween.EASE_IN_OUT)
		_tw(cam, "fov", gc.fov, 0.6)
	_tw(self, "letterbox", 0.0, 0.45)
	_tw(self, "dim", 0.0, 0.35)
	if is_instance_valid(glow):
		_tw(glow, "light_energy", 0.0, 0.4)
	await _wait(0.6)
	if is_instance_valid(glow):
		glow.queue_free()
	if gc:
		gc.current = true
	player.global_position.y = ground_y
	player.in_ult = false
	active = false


## เสาแสงสีทองจากฟ้าลงมาที่ศัตรู
func _make_pillar(at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.8
	cm.bottom_radius = 1.0
	cm.height = 16.0
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.0, 0.8, 0.3, 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene().add_child(mi)
	mi.global_position = at + Vector3.UP * 7.0
	_tw(m, "albedo_color", Color(1.0, 0.8, 0.3, 0.35), 0.5)
	return mi


## หมัด/ตัวพุ่งทะลุ: ดาเมจ + ประกายทอง
func _gold_hit(at: Vector3, dir: Vector3, dmg: float) -> void:
	enemy.take_hit(dir, false, dmg)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.add_combo(player.player_index)
	enemy.velocity = Vector3.ZERO
	enemy.knockback = Vector3.ZERO
	cam_shake = maxf(cam_shake, 0.4)
	Vfx.ring(player, at, dir, GOLD, 0.3, 2.2, 0.25)
	Vfx.sparks(player, at, GOLD, 16, 6.5)
	Vfx.sparks(player, at, Color.WHITE, 8, 4.0)
	_burst(at, 0.8)
	Engine.time_scale = 0.05
	get_tree().create_timer(0.05, true, false, true).timeout.connect(func():
		if active and Engine.time_scale < 0.1:
			Engine.time_scale = 1.0)


## ท่าปิด: ทับลงพื้นเต็มแรง พื้นแตก หินกระเด็น ฝุ่นตลบ
func _stomp_hit(ep: Vector3) -> void:
	Engine.time_scale = 0.02
	enemy.take_hit(fwd, true, 95.0)
	enemy.velocity = Vector3.ZERO
	enemy.knockback = Vector3.ZERO
	_sfx(SND.boom, 3.0)
	_flash(Color.WHITE, 1.0, 0.35)
	cam_shake = 1.4
	var g := Vector3(ep.x, player.global_position.y, ep.z)
	var tree := get_tree()
	var root: Node = tree.current_scene
	GroundImpact.spawn(player, g, 1.8)
	GroundImpact._rocks(tree, root, g + Vector3.UP * 0.3, Vector3.UP, 1.8)
	GroundImpact._rocks(tree, root, g + Vector3.UP * 0.3, fwd, 1.2)
	GroundImpact._crack(tree, root, g + Vector3.UP * 0.02, Basis.IDENTITY, 2.2)
	GroundImpact._dust_plume(tree, root, g, Basis.IDENTITY, 1.6)
	GroundImpact._grit(tree, root, g, Basis.IDENTITY, 1.4)
	Vfx.ring(player, g + Vector3.UP * 0.1, Vector3.UP, Color(1, 1, 1, 0.9), 0.5, 7.0, 0.4)
	Vfx.ring(player, g + Vector3.UP * 0.1, Vector3.UP, GOLD, 0.4, 5.0, 0.6)
	Vfx.sparks(player, g + Vector3.UP * 0.6, GOLD, 30, 10.0)
	_burst(g + Vector3.UP * 0.8, 2.0)
	var l := OmniLight3D.new()
	l.light_color = GOLD
	l.light_energy = 10.0
	l.omni_range = 9.0
	root.add_child(l)
	l.global_position = g + Vector3.UP * 1.2
	var tw := l.create_tween().set_ignore_time_scale(true)
	tw.tween_property(l, "light_energy", 0.0, 0.9)
	tw.tween_callback(l.queue_free)


func _scene() -> Node:
	var t := get_tree()
	return t.current_scene if t.current_scene != null else player.get_parent()
