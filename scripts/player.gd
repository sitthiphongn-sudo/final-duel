extends CharacterBody3D
## นักสู้ที่ผู้เล่นควบคุม — ใช้สคริปต์เดียวกันทั้ง P1 และ P2 (ตั้ง player_index ใน main.tscn)
## ปุ่มของแต่ละคนดูที่ GameState.setup_inputs() (P1 = WASD + J/K/L, P2 = ลูกศร + Numpad)
## ต่อย x5 = คอมโบ 5 จังหวะ (หมัด 1-2-อัปเปอร์คัต-กระโดดเตะ-เสยขึ้นฟ้า)
## กลางอากาศหลังหมัด 5: ต่อย = ต่อยทีละหมัดเอง | เตะ = ทุบลงพื้น | ไม่กดนาน = ร่วงลงเอง (คู่ต่อสู้ไม่ล้ม)
## ฝ่ายที่ถูกจับลอยกลางอากาศ: กดต่อยตอนอีกฝ่ายเว้นจังหวะ = ง้างสวน (อีกฝ่ายต่อยแทรกทันจะขัดได้) แล้วรัวหมัดกลับ
## อัลติเมต (เกจเต็ม) | บล็อกค้าง | Dash (กดทิศค้างเพื่อเลือกทาง, ถอยหลัง = ถอยหลบ, กลางอากาศได้ 1 ครั้ง)
## โจมตีจะหันหาคู่ต่อสู้อัตโนมัติเมื่ออยู่ใกล้ | ทิศเดินอิงกล้องรวม (fight_camera.gd)

@export_group("Movement")
@export var walk_speed := 2.2
@export var run_speed := 6.3
@export var jump_velocity := 7.0
@export var rise_gravity := 2.0        ## คูณแรงโน้มถ่วงตอนขึ้น (มาก = ถึงจุดสูงสุดเร็ว)
@export var fall_gravity := 3.2        ## คูณแรงโน้มถ่วงตอนตก (มาก = ตกเร็ว ไม่ลอยค้าง)
@export var turn_speed := 10.0
@export var walk_anim_speed := 1.1
@export var run_anim_speed := 1.15
@export var mouse_sensitivity := 0.003
@export var punch_lunge := 3.0         ## ความเร็วพุ่งไปข้างหน้าตอนต่อย (หมัด 3 แรงขึ้นอีก)
@export var kick_lunge := 5.5          ## ความเร็วพุ่งไปข้างหน้าตอนเตะกระโดด (กระโดด "ไปข้างหน้า" ไม่ใช่ขึ้นสูง)
@export var kick_jump := 0.62          ## แรงกระโดดตอนเตะ (สัดส่วนของ jump_velocity)

@export_group("Dash")
@export var dash_distance := 2.9       ## ระยะ dash ไปข้างหน้า (เมตร)
@export var dash_back_distance := 2.1  ## ระยะถอยหลบ
@export var dash_cooldown := 0.35
@export var dash_fov_kick := 8.0       ## มุมกล้องกว้างขึ้นชั่วขณะตอน dash (องศา)

@export_group("Stats")
@export var hp_max := 2000.0
@export var stamina_max := 100.0
@export var stamina_regen := 22.0        ## ฟื้นต่อวินาที
@export var dash_cost := 25.0            ## Dash ใช้สตามินาเท่านี้
@export var damage_light := 22.0
@export var damage_heavy := 38.0

@export_group("Ultimate")
@export var ult_start_full := false     ## เริ่มเกมมาเกจเต็มเลย (ไว้ลองท่า) ปิด = ต้องตีก่อนเกจถึงจะขึ้น
@export var ult_gain_hit := 9.0         ## เกจที่ได้เมื่อต่อยโดน
@export var ult_gain_heavy := 14.0      ## เกจที่ได้เมื่อหมัด 3 / เตะโดน
@export var ult_gain_hurt := 6.0        ## เกจที่ได้เมื่อโดนต่อย

@export_group("Hand Fire")
@export var hand_fire := true
@export var arena_radius := 7.2          ## เดินได้แค่ในวงกลมกลางลาน (เมตร จากจุดกึ่งกลางแมพ)
@export var fire_size := 1.4

@export_group("VFX")
@export var vfx_color := Color(1.0, 0.62, 0.25)   ## สีเอฟเฟกต์ประจำตัว (ไฟส้ม)
@export var wind_color := Color(0.85, 0.9, 1.0)   ## สีลมที่กระจายตอนออกหมัด
@export var respawn_height := -30.0

@export_group("Combat Feel")
@export var hit_range := 1.5           ## ระยะต่อยโดน (เมตร)
@export var shake_light := 0.55        ## กล้องสั่นตอนต่อยเบา
@export var shake_heavy := 1.0         ## กล้องสั่นตอนหมัด 3 / เตะ
@export var hitstop_light := 0.06      ## หยุดเวลาชั่วขณะตอนโดน (วินาที)
@export var hitstop_heavy := 0.14
@export var warp_dive_damage := 55.0   ## ดาเมจหมัดที่ 5 (วาร์ปทิ่มหมัดลง)
@export var warp_dive_angle := 45.0    ## มุมทิ่มลง (องศา) แบบ Dragon Ball
@export var air_rush_height := 2.6     ## ยกศัตรูลอยสูงจากพื้นกี่เมตร
@export var air_rush_hits := 10        ## ต่อยกลางอากาศได้สูงสุดกี่หมัด (ครบแล้วกดต่อยอีกที = ทุบลง)
@export var air_rush_interval := 0.14  ## กดต่อยรัวได้เร็วสุดทุกกี่วินาที
@export var air_hold_time := 1.2       ## ไม่กดอะไรนานเท่านี้ -> ทั้งคู่ร่วงลง
@export var air_rush_damage := 8.0     ## ดาเมจต่อหมัดรัว

@export_group("Idle")
@export var idle_period := 2.4         ## วินาทีต่อ 1 loop (เด้ง 4 ครั้ง + ถ่ายน้ำหนักซ้าย-ขวา 1 รอบ)
@export var idle_crouch := 0.12        ## ย่อตัวลงกี่เมตร
@export var idle_bounce := 0.03        ## เด้งขึ้นลงกี่เมตร

@export_group("Player")
@export_range(1, 2) var player_index := 1   ## 1 = ผู้เล่น 1 (ซ้าย), 2 = ผู้เล่น 2 (ขวา)
@export var lock_on_range := 6.0       ## คู่ต่อสู้อยู่ใกล้กว่านี้ -> ออกท่าแล้วหันหาเอง

@export_group("Air Counter")            ## ตอนถูกจับลอยกลางอากาศ: กดต่อยเพื่อสวน
@export var air_stun := 0.35           ## โดนหมัดกลางอากาศแล้วมึนนานเท่านี้ก่อนสวนได้
@export var air_counter_windup := 0.2  ## ง้างหมัดสวนนานเท่านี้ (อีกฝ่ายต่อยแทรกทันจะขัดได้)
@export var air_flurry_hits := 6       ## สวนติดแล้วรัวหมัดกี่หมัด (หมัดสุดท้ายซัดร่วง)
@export var air_flurry_interval := 0.12
@export var air_flurry_damage := 12.0
@export var knockdown_time := 1.6      ## นอนกับพื้นนานเท่านี้หลังโดนทุบ/K.O. แล้วค่อยลุก

const GameState := preload("res://scripts/game_state.gd")
var char_id := "emberclaw"
var char_data := {}

