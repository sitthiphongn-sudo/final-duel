extends CharacterBody3D
## ศัตรูบอท (Frostfang): เดิน/วิ่งเข้าหาผู้เล่น แล้วสุ่มออกท่าต่อยคอมโบ / อัปเปอร์คัต / ลูกเตะกระโดด
## โหมดโหด: คูลดาวน์สั้น บล็อกบ่อย บล็อกได้แล้วสวนทันที Dash พุ่งเข้าหา เสยสกัดคนที่กระโดดเข้ามา

const FighterRig := preload("res://scripts/fighter_rig.gd")
const HandFire := preload("res://scripts/hand_fire.gd")
const Vfx := preload("res://scripts/vfx.gd")
const GroundImpact := preload("res://scripts/ground_impact.gd")
const SLAM_SFX := preload("res://sounds/ground_slam.wav")
const GameState := preload("res://scripts/game_state.gd")
var char_id := "frostfang"
var char_data := {}

const ACTION_LEN := {
	"Punch1": 0.26, "Punch2": 0.26, "Punch3": 0.47,
	"JumpKick": 0.45, "Land": 0.18, "Hit": 0.35, "HitHeavy": 0.6,
	"JumpPrep": 0.08, "BlockHit": 0.25, "KnockDown": 2.0, "GetUp": 1.0,
	"DashF": 0.3,
}
const LUNGE := {"Punch1": 0.8, "Punch2": 1.0, "Punch3": 1.3}
const HIT_FRAC := {"Punch1": 0.3, "Punch2": 0.3, "Punch3": 0.44, "JumpKick": 0.42}
const HEAVY := ["Punch3", "JumpKick"]
const SFX := {
	"whoosh_light": preload("res://sounds/whoosh_light.wav"),
	"whoosh_heavy": preload("res://sounds/whoosh_heavy.wav"),
	"jump": preload("res://sounds/jump.wav"),
	"land": preload("res://sounds/land.wav"),
	"hit_light": preload("res://sounds/hit_light.wav"),
	"hit_heavy": preload("res://sounds/hit_heavy.wav"),
	"block": preload("res://sounds/block.wav"),
}
const STEPS := [
	preload("res://sounds/step_0.wav"), preload("res://sounds/step_1.wav"),
	preload("res://sounds/step_2.wav"), preload("res://sounds/step_3.wav"),
]

@export_group("AI")
@export var enabled := true
@export var walk_speed := 1.8
@export var run_speed := 6.0
@export var run_distance := 6.0        ## ไกลกว่านี้จะวิ่งเข้าหา
@export var attack_distance := 1.35    ## ระยะที่เริ่มโจมตี
@export var hit_range := 1.5
@export var min_cooldown := 0.25       ## เวลาพักระหว่างการโจมตี (สุ่มระหว่าง min-max)
@export var max_cooldown := 0.7
@export var retreat_chance := 0.12     ## โอกาสถอยออกหลังโจมตีเสร็จ
@export var punch_lunge := 3.0
@export var kick_lunge := 5.5
@export var jump_velocity := 7.0
@export var rise_gravity := 2.0
@export var fall_gravity := 3.2
@export var block_chance := 0.6       ## โอกาสบล็อกเมื่อผู้เล่นออกหมัดใส่
@export var turn_speed := 14.0         ## หันตามผู้เล่นเร็วแค่ไหน
@export var dash_in_chance := 0.55     ## โอกาส Dash พุ่งเข้าหาเมื่ออยู่ระยะกลาง (ต่อการตัดสินใจ)
@export var dash_distance := 3.2
@export var hit_recover := 0.3         ## โดนต่อยแล้วพักก่อนสวนกลับ (วินาที)
@export var air_counter_chance := 0.6  ## ตอนโดนจับลอยกลางอากาศ: โอกาสต่อยสวนเมื่อผู้เล่นเว้นจังหวะ
@export var air_stun := 0.35           ## โดนหมัดกลางอากาศแล้วมึนนานเท่านี้ก่อนสวนได้
@export var air_counter_windup := 0.2  ## ง้างหมัดสวนนานเท่านี้ (ผู้เล่นต่อยแทรกทันจะขัดได้)
@export var air_flurry_hits := 6       ## สวนแล้วรัวหมัดกลางอากาศกี่หมัด (หมัดสุดท้ายซัดผู้เล่นร่วง)
@export var air_flurry_interval := 0.12
@export var air_flurry_damage := 12.0

