extends "res://scripts/ultimate.gd"
## อัลติเมต "Shadow Death Dash" ของกาจอมยุทธ์ — คัทซีนสดในเกม (~8 วินาที)
##   1) จอดับ -> ตัวอักษรแดง 死ね ค่อยๆ ซูม
##   2) หายดำปุ๊บ ตัวกาหายไป เหลือแต่เส้นดาบฟันรัวรอบศัตรู 16 ครั้ง แล้วปรากฏฟันปิดเส้นเดียว
##   3) ศัตรูไถลไปชนขอบลาน แล้วกลับเข้าเกม

const Vfx := preload("res://scripts/vfx.gd")
const GroundImpact := preload("res://scripts/ground_impact.gd")
const CrowSlash := preload("res://scripts/crow_slash.gd")
const DEATH_SND := preload("res://sounds/ult_death.mp3")
const RED := Color(1.0, 0.18, 0.2)
const RED_SOFT := Color(1.0, 0.35, 0.3, 0.9)

var black: ColorRect
var kanji: TextureRect


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
	_flash(RED, 0.5, 0.25)
	_sfx(SND.hit_heavy, -4.0)

	var ground_y: float = player.global_position.y
	var ep: Vector3 = enemy.global_position
	var p0: Vector3 = player.global_position
	var chest: Vector3 = ep + Vector3.UP * 0.9

	# ---------- 1) เงามืด: จอดับ แล้วขึ้นตัวอักษรแดง 死ね ซูมช้าๆ ----------
	black = ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(black)
	var tb: Tween = black.create_tween()
	tb.tween_property(black, "color:a", 1.0, 0.5)
	await _wait(0.6)
	kanji = TextureRect.new()
	kanji.texture = load("res://ui/ult_shine.png")
	kanji.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	kanji.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	kanji.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kanji.modulate = Color(1, 1, 1, 0)
	kanji.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(kanji)
	var vs := get_viewport().get_visible_rect().size
	kanji.pivot_offset = vs * 0.5
	kanji.scale = Vector2.ONE * 0.7
	var tk: Tween = kanji.create_tween().set_parallel(true)
	tk.tween_property(kanji, "modulate:a", 1.0, 0.5)
	tk.tween_property(kanji, "scale", Vector2.ONE * 1.25, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sfx(DEATH_SND, 3.0)
	await _wait(1.4)
	_sfx(SND.hit_heavy, 0.0, 0.7)
	cam_shake = 0.6
	await _wait(1.0)
	# ---------- 2) หายดำปุ๊บ: ตัวกาหายไป เหลือแต่เส้นดาบฟันรัวรอบศัตรู ----------
	tk.kill()
	var tk2: Tween = kanji.create_tween().set_parallel(true)
	tk2.tween_property(kanji, "modulate:a", 0.0, 0.12)
	tk2.tween_property(kanji, "scale", Vector2.ONE * 2.2, 0.12)
	black.color.a = 0.0
	_flash(RED, 0.9, 0.25)
	_tw(self, "letterbox", 1.0, 0.2)
	_tw(self, "dim", 0.3, 0.2)
	enemy.anim_player.speed_scale = 1.0
	enemy.anim_player.play("Hit", 0.05)
	player.model.visible = false
	var epl: Vector3 = chest
	var n_cuts := 16
	var side_sign := 1.0
	for i in n_cuts:
		var th := randf() * TAU
		var cdir := Vector3(cos(th), 0.0, sin(th))
		var zb := cdir.cross(Vector3.UP).normalized()
		var bb := deg_to_rad(side_sign * randf_range(35.0, 80.0))
		side_sign = -side_sign
		var rr := 7.0
		var cen := -rr * Vector3(0.0, sin(bb), cos(bb))
		var off := Vector3(randf_range(-0.25, 0.25), randf_range(-0.3, 0.3), randf_range(-0.25, 0.25))
		var xfc := Transform3D(Basis(cdir, Vector3.UP, zb), epl + off)
		cam.fov = randf_range(34.0, 52.0)
		var cam_pos: Vector3 = epl + cdir * randf_range(3.2, 4.8) + Vector3.UP * randf_range(-0.1, 0.7)
		cam.global_transform = Transform3D(Basis(), cam_pos).looking_at(epl + Vector3(0, randf_range(-0.1, 0.2), 0), Vector3.UP)
		CrowSlash.arc(player, xfc, rad_to_deg(bb) - 24.0, rad_to_deg(bb) + 24.0, rr, 0.09, 1, cen, 0.0, 1.0, 0.12)
		_cut_fx(epl + off, cdir, 5.0)
		_sfx(SND.dash, -2.0, randf_range(1.1, 1.6))
		await _wait(lerpf(0.13, 0.065, float(i) / float(n_cuts - 1)))

	# ---------- ฟันปิด: ตัวกากลับมาปรากฏด้านหลังศัตรู ----------
	var mid: Vector3 = Vector3(ep.x, ground_y, ep.z)
	var thru: Vector3 = mid + fwd * 2.6
	player.global_position = thru
	player.model.rotation = Vector3(0.0, atan2(fwd.x, fwd.z), 0.0)
	player.model.visible = true
	player.rig.draw_blade(1.5)
	player._play("UltStrike", 0.02, 1.0, true)
	cam.fov = 36.0
	cam.global_transform = Transform3D(Basis(), chest + right * 4.0 + fwd * 0.3 + Vector3.UP * 0.3).looking_at(chest, Vector3.UP)
	var xf: Transform3D = player.model.global_transform
	xf.basis = xf.basis.orthonormalized()
	xf.origin = chest + fwd * 0.2
	var bb2 := deg_to_rad(-50.0)
	var rr2 := 7.0
	var cen2 := -rr2 * Vector3(0.0, sin(bb2), cos(bb2))
	CrowSlash.arc(player, xf, -50.0 - 22.0, -50.0 + 22.0, rr2, 0.10, 1, cen2, 0.0, 1.0, 0.7)
	_red_hit(chest, fwd, 30.0)
	Vfx.sparks(player, chest, Color(0.85, 0.0, 0.05), 40, 9.0)
	Vfx.sparks(player, chest + Vector3.UP * 0.3, Color(0.7, 0.0, 0.04), 24, 6.0)
	_flash(Color.WHITE, 1.0, 0.12)
	await _wait(0.12)
	Engine.time_scale = 0.12
	await _wait(0.12)
	Engine.time_scale = 1.0

	# ---------- 3) ศัตรูไถลไปชนขอบลาน ----------
	_moon_hit(ep)
	Engine.time_scale = 0.4
	enemy.frozen = false
	enemy.knockdown_pending = true
	enemy.knockback = fwd * 19.0
	enemy.velocity.y = 1.0
	enemy.wall_launched = true
	enemy.slide_end = true
	enemy.slide_decay = 6.0
	var wide := ep + right * 6.0 - fwd * 2.5 + Vector3.UP * 2.2
	cam.fov = 58.0
	cam.global_transform = Transform3D(Basis(), wide).looking_at(ep + fwd * 2.0 + Vector3.UP * 0.8, Vector3.UP)
	track_target = enemy
	var tree := get_tree()
	var root_n: Node = tree.current_scene
	for k in 7:
		await _wait(0.15)
		if not is_instance_valid(enemy):
			break
		var gp := Vector3(enemy.global_position.x, ground_y, enemy.global_position.z)
		GroundImpact._rocks(tree, root_n, gp + Vector3.UP * 0.2, Vector3.UP, 0.45)
		GroundImpact._dust_plume(tree, root_n, gp, Basis.IDENTITY, 0.8)
		if k == 2:
			Engine.time_scale = 1.0
	Engine.time_scale = 1.0
	await _wait(1.0)
	track_target = null

	# ---------- กลับเข้าเกม ----------
	var gc: Camera3D = player.fight_cam
	if gc:
		_tw(cam, "global_transform", gc.global_transform, 0.6, Tween.EASE_IN_OUT)
		_tw(cam, "fov", gc.fov, 0.6)
	_tw(self, "letterbox", 0.0, 0.45)
	_tw(self, "dim", 0.0, 0.35)
	await _wait(0.6)
	if is_instance_valid(black):
		black.queue_free()
	if is_instance_valid(kanji):
		kanji.queue_free()
	player.model.visible = true
	if gc:
		gc.current = true
	player.global_position.y = ground_y
	player.in_ult = false
	active = false


## ฟันรัว: ประกายแดง/ขาว ศัตรูสะดุ้ง (ไม่หน่วงเวลา)
func _cut_fx(at: Vector3, dir: Vector3, dmg: float) -> void:
	enemy.take_hit(dir, false, dmg)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.add_combo(player.player_index)
	enemy.velocity = Vector3.ZERO
	enemy.knockback = Vector3.ZERO
	cam_shake = maxf(cam_shake, 0.25)
	Vfx.sparks(player, at, RED, 8, 5.0)
	Vfx.sparks(player, at, Color.WHITE, 4, 3.5)
	Engine.time_scale = 1.0


## ฟันทะลุ: ดาเมจ + ประกายแดง
func _red_hit(at: Vector3, dir: Vector3, dmg: float) -> void:
	enemy.take_hit(dir, false, dmg)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.add_combo(player.player_index)
	enemy.velocity = Vector3.ZERO
	enemy.knockback = Vector3.ZERO
	cam_shake = maxf(cam_shake, 0.4)
	Vfx.ring(player, at, dir, RED, 0.3, 2.2, 0.25)
	Vfx.sparks(player, at, RED, 16, 6.5)
	Vfx.sparks(player, at, Color.WHITE, 8, 4.0)
	_burst(at, 0.8)
	Engine.time_scale = 0.05
	get_tree().create_timer(0.05, true, false, true).timeout.connect(func():
		if active and Engine.time_scale < 0.1:
			Engine.time_scale = 1.0)


## ฟันปิด: พื้นแตก หินกระเด็น ฝุ่นตลบ
func _moon_hit(ep: Vector3) -> void:
	Engine.time_scale = 0.02
	enemy.take_hit(fwd, true, 40.0)
	enemy.velocity = Vector3.ZERO
	enemy.knockback = Vector3.ZERO
	_sfx(SND.boom, 3.0)
	_flash(Color.WHITE, 1.0, 0.35)
	cam_shake = 1.4
	var g := Vector3(ep.x, player.global_position.y, ep.z)
	var tree := get_tree()
	var root: Node = tree.current_scene
	GroundImpact.spawn(player, g, 1.6)
	GroundImpact._rocks(tree, root, g + Vector3.UP * 0.3, Vector3.UP, 0.8)
	GroundImpact._crack(tree, root, g + Vector3.UP * 0.02, Basis.IDENTITY, 2.4)
	GroundImpact._dust_plume(tree, root, g, Basis.IDENTITY, 1.5)
	Vfx.ring(player, g + Vector3.UP * 0.1, Vector3.UP, Color(1, 1, 1, 0.9), 0.5, 7.0, 0.4)
	Vfx.ring(player, g + Vector3.UP * 0.1, Vector3.UP, RED, 0.4, 5.0, 0.6)
	Vfx.sparks(player, g + Vector3.UP * 0.6, RED, 30, 10.0)
	_burst(g + Vector3.UP * 0.8, 2.0)
	var l := OmniLight3D.new()
	l.light_color = RED
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