## ความยาวของท่าแบบเล่นครั้งเดียว (วินาที)
const ACTION_LEN := {
	"Punch1": 0.26, "Punch2": 0.26, "Punch3": 0.47,
	"JumpKick": 0.45, "Land": 0.18, "Hit": 0.35, "HitHeavy": 0.6,
	"JumpPrep": 0.08, "BlockHit": 0.25, "DashF": 0.3, "DashB": 0.28,
	"WarpDive": 0.46, "KnockDown": 1.6, "GetUp": 1.0,
}
## จังหวะของหมัดที่ 5 (วาร์ปขึ้นฟ้าแล้วทิ่มหมัดลง 45°): หายตัว -> โผล่ลอยง้าง -> พุ่งลง -> ค้างนิดหน่อย
const WD_APPEAR := 0.06       ## โผล่หน้าศัตรู
const WD_LAUNCH_HIT := 0.17   ## อัปเปอร์คัตโดน -> ศัตรูลอยขึ้น
const WD_ENEMY_UP := 0.2      ## ศัตรูพุ่งขึ้นถึงจุดสูงสุดใช้เวลาเท่านี้
const WD_DASH_UP := 0.27      ## ผู้เล่น Dash พุ่งขึ้นตาม
const WD_DASH_END := 0.44
const WD_RUSH_START := 0.5    ## เริ่มรัวหมัดกลางอากาศ
const CAM_PIVOT_OFS := Vector3(0, 1.5, 0)
const WD_VANISH := 0.08
const WD_DIVE := 0.22
const WD_DIVE_LEN := 0.12
const LOCK_MOVE := ["Punch1", "Punch2", "Punch3", "Hit", "HitHeavy", "BlockHit", "DashF", "DashB", "KnockDown", "GetUp"]
## ความแรงพุ่งของแต่ละท่า (คูณกับ punch_lunge / kick_lunge)
const LUNGE := {"Punch1": 0.8, "Punch2": 1.0, "Punch3": 1.3}
## จังหวะที่หมัด/เท้าถึงเป้า (สัดส่วนของความยาวท่า)
const HIT_FRAC := {"Punch1": 0.3, "Punch2": 0.3, "Punch3": 0.44, "JumpKick": 0.42}
## กดต่อยซ้ำได้ก่อนท่าจบ (ตัดช่วงดึงหมัดกลับ) ให้คอมโบไหลเร็ว
const COMBO_CANCEL := 0.35
const HEAVY := ["Punch3", "JumpKick"]

const SFX := {
	"whoosh_light": preload("res://sounds/whoosh_light.wav"),
	"whoosh_heavy": preload("res://sounds/whoosh_heavy.wav"),
	"hit_light": preload("res://sounds/hit_light.wav"),
	"hit_heavy": preload("res://sounds/hit_heavy.wav"),
	"jump": preload("res://sounds/jump.wav"),
	"land": preload("res://sounds/land.wav"),
	"block": preload("res://sounds/block.wav"),
}
const STEPS := [
	preload("res://sounds/step_0.wav"), preload("res://sounds/step_1.wav"),
	preload("res://sounds/step_2.wav"), preload("res://sounds/step_3.wav"),
]

@onready var model: Node3D = $Model
const GroundImpact := preload("res://scripts/ground_impact.gd")
const SLAM_SFX := preload("res://sounds/ground_slam.wav")

var fight_cam = null                 ## กล้องรวม (fight_camera.gd)
var opponent = null                  ## ผู้เล่นอีกคน
var pfx := "p1_"                     ## คำนำหน้าชื่อปุ่ม
var controls_locked := false         ## จบยก/พักเกม -> ไม่รับปุ่ม
var frozen := false                  ## ถูกอีกฝ่ายจับลอยค้าง (ท่าหมัด 5 / อัลติเมต)
var knockdown_pending := false       ## ตกถึงพื้นแล้วล้มหงาย
var slam_pending := false            ## โดนทุบจากฟ้า -> ฝุ่น/หินกระจายแรง
var block_time := 0.0                ## (ให้เข้ากับโค้ดของอีกฝ่ายที่ตั้งค่านี้)
var cooldown := 0.0
## กล้องสั่น: เก็บไว้ที่กล้องรวม (ทั้งสองคนแชร์)
var shake: float:
	get:
		return fight_cam.shake if fight_cam else 0.0
	set(v):
		if fight_cam:
			fight_cam.shake = v

const FighterRig := preload("res://scripts/fighter_rig.gd")
const HandFire := preload("res://scripts/hand_fire.gd")
const Ultimate := preload("res://scripts/ultimate.gd")
const Voice := preload("res://scripts/voice.gd")
const Vfx := preload("res://scripts/vfx.gd")
var rig
var anim_player: AnimationPlayer
var walk_anim := ""
var run_anim := ""
var spawn_point: Vector3
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var action := ""
var action_time := 0.0
var combo_queued := false
var air_time := 0.0
var action_elapsed := 0.0
var hit_done := false
var step_timer := 0.0
var knockback := Vector3.ZERO
var is_blocking := false
var dash_dir := Vector3.ZERO
var dash_cd := 0.0
var dash_warped := false
var dash_end_pos := Vector3.ZERO
var dash_air := false
var air_dash_ready := true
var wd_top := Vector3.ZERO
var wd_end := Vector3.ZERO
var wd_face := Vector3.FORWARD
var wd_yaw := 0.0
var wd_target = null
var wd_appeared := false
var wd_dived := false
var wd_s := Vector3.FORWARD
var wd_rush := false
var wd_rush_i := -1
var wd_rush_off := Vector3.ZERO
var wd_rush_d := Vector3.FORWARD
var wd_launched := false
var wd_dash_started := false
var wd_dash_arrived := false
var wd_final_ready := false
var wd_holding := false
var wd_enemy_start := Vector3.ZERO
var wd_air_pos := Vector3.ZERO
var wd_t_final := 0.0
var wd_air_started := false
var wd_idle := 0.0
var wd_punch_t := 0.0
var wd_buffer := false
var wd_kick_buffer := false
var wd_drift := 0.0
var wd_e_stun := 0.0          # เวลาตั้งแต่ศัตรูโดนหมัดล่าสุด (มึนอยู่ = สวนไม่ได้)
var wd_counter_t := -1.0      # >= 0 = ศัตรูกำลังง้างหมัดสวน
var wd_next_roll := 0.0
var wd_flurry := false        # ศัตรูกำลังรัวหมัดสวนกลางอากาศ
var wd_flurry_t := 0.0
var wd_flurry_i := -1
var wd_flurry_hit := false
var wd_flurry_p := Vector3.ZERO
var base_fov := 70.0
var hp := 2000.0
var stamina := 100.0
var stamina_delay := 0.0
var ult_gauge := 0.0
var in_ult := false
var ult
var voice
var fire_l: Node3D
var fire_r: Node3D


func _ready() -> void:
	# ตัวละครที่เลือกจากหน้าเลือกตัวละคร: เปลี่ยนโมเดล + ค่าสถานะ + สีเอฟเฟกต์
	pfx = "p%d_" % player_index
	char_id = GameState.p1 if player_index == 1 else GameState.p2
	char_data = GameState.data(char_id)
	model = GameState.swap_model(self, model, char_id)
	hp_max = float(char_data["hp"])
	damage_light = float(char_data["atk"])
	damage_heavy = round(float(char_data["atk"]) * 1.7)
	vfx_color = char_data["vfx_color"]
	spawn_point = global_position
	# เลเยอร์ 2 = ตัวละคร (ชนกันเอง), เลเยอร์ 3 = พื้นลานเรียบ (ไม่ชนพื้นแมพที่ขรุขระ -> เดินไม่ติด)
	collision_layer = 2
	collision_mask = 2 | 4
	add_to_group("fighters")
	add_to_group("p%d" % player_index)
	hp = hp_max
	stamina = stamina_max
	GameState.setup_inputs()
	_find_refs.call_deferred()

	anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player == null:
		push_warning("ไม่พบ AnimationPlayer ในโมเดล")
		return
	for n in anim_player.get_animation_list():
		if n.to_lower().contains("walk") and not n.contains("001") and walk_anim == "":
			walk_anim = n
	if walk_anim != "":
		anim_player.get_animation(walk_anim).loop_mode = Animation.LOOP_LINEAR
	rig = FighterRig.new()
	rig.idle_period = idle_period
	rig.idle_crouch = idle_crouch
	rig.idle_bounce = idle_bounce
	for a in LUNGE:   # ระยะพุ่งรวม = ความเร็วสูงสุด * เวลาช่วงพุ่ง * 2/PI
		rig.step_dist[a] = punch_lunge * LUNGE[a] * FighterRig.LUNGE_LEN * ACTION_LEN[a] * 2.0 / PI
	rig.step_dist["DashF"] = dash_distance
	rig.step_dist["DashB"] = dash_back_distance
	if rig.setup(model, anim_player):
		rig.build_all(ACTION_LEN)
	run_anim = rig.import_anim(char_data["run_glb"], "Run")
	voice = Voice.new()
	add_child(voice)
	if player_index == 1:              # เสียงพูดตอนเริ่มเกม (คนเดียวพอ ไม่พูดซ้อนกัน)
		if GameState.game_live:
			voice.say("start", 0.8)
		elif get_parent() and get_parent().has_signal("started"):
			get_parent().started.connect(func(): voice.say("start", 0.8), CONNECT_ONE_SHOT)
	ult = Ultimate.new()
	add_child(ult)
	ult.setup(self)
	if ult_start_full:
		ult_gauge = 100.0
	if hand_fire and rig._skel:
		fire_l = _attach_fire(1)
		fire_r = _attach_fire(-1)
	_play("FightIdle", 0.0)