@export_group("Hand Fire")
@export var hand_fire := true
@export var fire_size := 1.4
@export var vfx_color := Color(0.35, 0.72, 1.0)     ## สีเอฟเฟกต์ (ไฟน้ำเงิน)
@export var wind_color := Color(0.8, 0.92, 1.0)

@export_group("Stats")
@export var hp_max := 2000.0
@export var stamina_max := 100.0
@export var stamina_regen := 20.0
@export var damage_light := 26.0
@export var damage_heavy := 44.0

@export_group("Hit Reaction")
@export var knockback_light := 2.5
@export var knockback_heavy := 6.0
@export var respawn_height := -30.0

@onready var model: Node3D = $Model

var anim_player: AnimationPlayer
var rig
var walk_anim := ""
var run_anim := ""
var knockback := Vector3.ZERO
var shake := 0.0
var model_base_pos: Vector3
var spawn_point: Vector3
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var action := ""
var action_time := 0.0
var action_elapsed := 0.0
var hit_done := false
var queue: Array = []          # ท่าที่จะออกต่อในคอมโบ
var cooldown := 1.5
var retreat_time := 0.0
var air_time := 0.0
var step_timer := 0.0
var block_time := 0.0
var is_blocking := false
var prev_player_action := ""
var slam_pending := false      # โดนทุบลงจากฟ้า -> ตกถึงพื้นแล้วฝุ่น/หินกระจายแรง
var knockdown_pending := false  # โดนหมัดปิดท้ายอัลติเมต -> ตกถึงพื้นแล้วล้มหงาย
var hp := 2000.0
var stamina := 100.0
var ult_gauge := 0.0          # หลอด MAGIC ของศัตรู
var frozen := false
var decide_cd := 0.0          # หน่วงการตัดสินใจ dash
var dash_dir := Vector3.ZERO
var dash_dist_cur := 3.0
var fire_l: Node3D
var fire_r: Node3D          # อัลติเมตของผู้เล่นควบคุมอยู่ (หยุด AI/ฟิสิกส์)


func _ready() -> void:
	# คู่ต่อสู้ที่ถูกเลือกให้ (ตัวที่ผู้เล่นไม่ได้เลือก)
	char_id = GameState.p2
	char_data = GameState.data(char_id)
	model = GameState.swap_model(self, model, char_id)
	hp_max = float(char_data["hp"])
	damage_light = round(float(char_data["atk"]) * GameState.BOT_DAMAGE_MULT)
	damage_heavy = round(float(char_data["atk"]) * GameState.BOT_DAMAGE_MULT * 1.7)
	vfx_color = char_data["vfx_color"]
	add_to_group("enemy")
	hp = hp_max
	stamina = stamina_max
	spawn_point = global_position
	model_base_pos = model.position
	anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player == null:
		return
	for n in anim_player.get_animation_list():
		if n.to_lower().contains("walk") and not n.contains("001") and walk_anim == "":
			walk_anim = n
	if walk_anim != "":
		anim_player.get_animation(walk_anim).loop_mode = Animation.LOOP_LINEAR
	rig = FighterRig.new()
	for a in LUNGE:
		rig.step_dist[a] = punch_lunge * LUNGE[a] * FighterRig.LUNGE_LEN * ACTION_LEN[a] * 2.0 / PI
	if rig.setup(model, anim_player):
		rig.build_all(ACTION_LEN)
	run_anim = rig.import_anim(char_data["run_glb"], "Run")
	if hand_fire and rig._skel:
		fire_l = _attach_fire(1)
		fire_r = _attach_fire(-1)
	anim_player.play("FightIdle")
	anim_player.seek(randf() * 2.0, true)


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _physics_process(delta: float) -> void:
	if frozen:
		return
	stamina = minf(stamina_max, stamina + stamina_regen * delta)
	ult_gauge = minf(100.0, ult_gauge + 4.0 * delta)
	var on_floor := is_on_floor()
	if on_floor:
		air_time = 0.0
	else:
		air_time += delta
		velocity.y -= gravity * (rise_gravity if velocity.y > 0.0 else fall_gravity) * delta

	var player := _player()
	var to := Vector3.ZERO
	if player:
		to = player.global_position - global_position
		to.y = 0
	var dist := to.length()
	var move_dir := Vector3.ZERO
	var speed := 0.0

	# ---- อ่านจังหวะผู้เล่น: เห็นผู้เล่นเริ่มออกหมัดในระยะ -> สุ่มบล็อก ----
	if player and "action" in player:
		var pa: String = player.action
		if pa != prev_player_action and pa in HIT_FRAC and dist < 2.5 and action == "" and on_floor and randf() < block_chance:
			block_time = randf_range(0.45, 0.9)
		prev_player_action = pa
	block_time -= delta
	is_blocking = block_time > 0.0 and on_floor and (action == "" or action == "BlockHit")

	# ---- แอคชันที่กำลังทำ ----
	if action != "":
		action_elapsed += delta
		action_time -= delta
		if not hit_done and action in HIT_FRAC and action_elapsed >= HIT_FRAC[action] * ACTION_LEN[action]:
			hit_done = true
			_try_hit()
		if action_time <= 0.0 and action == "KnockDown":
			_start_action("GetUp")
		elif action_time <= 0.0:
			action = ""
			if not queue.is_empty() and on_floor:
				_face(to, 1.0)
				var nxt: String = queue.pop_front()
				if nxt == "JumpKick":
					velocity.y = jump_velocity * 0.62
					air_time = 0.2
					_sfx("jump", -8.0)
				_start_action(nxt)
			elif randf() < retreat_chance:
				retreat_time = randf_range(0.4, 0.8)
	# ---- ตัดสินใจ (AI) ----
	elif enabled and player:
		cooldown -= delta
		if is_blocking:
			_face(to, 10.0 * delta)
		elif retreat_time > 0.0:
			retreat_time -= delta
			move_dir = -to.normalized()
			speed = walk_speed
			_face(to, 8.0 * delta)
		elif dist > attack_distance:
			move_dir = to.normalized()
			speed = run_speed if dist > 3.0 else walk_speed * 1.6
			_face(move_dir, turn_speed * delta)
			decide_cd -= delta
			# ระยะกลาง: Dash พุ่งเข้าประชิด
			if on_floor and dist > 2.2 and dist < 7.5 and decide_cd <= 0.0:
				decide_cd = 0.6
				if randf() < dash_in_chance:
					_face(to, 1.0)
					_start_dash(to.normalized(), minf(dash_distance, dist - 1.0))
		else:
			_face(to, turn_speed * delta)
			# ผู้เล่นกระโดดเข้ามา -> เสยสกัด
			if on_floor and player and not player.is_on_floor() and player.global_position.y - global_position.y < 2.2 and cooldown <= 0.25:
				queue = []
				_start_action("Punch3")
				cooldown = randf_range(min_cooldown, max_cooldown)
			elif cooldown <= 0.0 and on_floor:
				_choose_attack()

	# ---- เคลื่อนที่ ----
	var lunge := _lunge_speed()
	if knockback.length() > 0.05:
		velocity.x = knockback.x
		velocity.z = knockback.z
		knockback = knockback.move_toward(Vector3.ZERO, 14.0 * delta)
	elif action == "DashF":
		var t01 := 1.0 - action_time / float(ACTION_LEN["DashF"])
		var v0 := 2.5 * dash_dist_cur / float(ACTION_LEN["DashF"])
		var v := v0 * pow(1.0 - clampf(t01, 0.0, 1.0), 1.5)
		velocity.x = dash_dir.x * v
		velocity.z = dash_dir.z * v
		model.visible = t01 < 0.14 or t01 > 0.72
	elif lunge > 0.0:
		var fwd := model.global_basis.z
		fwd.y = 0
		fwd = fwd.normalized()
		velocity.x = fwd.x * lunge
		velocity.z = fwd.z * lunge
	elif speed > 0.0:
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
	elif on_floor:
		velocity.x = move_toward(velocity.x, 0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 20.0 * delta)

	if action != "DashF" and not model.visible:
		model.visible = true
	var was_air := air_time
	move_and_slide()
	if knockdown_pending and is_on_floor() and was_air > 0.1:
		knockdown_pending = false
		_start_action("KnockDown")
		_sfx("land", 2.0, 0.8)
		# กระแทกพื้น: ฝุ่น + หินกระจาย (ถูกทุบจากฟ้า = แรงสุด, ล้มปกติ = เบาลง)
		var power := 1.0 if slam_pending else 0.45
		GroundImpact.spawn(self, global_position, power)
		if slam_pending:
			_sfx_stream(SLAM_SFX, 4.0, randf_range(0.95, 1.05))
		var pl := _player()
		if pl and "shake" in pl:
			pl.shake = maxf(pl.shake, 1.1 if slam_pending else 0.5)
		slam_pending = false
	elif is_on_floor() and was_air > 0.25 and (action == "" or action == "JumpKick"):
		_start_action("Land")
		_sfx("land", -5.0)

	# ---- แอนิเมชัน ----
	if action == "" and anim_player:
		if not is_on_floor() and air_time > 0.1:
			_play("JumpUp" if velocity.y > 0.5 else "JumpFall", 0.12)
		elif is_blocking:
			_play("Block", 0.08)
		elif speed > 0.0:
			if speed >= run_speed and run_anim != "":
				_play(run_anim, 0.2)
			else:
				# ถอยหลัง = เล่นท่าเดินย้อนกลับ
				_play(walk_anim, 0.2, -1.0 if retreat_time > 0.0 else 1.1)
		else:
			_play("FightIdle", 0.3)

	# เสียงเท้า
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.8 and action == "":
		step_timer -= delta
		if step_timer <= 0.0:
			step_timer = 0.34 if speed >= run_speed else 0.48
			_sfx_stream(STEPS.pick_random(), -12.0, randf_range(0.85, 1.0))

	if global_position.y < respawn_height:
		global_position = spawn_point
		velocity = Vector3.ZERO