func _find_refs() -> void:
	fight_cam = get_tree().get_first_node_in_group("fight_camera")
	opponent = get_tree().get_first_node_in_group("p%d" % (3 - player_index))
	# ยืนหันหน้าเข้าหากันตอนเริ่ม
	if opponent:
		var to: Vector3 = opponent.global_position - global_position
		model.rotation.y = atan2(to.x, to.z)


# ---------- ปุ่ม (แยกตามผู้เล่น) ----------

func _pressed(a: String) -> bool:
	return not controls_locked and Input.is_action_just_pressed(pfx + a)


func _held(a: String) -> bool:
	return not controls_locked and Input.is_action_pressed(pfx + a)


func _move_input() -> Vector2:
	if controls_locked:
		return Vector2.ZERO
	return Input.get_vector(pfx + "move_left", pfx + "move_right", pfx + "move_forward", pfx + "move_back")


## ทิศเดินอิงกล้องรวม (หมุนรอบแกนตั้งอย่างเดียว)
func _cam_basis() -> Basis:
	if fight_cam:
		return Basis(Vector3.UP, fight_cam.global_rotation.y)
	return Basis()


func _fov_kick() -> void:
	if fight_cam:
		fight_cam.fov_kick(dash_fov_kick * 0.6)


## ทิศไปหาคู่ต่อสู้ (แนวนอน) + ระยะ
func _to_opponent() -> Vector3:
	if opponent == null or not is_instance_valid(opponent):
		return Vector3.ZERO
	var to: Vector3 = opponent.global_position - global_position
	to.y = 0.0
	return to


## ถูกจับลอยกลางอากาศแล้วกดต่อยสวน (อีกฝ่ายเรียกเช็คทุกเฟรม)
func air_counter_pressed() -> bool:
	return _pressed("punch")


func _physics_process(delta: float) -> void:
	if in_ult or frozen:
		return   # ระหว่างอัลติเมต / ถูกจับลอยค้าง -> อีกฝ่ายควบคุมตำแหน่งเอง
	if action == "WarpDive":
		_warp_dive_tick(delta)
		return
	if wd_holding:              # โดนขัดจังหวะกลางท่า -> ปล่อยคู่ต่อสู้
		_release_enemy()
	var on_floor := is_on_floor()
	if on_floor:
		air_time = 0.0
		air_dash_ready = true
	else:
		air_time += delta
		velocity.y -= gravity * (rise_gravity if velocity.y > 0.0 else fall_gravity) * delta

	# ---- ปุ่มแอคชัน ----
	dash_cd -= delta
	stamina_delay = maxf(0.0, stamina_delay - delta)
	if stamina_delay <= 0.0:
		stamina = minf(stamina_max, stamina + stamina_regen * delta)
	var can_act: bool = action == "" or action == "Land" \
		or (action.begins_with("Dash") and action_time < ACTION_LEN[action] * 0.35)
	is_blocking = _held("block") and on_floor and (can_act or action == "BlockHit")
	if _pressed("ultimate") and ult_gauge >= 100.0 and on_floor and can_act and ult.can_start():
		ult_gauge = 0.0
		ult.start()
		return
	# Dash กลางอากาศได้ 1 ครั้งต่อการกระโดด (ระหว่างลอย หรือหลังเตะโดนแล้ว)
	var air_dash_ok: bool = not on_floor and air_dash_ready \
		and (action == "" or (action == "JumpKick" and hit_done))
	if _pressed("dash") and ((on_floor and can_act) or air_dash_ok) and dash_cd <= 0.0 \
			and not action.begins_with("Dash") and stamina >= dash_cost:
		if not on_floor:
			air_dash_ready = false
		stamina -= dash_cost
		stamina_delay = 0.6
		_start_dash()
	if _pressed("jump") and on_floor and can_act and not is_blocking:
		_start_action("JumpPrep")
	if _pressed("punch") and not action.begins_with("Hit") and not is_blocking:
		if can_act and on_floor:
			_start_action("Punch1")
		elif action in ["Punch1", "Punch2", "Punch3", "JumpKick"]:
			combo_queued = true
	if _pressed("kick") and can_act and not is_blocking:
		if on_floor:
			velocity.y = jump_velocity * kick_jump
			air_time = 0.2
			_sfx("jump", -6.0)
		_start_action("JumpKick")

	if action != "":
		action_elapsed += delta
		if not hit_done and action in HIT_FRAC and action_elapsed >= HIT_FRAC[action] * ACTION_LEN[action]:
			hit_done = true
			_try_hit()
		action_time -= delta
		var cancel_ok: bool = hit_done and action_time <= ACTION_LEN[action] * COMBO_CANCEL
		if combo_queued and cancel_ok and action == "Punch1":
			combo_queued = false
			_start_action("Punch2")
		elif combo_queued and cancel_ok and action == "Punch2":
			combo_queued = false
			_start_action("Punch3")
		elif combo_queued and cancel_ok and action == "Punch3":
			# จังหวะที่ 4: กระโดดเตะต่อจากอัปเปอร์คัต
			combo_queued = false
			velocity.y = jump_velocity * kick_jump
			air_time = 0.2
			_sfx("jump", -6.0)
			_start_action("JumpKick")
		elif combo_queued and action == "JumpKick" and hit_done \
				and action_elapsed >= HIT_FRAC["JumpKick"] * ACTION_LEN["JumpKick"] + 0.05:
			# จังหวะที่ 5: วาร์ปขึ้นเหนือหัวศัตรูแล้วทิ่มหมัดลง
			_start_warp_dive()
			return
		elif action_time <= 0.0 and action == "KnockDown":
			_start_action("GetUp")
		elif action_time <= 0.0:
			if action.begins_with("Dash"):
				dash_cd = dash_cooldown
			if action == "JumpPrep":
				velocity.y = jump_velocity
				air_time = 0.2
				on_floor = false
				_play("JumpUp", 0.05, 1.0, true)
				_sfx("jump", -6.0)
			action = ""
			combo_queued = false

	# ---- เคลื่อนที่ (อิงทิศกล้อง) ----
	var input := _move_input()
	var dir := _cam_basis() * Vector3(input.x, 0, input.y)
	dir.y = 0
	dir = dir.normalized()
	var running := _held("run")
	var speed := run_speed if running else walk_speed
	if action in LOCK_MOVE or is_blocking:
		speed = 0.0
	elif action == "Land" or action == "JumpPrep":
		speed *= 0.4

	var lunge := _lunge_speed()
	if knockback.length() > 0.05:
		velocity.x = knockback.x
		velocity.z = knockback.z
		knockback = knockback.move_toward(Vector3.ZERO, 14.0 * delta)
	elif action.begins_with("Dash"):
		# ออกตัวแรงแล้วเบรก: v ~ (1-t)^1.5, ระยะรวม = v0 * len / 2.5
		var t01 := 1.0 - action_time / float(ACTION_LEN[action])
		var dist := dash_distance if action == "DashF" else dash_back_distance
		var v0 := 2.5 * dist / float(ACTION_LEN[action])
		var v := v0 * pow(1.0 - clampf(t01, 0.0, 1.0), 1.5)
		velocity.x = dash_dir.x * v
		velocity.z = dash_dir.z * v
		if dash_air:
			velocity.y = 0.0          # dash กลางอากาศ: พุ่งตรงไม่ตก
	elif lunge > 0.0:
		var fwd := model.global_basis.z
		fwd.y = 0
		fwd = fwd.normalized()
		velocity.x = fwd.x * lunge
		velocity.z = fwd.z * lunge
	elif dir != Vector3.ZERO and speed > 0.0:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), turn_speed * delta)
	elif on_floor:
		velocity.x = move_toward(velocity.x, 0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 20.0 * delta)
	# ยืนเฉยๆ / บล็อก -> หันหน้าหาคู่ต่อสู้เอง (ล็อกเป้าแบบเกมต่อสู้ 3D)
	var to_opp := _to_opponent()
	if (action == "" or action == "BlockHit") and (dir == Vector3.ZERO or is_blocking) and to_opp.length() > 0.2 \
			and knockback.length() <= 0.05:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(to_opp.x, to_opp.z), turn_speed * 0.6 * delta)

	# ระหว่าง Dash ตัวละครหายไป (เหมือนวาร์ป) แล้วโผล่พร้อมเอฟเฟกต์ที่ปลายทาง
	if action.begins_with("Dash"):
		var dt01 := 1.0 - action_time / float(ACTION_LEN[action])
		model.visible = dt01 < 0.14 or dt01 > 0.72
		if not dash_warped and dt01 > 0.72:
			dash_warped = true
			var c2 := global_position + Vector3.UP * 1.0
			Vfx.ring(self, c2, -dash_dir, Color(vfx_color.r, vfx_color.g, vfx_color.b, 0.7), 0.25, 1.3, 0.26)
			Vfx.sparks(self, c2, vfx_color, 6, 3.5)
			if fire_l:
				fire_l.boost(0.8)
				fire_r.boost(0.8)
	elif not model.visible:
		model.visible = true
	# คืนตัวให้ตั้งตรงหลังท่าทิ่มหมัดเอียงตัว
	if absf(model.rotation.x) > 0.001:
		model.rotation.x = lerpf(model.rotation.x, 0.0, clampf(12.0 * delta, 0.0, 1.0))

	var was_air := air_time
	move_and_slide()
	_confine_to_arena(delta)

	# ตกถึงพื้นหลังโดนทุบ / K.O. -> ล้มหงาย + ฝุ่น/หินกระจาย
	if knockdown_pending and is_on_floor() and was_air > 0.1:
		knockdown_pending = false
		_start_action("KnockDown")
		action_time = knockdown_time
		_sfx("land", 2.0, 0.8)
		GroundImpact.spawn(self, global_position, 1.0 if slam_pending else 0.45)
		if slam_pending:
			_sfx_stream(SLAM_SFX, 4.0, randf_range(0.95, 1.05))
		shake = maxf(shake, 1.1 if slam_pending else 0.5)
		slam_pending = false
	# ลงพื้นหลังลอยนาน -> ท่า Land
	elif is_on_floor() and was_air > 0.25 and (action == "" or action == "JumpKick"):
		_start_action("Land")
		_sfx("land", -3.0)

	# เสียงเท้า
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.8 and action == "":
		step_timer -= delta
		if step_timer <= 0.0:
			step_timer = 0.34 if running else 0.48
			_sfx_stream(STEPS.pick_random(), -10.0 if not running else -6.0, randf_range(0.9, 1.1))
	else:
		step_timer = 0.1

	# ---- เลือกแอนิเมชันเมื่อไม่มีแอคชัน ----
	if action == "":
		if not is_on_floor() and air_time > 0.1:
			_play("JumpUp" if velocity.y > 0.5 else "JumpFall", 0.12)
		elif is_blocking:
			_play("Block", 0.08)
		elif dir != Vector3.ZERO:
			if running and run_anim != "":
				_play(run_anim, 0.2, run_anim_speed)
			else:
				_play(walk_anim, 0.2, walk_anim_speed)
		else:
			_play("FightIdle", 0.3)

	if global_position.y < respawn_height:
		global_position = spawn_point
		velocity = Vector3.ZERO