func _choose_attack() -> void:
	var r := randf()
	if r < 0.2:
		queue = ["Punch2"]                  # หมัด 1-2
		_start_action("Punch1")
	elif r < 0.45:
		queue = ["Punch2", "Punch3"]        # คอมโบ 1-2-3
		_start_action("Punch1")
	elif r < 0.7:
		queue = ["Punch2", "Punch3", "JumpKick"]   # คอมโบเต็ม 4 จังหวะ
		_start_action("Punch1")
	elif r < 0.85:
		queue = []
		_start_action("Punch3")
	else:
		queue = []
		velocity.y = jump_velocity * 0.62
		air_time = 0.2
		_sfx("jump", -8.0)
		_start_action("JumpKick")
	cooldown = randf_range(min_cooldown, max_cooldown)


## Dash พุ่งเข้าหาผู้เล่น (วาร์ปหายตัวช่วงกลาง + เส้นความเร็ว เหมือนผู้เล่น)
func _start_dash(d: Vector3, dist: float) -> void:
	if stamina < 20.0:
		return
	stamina -= 20.0
	dash_dir = d
	dash_dist_cur = maxf(dist, 1.0)
	queue.clear()
	_start_action("DashF")
	var c := global_position + Vector3.UP * 1.0
	var endp := c + d * dash_dist_cur
	Vfx.ring(self, c, d, Color(vfx_color.r, vfx_color.g, vfx_color.b, 0.7), 0.25, 1.3, 0.28)
	Vfx.speed_lines(self, c, endp, Color(1, 1, 1, 0.85), 12, 0.6, 0.035, 0.3)
	Vfx.speed_lines(self, c, endp, vfx_color, 6, 0.85, 0.05, 0.32)
	_sfx("whoosh_light", -4.0, 0.7)
	# จบ dash แล้วต่อยทันที
	cooldown = 0.0