## กันไม่ให้ออกนอกวงกลมกลางลาน (ถ้าถูกท่าอัลติเมตพาออกไป จะค่อยๆ เลื่อนกลับเข้ามา)
func _confine_to_arena(delta: float) -> void:
	var h := Vector2(global_position.x, global_position.z)
	var d := h.length()
	if d <= arena_radius or d < 0.001:
		return
	var n := h / d
	var edge := n * arena_radius
	if d > arena_radius + 0.6:
		h = h.move_toward(edge, 10.0 * delta)
	else:
		h = edge
	global_position.x = h.x
	global_position.z = h.y
	var outv := velocity.x * n.x + velocity.z * n.y
	if outv > 0.0:
		velocity.x -= outv * n.x
		velocity.z -= outv * n.y
	var outk := knockback.x * n.x + knockback.z * n.y
	if outk > 0.0:
		knockback.x -= outk * n.x
		knockback.z -= outk * n.y


## ความเร็วพุ่งไปข้างหน้าของท่าที่กำลังเล่น: พุ่งแรงช่วงต้นท่าแล้วค่อยๆ หยุด
func _lunge_speed() -> float:
	if action == "":
		return 0.0
	var t01 := 1.0 - action_time / float(ACTION_LEN[action])
	if action in LUNGE:
		return punch_lunge * LUNGE[action] * sin(PI * FighterRig.lunge_k(action, t01))
	if action == "JumpKick":
		return kick_lunge * (1.0 - smoothstep(0.5, 1.0, t01))
	return 0.0


func _start_action(a: String) -> void:
	# ออกท่าโจมตี: คู่ต่อสู้อยู่ใกล้ -> หันหาเอง, ไม่งั้นหันตามทิศที่กดค้าง
	if a in HIT_FRAC:
		var to_opp := _to_opponent()
		var input := _move_input()
		if to_opp.length() > 0.1 and to_opp.length() <= lock_on_range:
			model.rotation.y = atan2(to_opp.x, to_opp.z)
		elif input != Vector2.ZERO:
			var d := _cam_basis() * Vector3(input.x, 0, input.y)
			model.rotation.y = atan2(d.x, d.z)
	action = a
	action_time = ACTION_LEN[a]
	action_elapsed = 0.0
	hit_done = false
	if a in HIT_FRAC:
		_punch_vfx(a)
	if a in HIT_FRAC and fire_l:
		match a:
			"Punch1": fire_l.boost(1.0)
			"Punch2": fire_r.boost(1.0)
			"Punch3": fire_r.boost(2.5)
			"JumpKick":
				fire_l.boost(0.6)
				fire_r.boost(0.6)
	if a in HIT_FRAC:
		_sfx("whoosh_heavy" if a in HEAVY else "whoosh_light", -4.0, randf_range(0.92, 1.08))
	_play(a, 0.05, 1.0, true)


func _play(anim_name: String, blend: float, speed := 1.0, restart := false) -> void:
	if anim_player == null or anim_name == "" or not anim_player.has_animation(anim_name):
		return
	if restart or anim_player.assigned_animation != anim_name or not anim_player.is_playing() and anim_player.get_animation(anim_name).loop_mode != Animation.LOOP_NONE:
		anim_player.play(anim_name, blend, speed)
		if restart:
			anim_player.seek(0.0, true)


# ---------- ต่อยโดน / เอฟเฟกต์ ----------

func _try_hit() -> void:
	var fwd := model.global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var heavy := action in HEAVY
	var reach := hit_range + (0.3 if action == "JumpKick" else 0.0)
	for e in ([opponent] if opponent and is_instance_valid(opponent) else []):
		var to: Vector3 = e.global_position - global_position
		to.y = 0
		if to.length() > reach or fwd.dot(to.normalized()) < 0.35:
			continue
		var dmg: float = damage_heavy if heavy else damage_light
		var blocked: bool = e.take_hit(fwd, heavy, dmg)
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and not blocked:
			hud.add_combo(player_index)
		ult_gauge = minf(100.0, ult_gauge + (3.0 if blocked else (ult_gain_heavy if heavy else ult_gain_hit)))
		if not blocked:
			var hit_pos: Vector3 = e.global_position + Vector3.UP * 1.25 - fwd * 0.2
			Vfx.ring(self, hit_pos, fwd, vfx_color, 0.2, 1.5 if heavy else 0.9, 0.25)
			Vfx.sparks(self, hit_pos, vfx_color, 8 if heavy else 5, 5.0 if heavy else 3.5)
		if blocked:
			shake = maxf(shake, shake_light * 0.6)
			_hitstop(hitstop_light * 0.7)
		else:
			shake = maxf(shake, shake_heavy if heavy else shake_light)
			_hitstop(hitstop_heavy if heavy else hitstop_light)