func _start_action(a: String) -> void:
	action = a
	action_time = ACTION_LEN[a]
	action_elapsed = 0.0
	hit_done = false
	if a in HIT_FRAC:
		_punch_vfx(a)
		_boost_fire(a)
		_sfx("whoosh_heavy" if a in HEAVY else "whoosh_light", -6.0, randf_range(0.85, 1.0))
	if anim_player and anim_player.has_animation(a):
		anim_player.play(a, 0.05)
		anim_player.seek(0.0, true)


func _lunge_speed() -> float:
	if action == "":
		return 0.0
	var t01 := 1.0 - action_time / float(ACTION_LEN[action])
	if action in LUNGE:
		# ไม่พุ่งทะลุผู้เล่น
		var p := _player()
		if p and global_position.distance_to(p.global_position) < 0.9:
			return 0.0
		return punch_lunge * LUNGE[action] * sin(PI * FighterRig.lunge_k(action, t01))
	if action == "JumpKick":
		return kick_lunge * (1.0 - smoothstep(0.5, 1.0, t01))
	return 0.0


func _try_hit() -> void:
	var p := _player()
	if p == null or not p.has_method("take_hit"):
		return
	var fwd := model.global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var to := p.global_position - global_position
	to.y = 0
	var reach := hit_range + (0.3 if action == "JumpKick" else 0.0)
	if to.length() <= reach and fwd.dot(to.normalized()) >= 0.35:
		var dmg: float = damage_heavy if action in HEAVY else damage_light
		p.take_hit(fwd, action in HEAVY, dmg)
		stamina = maxf(0.0, stamina - 8.0)


func _face(dir: Vector3, weight: float) -> void:
	if dir.length() < 0.01:
		return
	model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), clampf(weight, 0.0, 1.0))


func _play(anim_name: String, blend: float, speed := 1.0) -> void:
	if anim_name == "" or not anim_player.has_animation(anim_name):
		return
	if anim_player.assigned_animation != anim_name or anim_player.get_playing_speed() != speed and anim_player.get_animation(anim_name).loop_mode != Animation.LOOP_NONE:
		anim_player.play(anim_name, blend, speed, speed < 0.0)


## ถูกผู้เล่นต่อย: ยกเลิกท่า กระเด็น สั่น เล่นท่าโดนต่อย
func take_hit(dir: Vector3, heavy: bool, damage := 0.0) -> bool:
	if action == "KnockDown" or action == "GetUp":
		return false   # ล้มอยู่ ตีไม่โดน
	# บล็อกได้เฉพาะการโจมตีจากด้านหน้า
	if is_blocking and model.global_basis.z.dot(-dir) > 0.3:
		var sp: Vector3 = global_position + Vector3.UP * 1.15 - dir * 0.75
		Vfx.shield(self, sp, -dir, Color(0.5, 0.8, 1.0), 1.5 if heavy else 1.2)
		Vfx.sparks(self, sp, Color(0.75, 0.9, 1.0), 14, 6.0)
		knockback = dir * (3.0 if heavy else 1.2)
		_start_action("BlockHit")
		_sfx("block", 0.0, randf_range(0.9, 1.1) * (0.85 if heavy else 1.0))
		shake = 0.05
		block_time = maxf(block_time, 0.3)
		stamina = maxf(0.0, stamina - 12.0)
		_damage(damage * 0.2)
		cooldown = 0.0                       # บล็อกได้แล้วสวนกลับทันที
		return true
	queue.clear()
	block_time = 0.0
	retreat_time = 0.0
	knockback = dir * (knockback_heavy if heavy else knockback_light)
	if heavy:
		velocity.y = 3.0
	model.rotation.y = atan2(-dir.x, -dir.z)
	_start_action("HitHeavy" if heavy else "Hit")
	_damage(damage)
	shake = 0.12 if heavy else 0.07
	_sfx("hit_heavy" if heavy else "hit_light", 0.0, randf_range(0.9, 1.05))
	cooldown = maxf(cooldown, hit_recover)   # เว้นจังหวะนิดเดียวแล้วสวน
	return false


func _process(delta: float) -> void:
	if shake > 0.0:
		model.position = model_base_pos + Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1)) * shake
		shake = move_toward(shake, 0.0, delta / maxf(Engine.time_scale, 0.001) * 0.2)
	else:
		model.position = model_base_pos


func _sfx(sfx_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	_sfx_stream(SFX[sfx_name], volume_db, pitch)


func _sfx_stream(stream: AudioStream, volume_db := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.bus = "SFX"
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.position = Vector3(0, 1.0, 0)
	p.finished.connect(p.queue_free)
	p.play()


## ไฟน้ำเงินที่มือ (Frostfang)
func _attach_fire(side: int) -> Node3D:
	var skel: Skeleton3D = rig._skel
	var att := BoneAttachment3D.new()
	att.bone_name = skel.get_bone_name(rig._b(side, "Hand"))
	skel.add_child(att)
	var fx := HandFire.new()
	fx.size = fire_size
	var fc: Array = char_data["fire"]
	fx.flipbook = load(char_data["flipbook"])
	fx.color_core = fc[0]
	fx.color_mid = fc[1]
	fx.color_tail = fc[2]
	fx.color_ember = fc[3]
	fx.color_light = fc[4]
	fx.position = Vector3(0, 0.12, 0.0)
	att.add_child(fx)
	return fx


## ไฟลุกแรงขึ้นตอนออกหมัด
func _boost_fire(a: String) -> void:
	if fire_l == null:
		return
	match a:
		"Punch1": fire_l.boost(1.0)
		"Punch2": fire_r.boost(1.0)
		"Punch3": fire_r.boost(2.5)
		"JumpKick":
			fire_l.boost(0.6)
			fire_r.boost(0.6)


## ลมกระจายตอนศัตรูออกหมัด
func _punch_vfx(a: String) -> void:
	if rig == null or rig._skel == null:
		return
	var side := 1 if a == "Punch1" else -1
	var bone := "Foot" if a == "JumpKick" else "Hand"
	var skel: Skeleton3D = rig._skel
	var pos: Vector3 = skel.global_transform * skel.get_bone_global_pose(rig._b(side, bone)).origin
	var fwd := model.global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	Vfx.puff(self, pos + fwd * 0.2, fwd, wind_color, 5, 5.0, 0.22, 0.14, 25.0)
	Vfx.ring(self, pos + fwd * 0.35, fwd, Color(wind_color.r, wind_color.g, wind_color.b, 0.35), 0.12, 0.65, 0.18)


func _damage(amount: float) -> void:
	if amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	if hp <= 0.0:
		knockdown_pending = true
		var hud = get_tree().get_first_node_in_group("hud")
		if hud:
			hud.show_ko("K.O.")
		get_tree().create_timer(3.0, true, false, true).timeout.connect(func():
			hp = hp_max)