## หยุดเวลาชั่วขณะให้รู้สึกถึงแรงกระแทก
func _hitstop(duration: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


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


## ถูกศัตรูต่อย: ยกเลิกท่าที่ทำอยู่ + กระเด็น + ท่าโดนต่อย + เสียง + กล้องสั่น
func take_hit(dir: Vector3, heavy: bool, damage := 0.0) -> bool:
	if in_ult:
		return true
	if action == "KnockDown" or action == "GetUp":
		return false   # ล้มอยู่ ตีไม่โดน
	# บล็อกได้เฉพาะการโจมตีจากด้านหน้า
	if is_blocking and model.global_basis.z.dot(-dir) > 0.3:
		var sp: Vector3 = global_position + Vector3.UP * 1.15 - dir * 0.75
		Vfx.shield(self, sp, -dir, Color(0.55, 0.8, 1.0), 1.5 if heavy else 1.2)
		Vfx.sparks(self, sp, Color(0.8, 0.92, 1.0), 14, 6.0)
		knockback = dir * (3.0 if heavy else 1.2)
		_start_action("BlockHit")
		_sfx("block", 0.0, randf_range(0.9, 1.1) * (0.85 if heavy else 1.0))
		shake = maxf(shake, shake_light * 0.7)
		_hitstop(hitstop_light * 0.7)
		_damage(damage * 0.2)          # บล็อกได้ เสียเลือดนิดหน่อย
		return true
	combo_queued = false
	_damage(damage)
	ult_gauge = minf(100.0, ult_gauge + ult_gain_hurt)
	knockback = dir * (6.0 if heavy else 2.5)
	if heavy:
		velocity.y = 3.0
	model.rotation.y = atan2(-dir.x, -dir.z)
	_start_action("HitHeavy" if heavy else "Hit")
	_sfx("hit_heavy" if heavy else "hit_light", 0.0, randf_range(0.8, 0.95))
	shake = maxf(shake, (shake_heavy if heavy else shake_light) * 1.3)
	_hitstop(hitstop_heavy if heavy else hitstop_light)
	return false


# ---------- Dash ----------

func _start_dash() -> void:
	var input := _move_input()
	var facing := model.global_basis.z
	facing.y = 0
	facing = facing.normalized()
	var to_opp := _to_opponent()
	if to_opp.length() > 0.2 and to_opp.length() < 12.0:
		facing = to_opp.normalized()           # ไม่กดทิศ = Dash เข้าหาคู่ต่อสู้
		model.rotation.y = atan2(facing.x, facing.z)
	var d := facing
	if input != Vector2.ZERO:
		d = _cam_basis() * Vector3(input.x, 0, input.y)
		d.y = 0
		d = d.normalized()
	combo_queued = false
	dash_air = not is_on_floor()
	if dash_air:
		velocity.y = 0.0
	if d.dot(facing) < -0.3:
		dash_dir = d                     # ถอยหลบ: หันหน้าเดิม (ยังมองคู่ต่อสู้)
		_start_action("DashB")
	else:
		dash_dir = d
		model.rotation.y = atan2(d.x, d.z)
		_start_action("DashF")
	_sfx("whoosh_light", -3.0, 0.7)
	_fov_kick()
	# วาร์ป: ระเบิดพลังที่จุดออกตัว + ลำแสงไปยังจุดปลายทาง
	var dist: float = dash_distance if action == "DashF" else dash_back_distance
	dash_end_pos = global_position + dash_dir * dist
	dash_warped = false
	var c := global_position + Vector3.UP * 1.0
	Vfx.ring(self, c, dash_dir, Color(vfx_color.r, vfx_color.g, vfx_color.b, 0.7), 0.25, 1.4, 0.3)
	Vfx.sparks(self, c, vfx_color, 7, 4.0)
	Vfx.streak(self, c, dash_end_pos + Vector3.UP * 1.0, vfx_color, 0.45, 0.22)
	# เส้นความเร็วตามแนววาร์ป
	Vfx.speed_lines(self, c, dash_end_pos + Vector3.UP * 1.0, Color(1, 1, 1, 0.9), 14, 0.6, 0.035, 0.3)
	Vfx.speed_lines(self, c, dash_end_pos + Vector3.UP * 1.0, vfx_color, 8, 0.85, 0.05, 0.32)


# ---------- หมัดที่ 5: วาร์ปเสยศัตรูขึ้นฟ้า -> รัวหมัดกลางอากาศ -> ทิ่มหมัดลงให้ร่วง ----------

func _start_warp_dive() -> void:
	combo_queued = false
	var fwd := model.global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	# เป้าคือคู่ต่อสู้ถ้าอยู่ใกล้ (ไม่มี = ทิ่มลงข้างหน้าเฉยๆ)
	wd_target = null
	if opponent and is_instance_valid(opponent) and (opponent.global_position - global_position).length() < 7.0 \
			and not opponent.in_ult:
		wd_target = opponent
	var ep: Vector3 = global_position + fwd * 2.0
	if wd_target:
		ep = wd_target.global_position
	var s := ep - global_position
	s.y = 0
	if s.length() < 0.1:
		s = fwd
	wd_s = s.normalized()
	wd_face = -wd_s
	wd_yaw = atan2(wd_face.x, wd_face.z)
	wd_rush = wd_target != null and not (wd_target.action in ["KnockDown", "GetUp"])
	wd_rush_i = -1
	wd_launched = false
	wd_dash_started = false
	wd_dash_arrived = false
	wd_appeared = false
	wd_dived = false
	wd_final_ready = false
	if wd_rush:
		var ground_y := _ground_below(ep)
		wd_enemy_start = ep
		wd_air_pos = Vector3(ep.x, ground_y + air_rush_height, ep.z)
		wd_t_final = 1.0e9                     # รอผู้เล่นกด K / ต่อยครบ ค่อยกำหนด
		wd_air_started = false
		wd_buffer = false
		wd_kick_buffer = false
		wd_drift = 0.0
		wd_flurry = false
		wd_target.frozen = true                 # จับศัตรูลอยค้างไว้ระหว่างรัวหมัด
		wd_target.velocity = Vector3.ZERO
		wd_target.knockback = Vector3.ZERO
		wd_target.is_blocking = false
		wd_target.block_time = 0.0
		wd_holding = true
	else:
		wd_t_final = 0.0
		_setup_final_dive(ep)
	action = "WarpDive"
	action_time = wd_t_final + WD_DIVE + WD_DIVE_LEN + 0.12
	action_elapsed = 0.0
	hit_done = false
	velocity = Vector3.ZERO
	knockback = Vector3.ZERO
	model.visible = false
	var c := global_position + Vector3.UP * 1.0
	Vfx.ring(self, c, wd_s, Color(vfx_color.r, vfx_color.g, vfx_color.b, 0.7), 0.25, 1.4, 0.3)
	Vfx.sparks(self, c, vfx_color, 7, 4.0)
	_sfx("whoosh_light", -3.0, 0.75)
	_fov_kick()


## ตำแหน่งท่าทิ่มหมัดสุดท้าย: โผล่เหนือหัวด้านหลังศัตรู แล้วพุ่งลงเป็นแนว warp_dive_angle
func _setup_final_dive(ep: Vector3) -> void:
	var tilt := deg_to_rad(warp_dive_angle)
	var drop := 1.05
	var run := drop / tan(tilt)
	var off := (wd_face * sin(tilt) + Vector3.UP * cos(tilt)) * 0.73   # ตัวหมุนรอบเท้า -> ชดเชยให้สะโพกอยู่ตรงจุด
	var hip_end := ep + wd_s * 0.55 + Vector3.UP * 1.55
	var hip_top := hip_end + wd_s * run + Vector3.UP * drop
	wd_top = hip_top - off
	wd_end = hip_end - off
	wd_final_ready = true


func _ground_below(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, p + Vector3.DOWN * 30.0)
	q.collision_mask = 4                     # พื้นลานเรียบ (ที่ตัวละครยืนอยู่จริง)
	var ex: Array[RID] = [get_rid()]
	if wd_target:
		ex.append(wd_target.get_rid())
	q.exclude = ex
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r.position.y if r else p.y


## ตำแหน่งเท้าศัตรูตอนลอยอยู่ (ลอยขึ้นช้าๆ ระหว่างโดนรัว)
func _enemy_air_pos(t: float) -> Vector3:
	var k := clampf((t - WD_LAUNCH_HIT) / WD_ENEMY_UP, 0.0, 1.0)
	k = 1.0 - pow(1.0 - k, 3.0)
	return wd_enemy_start.lerp(wd_air_pos, k) + Vector3.UP * wd_drift


func _warp_dive_tick(delta: float) -> void:
	action_elapsed += delta
	action_time -= delta
	var t := action_elapsed
	var e = wd_target
	var e_ok: bool = wd_rush and e != null and is_instance_valid(e)
	var tilt := deg_to_rad(warp_dive_angle)

	# ศัตรูลอยค้างจนกว่าจะโดนหมัดสุดท้าย
	if e_ok and wd_holding and not wd_flurry:
		e.global_position = _enemy_air_pos(t)

	if e_ok and t < wd_t_final:
		if t < WD_APPEAR:
			model.visible = false
			return
		# ---- จังหวะเสย: โผล่หน้าศัตรูแล้วอัปเปอร์คัตส่งขึ้นฟ้า -> Dash พุ่งขึ้นตาม ----
		if t < WD_RUSH_START:
			var front: Vector3 = wd_enemy_start - wd_s * 0.9
			var air_front: Vector3 = e.global_position - wd_s * 0.9
			if t >= WD_DASH_UP:
				var u := clampf((t - WD_DASH_UP) / (WD_DASH_END - WD_DASH_UP), 0.0, 1.0)
				if not wd_dash_started:
					wd_dash_started = true
					_play("DashF", 0.02, 1.3, true)
					_sfx("whoosh_light", -2.0, 0.65)
					_fov_kick()
					var c0 := front + Vector3.UP * 1.0
					var c1 := air_front + Vector3.UP * 1.0
					Vfx.ring(self, c0, Vector3.UP, Color(vfx_color.r, vfx_color.g, vfx_color.b, 0.7), 0.25, 1.4, 0.3)
					Vfx.sparks(self, c0, vfx_color, 7, 4.0)
					Vfx.streak(self, c0, c1, vfx_color, 0.45, 0.22)
					Vfx.speed_lines(self, c0, c1, Color(1, 1, 1, 0.9), 14, 0.6, 0.035, 0.3)
					Vfx.speed_lines(self, c0, c1, vfx_color, 8, 0.85, 0.05, 0.32)
					if fire_l:
						fire_l.boost(1.5)
						fire_r.boost(1.5)
				# ออกตัวแรงแล้วเบรก เหมือน Dash บนพื้น, หายตัวช่วงกลาง
				var k := 1.0 - pow(1.0 - u, 2.5)
				global_position = front.lerp(air_front, k)
				model.visible = u < 0.15 or u > 0.7
				if u >= 1.0 and not wd_dash_arrived:
					wd_dash_arrived = true
					var c2 := air_front + Vector3.UP * 1.0
					Vfx.ring(self, c2, Vector3.DOWN, Color(vfx_color.r, vfx_color.g, vfx_color.b, 0.7), 0.25, 1.3, 0.26)
					Vfx.sparks(self, c2, vfx_color, 6, 3.5)
					_play("JumpUp", 0.05, 1.0, true)
				return
			if not wd_appeared:
				wd_appeared = true
				model.visible = true
				model.rotation = Vector3(0.0, atan2(wd_s.x, wd_s.z), 0.0)
				_play("Punch3", 0.02, 1.6, true)
				Vfx.sparks(self, front + Vector3.UP, vfx_color, 8, 4.0)
				if fire_r:
					fire_r.boost(2.5)
			global_position = front
			if not wd_launched and t >= WD_LAUNCH_HIT:
				wd_launched = true
				_rush_hit(e, wd_s, true)
			return
		# ---- ลอยค้างกลางอากาศ: ผู้เล่นกดต่อยเองทีละหมัด ----
		if not wd_air_started:
			wd_air_started = true
			wd_rush_off = -wd_s * 0.9
			wd_e_stun = -0.25                      # เพิ่งโดนเสยมา มึนนานกว่าปกติ
			wd_counter_t = -1.0
			wd_next_roll = 0.0
			wd_idle = 0.0
			wd_punch_t = 99.0
			_play("FightIdle", 0.12)
		# กล้องสั่นเบาๆ ตลอดเวลาที่สู้กันอยู่กลางอากาศ
		shake = maxf(shake, 0.4)
		if wd_flurry:
			_flurry_tick(e, delta)
			return
		wd_idle += delta
		wd_punch_t += delta
		if _pressed("punch"):
			wd_buffer = true
		if _pressed("kick"):
			wd_kick_buffer = true
		if wd_buffer and wd_punch_t >= air_rush_interval:
			wd_buffer = false
			if wd_rush_i + 1 >= air_rush_hits:
				wd_kick_buffer = true              # ต่อยครบแล้ว หมัดถัดไป = ทุบลง
			else:
				wd_rush_i += 1
				wd_punch_t = 0.0
				wd_idle = 0.0
				_rush_warp(e, wd_rush_i)
		if wd_rush_i >= 0 and not hit_done and wd_punch_t >= 0.06:
			hit_done = true
			_rush_hit(e, wd_rush_d, false)
		# ---- ศัตรูต่อยสวนกลางอากาศ ----
		wd_e_stun += delta
		if wd_counter_t >= 0.0:
			wd_counter_t += delta
			var to_p: Vector3 = global_position - e.global_position
			to_p.y = 0
			if to_p.length() > 0.05:
				e.model.rotation.y = atan2(to_p.x, to_p.z)
			if wd_counter_t >= _e_param(e, "air_counter_windup", 0.2):
				_start_flurry(e)
				return
		elif wd_e_stun >= _e_param(e, "air_stun", 0.35) and e.has_method("air_counter_pressed") and e.air_counter_pressed():
			_start_air_counter(e)                   # อีกฝ่ายกดต่อยสวน (หลังหายมึน)
		# ศัตรูลอยสูงขึ้นทีละนิดตามจำนวนหมัด
		wd_drift = move_toward(wd_drift, 0.035 * (wd_rush_i + 1), delta * 0.6)
		# ว่างอยู่ -> กลับท่าตั้งการ์ดลอยกลางอากาศ
		if wd_punch_t > 0.3 and wd_punch_t - delta <= 0.3:
			_play("FightIdle", 0.15)
		if wd_punch_t > 0.3:
			model.rotation.x = lerpf(model.rotation.x, 0.0, clampf(8.0 * delta, 0.0, 1.0))
		global_position = e.global_position + wd_rush_off
		if wd_kick_buffer and wd_punch_t >= 0.1:
			wd_kick_buffer = false
			wd_t_final = t                          # เริ่มท่าทุบลง
			action_time = WD_DIVE + WD_DIVE_LEN + 0.12
		elif wd_idle > air_hold_time:
			_air_drop(e)                            # ไม่กดต่อ -> ร่วงลงทั้งคู่
		return

	# ---- หมัดสุดท้าย: วาร์ปไปเหนือหัวด้านหลัง ลอยง้าง แล้วทิ่มลง 45° ----
	var f := t - wd_t_final
	if not wd_final_ready:
		_setup_final_dive(e.global_position if e_ok else global_position + wd_s * 2.0)
		hit_done = false
		wd_appeared = false
		model.visible = false
		Vfx.sparks(self, global_position + Vector3.UP, vfx_color, 6, 4.0)
		_sfx("whoosh_light", -3.0, 0.9)
	if f < WD_VANISH:
		model.visible = false
		return
	if not wd_appeared:
		wd_appeared = true
		global_position = wd_top
		model.visible = true
		model.rotation = Vector3(tilt * 0.35, wd_yaw, 0.0)
		_play("JumpUp", 0.03, 1.0, true)
		var c := wd_top + Vector3.UP * 0.8
		Vfx.ring(self, c, wd_face, Color(vfx_color.r, vfx_color.g, vfx_color.b, 0.7), 0.25, 1.3, 0.26)
		Vfx.sparks(self, c, vfx_color, 8, 4.0)
		if fire_l:
			fire_l.boost(1.0)
			fire_r.boost(2.5)
	if f < WD_DIVE:
		var h := (f - WD_VANISH) / (WD_DIVE - WD_VANISH)
		global_position = wd_top + Vector3.UP * 0.1 * sin(PI * 0.5 * h)
		model.rotation = Vector3(lerpf(tilt * 0.35, tilt * 0.15, h), wd_yaw, 0.0)
	elif f < WD_DIVE + WD_DIVE_LEN:
		if not wd_dived:
			wd_dived = true
			_play("AirPunch1", 0.03, 1.2, true)
			_sfx("whoosh_heavy", -2.0, 0.9)
			if fire_l:
				fire_l.boost(3.0)
		var u := clampf((f - WD_DIVE) / WD_DIVE_LEN, 0.0, 1.0)
		model.rotation = Vector3(tilt, wd_yaw, 0.0)
		global_position = (wd_top + Vector3.UP * 0.1).lerp(wd_end, pow(u, 1.3))
		if not hit_done and u >= 0.7:
			_warp_dive_hit()
	else:
		global_position = wd_end
		model.rotation.x = tilt
	if action_time <= 0.0:
		action = ""
		velocity = -wd_face * 1.6 + Vector3.UP * 1.8     # เด้งกลับหลังกระแทก แล้วตกลงพื้น
		air_time = 0.3
		_release_enemy()
		_restore_camera()


## วาร์ปไปจุดถัดไปรอบตัวศัตรู: คู่ = ระดับเดียวกัน (หมัดตรง), คี่ = ลอยเหนือหัวเอียงทิ่มลง
func _rush_warp(e, i: int) -> void:
	var right := wd_s.cross(Vector3.UP).normalized()
	var dirs := [-wd_s, right, wd_s, -right, (-wd_s + right).normalized(), (wd_s + right).normalized(),
		(wd_s - right).normalized(), (-wd_s - right).normalized()]
	var d: Vector3 = dirs[i % dirs.size()]
	var high := i % 2 == 1
	var tilt := deg_to_rad(warp_dive_angle)
	var face := -d
	var yaw := atan2(face.x, face.z)
	var old := global_position
	if high:
		var hip: Vector3 = d * 0.85 + Vector3.UP * 1.65
		wd_rush_off = hip - (face * sin(tilt) + Vector3.UP * cos(tilt)) * 0.73
		model.rotation = Vector3(tilt, yaw, 0.0)
	else:
		wd_rush_off = d * 0.95
		model.rotation = Vector3(0.0, yaw, 0.0)
	wd_rush_d = face
	hit_done = false
	global_position = e.global_position + wd_rush_off
	model.visible = true
	_play("AirPunch1" if i % 2 == 0 else "AirPunch2", 0.02, 1.6, true)
	var fire = fire_l if i % 2 == 0 else fire_r
	if fire:
		fire.boost(1.8)
	var c := global_position + Vector3.UP * 1.0
	Vfx.sparks(self, old + Vector3.UP * 1.0, vfx_color, 5, 3.0)
	Vfx.speed_lines(self, old + Vector3.UP * 1.0, c, Color(1, 1, 1, 0.8), 8, 0.5, 0.03, 0.2)
	_sfx("whoosh_light", -6.0, randf_range(1.15, 1.45))


## หมัดระหว่างรัว (launch = อัปเปอร์คัตเปิดฉาก)
func _rush_hit(e, dir: Vector3, launch: bool) -> void:
	wd_e_stun = 0.0
	if wd_counter_t >= 0.0:
		wd_counter_t = -1.0                        # ต่อยแทรกทัน = ขัดหมัดสวนของศัตรู
		Vfx.ring(self, e.global_position + Vector3.UP * 1.3, dir, Color(1, 1, 1, 0.8), 0.3, 1.8, 0.2)
	e.is_blocking = false
	e.block_time = 0.0
	e.take_hit(dir, launch, air_rush_damage * (1.5 if launch else 1.0))
	e.velocity = Vector3.ZERO
	e.knockback = Vector3.ZERO
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.add_combo(player_index)
	ult_gauge = minf(100.0, ult_gauge + ult_gain_hit * 0.5)
	var hit_pos: Vector3 = e.global_position + Vector3.UP * 1.3 - dir * 0.2
	Vfx.ring(self, hit_pos, dir, vfx_color, 0.2, 1.3 if launch else 0.9, 0.22)
	Vfx.sparks(self, hit_pos, vfx_color, 8 if launch else 5, 4.5)
	shake = maxf(shake, shake_heavy * (1.3 if launch else 1.0))
	_hitstop(hitstop_heavy if launch else 0.045)


func _warp_dive_hit() -> void:
	hit_done = true
	var e = wd_target
	if e == null or not is_instance_valid(e):
		return
	var to: Vector3 = e.global_position - global_position
	to.y = 0
	if to.length() > 2.2:
		return                                 # ศัตรูหลบไปแล้ว
	if not wd_holding and "action" in e and (e.action == "KnockDown" or e.action == "GetUp"):
		return
	var dir := wd_face
	e.is_blocking = false
	var blocked: bool = e.take_hit(dir, true, warp_dive_damage)
	_release_enemy()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and not blocked:
		hud.add_combo(player_index)
	ult_gauge = minf(100.0, ult_gauge + ult_gain_heavy)
	if not blocked:
		if "knockdown_pending" in e:
			e.knockdown_pending = true          # ทิ่มลงกระแทกพื้น -> ล้ม
		if wd_rush and "slam_pending" in e:
			e.slam_pending = true               # ตกถึงพื้น = ฝุ่นตลบ หินกระเด็น
		e.knockback = dir * 3.5
		e.velocity.y = -11.0 if wd_rush else 2.2    # ทุบร่วงจากฟ้า
		var hit_pos: Vector3 = e.global_position + Vector3.UP * 1.4
		Vfx.ring(self, hit_pos, (dir + Vector3.DOWN).normalized(), vfx_color, 0.25, 2.0, 0.3)
		Vfx.sparks(self, hit_pos, vfx_color, 12, 6.0)
	shake = maxf(shake, shake_heavy * 1.25)
	_hitstop(hitstop_heavy * 1.3)


## ปล่อยให้ทั้งคู่ร่วงลงเอง (ผู้เล่นไม่กดต่อ)
func _air_drop(e) -> void:
	_release_enemy()
	if "knockdown_pending" in e:
		e.knockdown_pending = false            # ตีไม่ครบ = ศัตรูตกลงมายืนได้ ไม่ล้ม
	e.action = ""
	e.velocity = Vector3(0, -1.0, 0)
	e.knockback = Vector3.ZERO
	action = ""
	velocity = Vector3.ZERO
	air_time = 0.3
	_restore_camera()


func _e_param(e, pname: String, def: float) -> float:
	return float(e.get(pname)) if pname in e else def


## ศัตรูเริ่มง้างหมัดสวน (มีสัญญาณเตือน: ไฟสีฟ้าที่มือ + ประกาย)
func _start_air_counter(e) -> void:
	wd_counter_t = 0.0
	var wind: float = _e_param(e, "air_counter_windup", 0.2)
	if e.anim_player and e.anim_player.has_animation("AirPunch1"):
		# เล่นช้าให้จังหวะหมัดยืดสุดตรงกับตอนง้างเสร็จ
		e.anim_player.play("AirPunch1", 0.05, 0.08 / maxf(wind, 0.05))
		e.anim_player.seek(0.0, true)
	if "fire_r" in e and e.fire_r:
		e.fire_r.boost(3.0)
	var c: Vector3 = e.global_position + Vector3.UP * 1.3
	Vfx.sparks(self, c, e.vfx_color if "vfx_color" in e else Color(0.4, 0.75, 1.0), 10, 3.0)
	Vfx.ring(self, c, Vector3.UP, Color(0.5, 0.8, 1.0, 0.7), 0.2, 1.2, 0.2)


## ศัตรูต่อยสวนโดน: ผู้เล่นกระเด็นร่วงลง ศัตรูหลุดจากการจับแล้วตกลงมายืน
## ศัตรูสวนติด: วาร์ปรอบตัวผู้เล่นแล้วรัวหมัด (ผู้เล่นมึนลอยค้าง) หมัดสุดท้ายซัดร่วง
func _start_flurry(e) -> void:
	wd_counter_t = -1.0
	wd_flurry = true
	wd_flurry_t = 0.0
	wd_flurry_i = -1
	wd_flurry_hit = true
	wd_flurry_p = e.global_position - wd_s * 0.9      # ลอยระดับเดียวกับศัตรู
	global_position = wd_flurry_p
	wd_buffer = false
	wd_kick_buffer = false
	model.visible = true
	model.rotation.x = 0.0
	_play("Hit", 0.03, 1.2, true)


func _flurry_tick(e, delta: float) -> void:
	wd_flurry_t += delta
	global_position = wd_flurry_p
	# ปุ่มที่กดระหว่างโดนรัว = ไม่มีผล (มึนอยู่)
	var n := int(_e_param(e, "air_flurry_hits", 6))
	var iv := _e_param(e, "air_flurry_interval", 0.12)
	var want := int(wd_flurry_t / iv)
	if want > wd_flurry_i:
		wd_flurry_i = want
		if wd_flurry_i >= n:
			wd_flurry = false
			_air_countered(e)                    # หมัดสุดท้าย: ซัดผู้เล่นกระเด็นร่วง
			return
		_enemy_rush_warp(e, wd_flurry_i)
		wd_flurry_hit = false
	if not wd_flurry_hit and wd_flurry_t - wd_flurry_i * iv >= 0.045:
		wd_flurry_hit = true
		_enemy_rush_hit(e)


## ศัตรูวาร์ปไปจุดถัดไปรอบตัวผู้เล่น (เหมือนที่ผู้เล่นทำ) แล้วง้างต่อย
func _enemy_rush_warp(e, i: int) -> void:
	var right := wd_s.cross(Vector3.UP).normalized()
	var dirs := [wd_s, -right, -wd_s, right, (wd_s + right).normalized(), (-wd_s - right).normalized(),
		(wd_s - right).normalized(), (-wd_s + right).normalized()]
	var d: Vector3 = dirs[i % dirs.size()]
	var old: Vector3 = e.global_position
	var np: Vector3 = wd_flurry_p + d * 0.95
	e.global_position = np
	e.model.rotation.y = atan2(-d.x, -d.z)
	model.rotation = Vector3(0.0, atan2(d.x, d.z), 0.0)      # หันไปหาศัตรูที่วาร์ปมา
	if e.anim_player:
		var an := "AirPunch1" if i % 2 == 0 else "AirPunch2"
		if e.anim_player.has_animation(an):
			e.anim_player.play(an, 0.02, 1.7)
			e.anim_player.seek(0.0, true)
	var col: Color = e.vfx_color if "vfx_color" in e else Color(0.4, 0.75, 1.0)
	if i > 0:
		Vfx.sparks(self, old + Vector3.UP * 1.0, col, 5, 3.0)
		Vfx.speed_lines(self, old + Vector3.UP * 1.0, np + Vector3.UP * 1.0, Color(0.85, 0.93, 1.0, 0.8), 8, 0.5, 0.03, 0.2)
	var fire = e.fire_l if i % 2 == 0 else e.fire_r
	if fire:
		fire.boost(1.8)
	_sfx("whoosh_light", -6.0, randf_range(1.1, 1.4))


func _enemy_rush_hit(e) -> void:
	var dir: Vector3 = global_position - e.global_position
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.05 else -wd_s
	_damage(_e_param(e, "air_flurry_damage", 12.0))
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and "player_index" in e:
		hud.add_combo(e.player_index)
	_play("Hit", 0.02, 1.5, true)
	var col: Color = e.vfx_color if "vfx_color" in e else Color(0.4, 0.75, 1.0)
	var hp_pos := global_position + Vector3.UP * 1.25 - dir * 0.2
	Vfx.ring(self, hp_pos, -dir, col, 0.2, 1.0, 0.2)
	Vfx.sparks(self, hp_pos, col, 6, 4.5)
	_sfx("hit_light", 0.0, randf_range(0.8, 0.95))
	shake = maxf(shake, shake_heavy * 1.1)
	_hitstop(0.045)


func _air_countered(e) -> void:
	wd_counter_t = -1.0
	wd_flurry = false
	var dir: Vector3 = global_position - e.global_position
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.05 else -wd_s
	_release_enemy()
	_restore_camera()
	if "knockdown_pending" in e:
		e.knockdown_pending = false
	e.action = ""
	e.velocity = Vector3.ZERO
	e.knockback = Vector3.ZERO
	if "cooldown" in e:
		e.cooldown = 0.2
	var hit_pos: Vector3 = global_position + Vector3.UP * 1.2
	var col: Color = e.vfx_color if "vfx_color" in e else Color(0.4, 0.75, 1.0)
	Vfx.ring(self, hit_pos, -dir, col, 0.2, 1.5, 0.25)
	Vfx.sparks(self, hit_pos, col, 10, 5.0)
	action = ""                                   # ออกจากท่าก่อน แล้วรับหมัด
	model.visible = true
	take_hit(dir, true, _e_param(e, "damage_heavy", 40.0))


func _release_enemy() -> void:
	if wd_holding and wd_target and is_instance_valid(wd_target):
		wd_target.frozen = false
	wd_holding = false


func _restore_camera() -> void:
	pass                                      # กล้องรวมตามทั้งสองคนเองอยู่แล้ว


# ---------- ไฟที่มือ ----------

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
	# แสงรอบมือกินเครื่องมาก (ต้องคำนวณแสงทั่วแมพ): HIGH = 2 มือ, MEDIUM = มือขวามือเดียว, LOW = ไม่มี
	fx.with_light = GameState.gfx == 2 or (GameState.gfx == 1 and side == -1)
	if GameState.gfx == 1:
		fx.light_energy *= 1.5
	fx.position = Vector3(0, 0.12, 0.0)   # จากข้อมือไปกลางกำปั้น
	att.add_child(fx)
	return fx


## ลมกระจายตอนออกหมัด/เตะ (ออกจากกำปั้นหรือเท้าที่ใช้)
func _punch_vfx(a: String) -> void:
	if rig == null or rig._skel == null:
		return
	var side := 1 if a == "Punch1" else -1
	var bone := "Hand"
	if a == "JumpKick":
		bone = "Foot"
	var skel: Skeleton3D = rig._skel
	var pos: Vector3 = skel.global_transform * skel.get_bone_global_pose(rig._b(side, bone)).origin
	var fwd := model.global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	Vfx.puff(self, pos + fwd * 0.2, fwd, wind_color, 5, 5.0, 0.22, 0.14, 25.0)
	Vfx.ring(self, pos + fwd * 0.35, fwd, Color(wind_color.r, wind_color.g, wind_color.b, 0.35), 0.12, 0.65, 0.18)


## เสียเลือด (0 = แพ้ยกนี้ -> ฉากหลักประกาศผู้ชนะแล้วเริ่มยกใหม่)
func _damage(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	if hp <= 0.0:
		knockdown_pending = true
		velocity.y = maxf(velocity.y, 4.0)      # เด้งลอยนิดหนึ่งแล้วล้มลงพื้น
		air_time = maxf(air_time, 0.15)
		var main := get_tree().current_scene
		if main and main.has_method("on_fighter_ko"):
			main.on_fighter_ko(self)


## เริ่มยกใหม่: เลือด/สตามินาเต็ม กลับจุดเกิด
func reset_round() -> void:
	_release_enemy()
	hp = hp_max
	stamina = stamina_max
	action = ""
	combo_queued = false
	knockdown_pending = false
	slam_pending = false
	frozen = false
	in_ult = false
	is_blocking = false
	knockback = Vector3.ZERO
	velocity = Vector3.ZERO
	ult_gauge = 100.0 if ult_start_full else 0.0   # เริ่มยกใหม่ต้องสะสมเกจใหม่
	global_position = spawn_point
	model.visible = true
	model.rotation = Vector3.ZERO
	if opponent:
		var to: Vector3 = opponent.spawn_point - spawn_point
		model.rotation.y = atan2(to.x, to.z)
	if anim_player:
		anim_player.speed_scale = 1.0
	_play("FightIdle", 0.1, 1.0, true)
