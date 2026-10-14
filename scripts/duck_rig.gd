extends RefCounted
## ชุดแอนิเมชันของเป็ดราชา (สร้างจากโค้ด) ใช้แทน FighterRig กับโมเดลที่ไม่มีแขน/ขาแบบมนุษย์
## โครงกระดูกเป็ดมีแค่ 6 ข้อ: Root, Body, Head, Crown, Foot_L, Foot_R
## ใช้ชื่อท่าเดียวกับ FighterRig ทุกท่า (FightIdle, Punch1..3, Hit, KnockDown ...) player.gd จึงเรียกใช้ได้เลย
## ท่าต่อยไม่ใช้แขน: ตัวโน้มพุ่ง + หัวโขกไปข้างหน้า ส่วน "ปีกใส" เป็นเอฟเฟกต์ที่ duck_wings.gd ทำให้ตอนออกท่า

const FighterRig := preload("res://scripts/fighter_rig.gd")
const Wings := preload("res://scripts/duck_wings.gd")

## โมเดลเป็ดถูกย่อ 0.8 ใน king_duck.tscn : 1 เมตรในเกม = 1.25 หน่วยโมเดล
const UNIT := 1.25
## หน่วยโมเดล: ท้องเป็ดอยู่ต่ำกว่าข้อ Body เท่านี้ (ใช้ล็อกท้องให้ติดพื้นตอนบีบตัว)
const BELLY := 0.45
const HEAD_SINK := 0.0          ## หัวจมลงในตัวกี่หน่วยโมเดล (ซ่อนเส้นที่คอ)

var model: Node3D
var anim_player: AnimationPlayer
var L := {}
var idle_period := 2.4
var idle_crouch := 0.12
var idle_bounce := 0.03
var step_dist := {}
var B := {}                      # ชื่อกระดูกแบบ mixamo -> index (ให้ ultimate.gd / player.gd ใช้ได้)

var _lib: AnimationLibrary
var _skel: Skeleton3D
var _skel_path := ""
var _i := {}                     # Root/Body/Head/Crown/Foot_L/Foot_R -> index
var _rest_pos: Array = []
var _rest_rot: Array = []
var _lpos: Array = []
var _lrot: Array = []
var _lscl: Array = []

const DEF := {"sy": 1.0}


## เรียกจากโค้ดที่ใช้ rig._b(side, "Hand"/"Foot")
func _b(side: int, part: String) -> int:
	if part == "Foot":
		return _i["Foot_L"] if side > 0 else _i["Foot_R"]
	return _i["Body"]            # เป็ดไม่มีมือ -> ใช้ลำตัว (ปีกใสติดที่ลำตัว)


func setup(p_model: Node3D, p_anim_player: AnimationPlayer) -> bool:
	model = p_model
	anim_player = p_anim_player
	_lib = anim_player.get_animation_library("")
	if _lib == null:
		_lib = AnimationLibrary.new()
		anim_player.add_animation_library("", _lib)
	for c in model.find_children("*", "Skeleton3D", true, false):
		_skel = c
		break
	if _skel == null:
		push_warning("ไม่พบ Skeleton3D ของเป็ด")
		return false
	for n in ["Root", "Body", "Head", "Crown", "Foot_L", "Foot_R"]:
		_i[n] = _skel.find_bone(n)
		if _i[n] < 0:
			push_warning("ไม่พบกระดูก " + n)
			return false
	for k in ["Hips", "Spine", "Spine1", "Spine2", "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand"]:
		B[k] = _i["Body"]
	B["Neck"] = _i["Head"]
	B["Head"] = _i["Head"]
	B["LeftUpLeg"] = _i["Foot_L"]
	B["LeftLeg"] = _i["Foot_L"]
	B["LeftFoot"] = _i["Foot_L"]
	B["RightUpLeg"] = _i["Foot_R"]
	B["RightLeg"] = _i["Foot_R"]
	B["RightFoot"] = _i["Foot_R"]
	for i in _skel.get_bone_count():
		var r := _skel.get_bone_rest(i)
		_rest_rot.append(r.basis.get_rotation_quaternion())
		_rest_pos.append(r.origin)
	# ลดหัวลงนิดเดียวให้ซ้อนทับตัว: ปิดรอยแยกเป็นเส้นตรงคอ
	_skel.set_bone_pose_position(_i["Head"], _rest_pos[_i["Head"]] + Vector3(0.0, -HEAD_SINK, 0.0))
	_skel_path = String(anim_player.get_node(anim_player.root_node).get_path_to(_skel))
	_setup_blink()
	return true


## กะพริบตา: ตาเป็นโมเดลแยก มีแอนิเมชัน "Blink" มากับไฟล์ glb แต่ AnimationPlayer เล่นได้ทีละท่า
## เลยสร้างตัวเล่นที่สองไว้เล่นกะพริบวนตลอดเวลา (ไม่ชนกับท่าต่อสู้)
func _setup_blink() -> void:
	var src: Animation = null
	for n in _lib.get_animation_list():
		if n.to_lower().begins_with("blink"):
			src = _lib.get_animation(n)
			break
	if src == null:
		return
	var bp := AnimationPlayer.new()
	bp.name = "BlinkPlayer"
	anim_player.get_parent().add_child(bp)
	bp.root_node = anim_player.root_node
	var bl := AnimationLibrary.new()
	var an := src.duplicate() as Animation
	an.loop_mode = Animation.LOOP_LINEAR
	bl.add_animation("Blink", an)
	bp.add_animation_library("", bl)
	bp.play("Blink")


func import_anim(_path: String, new_name: String) -> String:
	return "Run" if _lib.has_animation("Run") else ""


func build_all(lengths: Dictionary) -> void:
	L = lengths
	_make_anim("FightIdle", idle_period, true, _pose_idle)
	_make_anim("Walking", 0.46, true, func(u): _pose_walk(u, 0.30, 0.10, 6.0, 0.03, 4.0))
	_make_anim("Run", 0.55, true, _pose_toboggan, 36)
	_make_anim("MenuIdle", 7.0, true, _pose_menu_idle, 140)
	_make_anim("Punch1", L.Punch1, false, _pose_peck)
	_make_anim("Punch2", L.Punch2, false, _pose_rising_spiral)
	_make_anim("Punch3", L.Punch3, false, _pose_royal_smash, 48)
	_make_anim("JumpPrep", L.get("JumpPrep", 0.1), false, func(u): _play_kf(_KF_JUMP_PREP, u))
	_make_anim("JumpUp", 0.3, false, func(u): _play_kf(_KF_JUMP_UP, u))
	_make_anim("JumpFall", 0.3, false, func(u): _play_kf(_KF_JUMP_FALL, u))
	_make_anim("Block", 1.2, true, _pose_block)
	_make_anim("BlockHit", L.get("BlockHit", 0.3), false, _pose_block_hit)
	_make_anim("JumpKick", L.JumpKick, false, func(u): _play_kf(_KF_DIVE, u))
	_make_anim("Land", L.Land, false, func(u): _play_kf(_KF_LAND, u))
	_make_anim("Hit", L.get("Hit", 0.4), false, func(u): _pose_hit(u, 1.0))
	_make_anim("HitHeavy", L.get("HitHeavy", 0.7), false, func(u): _pose_hit(u, 1.8))
	_make_anim("UltCharge", 1.1, false, _pose_ult_charge)
	_make_anim("AirPunch1", L.get("Punch1", 0.26), false, func(u): _pose_air_cutter(u, 1), 24)
	_make_anim("AirPunch2", L.get("Punch2", 0.26), false, func(u): _pose_air_cutter(u, -1), 24)
	_make_anim("UltWindup", 1.3, false, _pose_ult_windup)
	_make_anim("UltStrike", 0.5, false, func(u): _play_kf(_KF_ULT_STRIKE, u))
	_make_anim("KnockDown", 0.7, false, func(u): _play_kf(_KF_KNOCKDOWN, u))
	_make_anim("GetUp", 1.0, false, func(u): _play_kf(_KF_GETUP, u))
	_make_anim("DashF", L.get("DashF", 0.3), false, func(u): _pose_dash(u, 1))
	_make_anim("DashB", L.get("DashB", 0.28), false, func(u): _pose_dash(u, -1))


# ======================= ระบบสร้างท่า =======================
# พารามิเตอร์ท่า (Dictionary) — ค่าที่ไม่ใส่ = 0 (sy = 1)
#   ตัว:  bp = โน้มหน้า(+)/เอนหลัง(-) องศา, by = บิดซ้าย/ขวา, br = เอียงข้าง,
#         ox/oy/oz = เลื่อนตัว (หน่วยโมเดล), sy = บีบ(<1)/ยืด(>1) ตัวตามแนวตั้ง (ท้องยังติดพื้น)
#   หัว:  hp = ก้ม(+)/เงย(-), hy = หันซ้ายขวา, hr = เอียง, cp = มงกุฎสะบัดเพิ่ม
#   เท้า: fl_y/fl_z = ยกเท้าซ้าย/เลื่อนไปหน้า, fr_y/fr_z = เท้าขวา, flp/frp = ปลายเท้าก้ม(+)/กระดก(-), fx = กางเท้าออก

func _v(p: Dictionary, k: String) -> float:
	return p.get(k, DEF.get(k, 0.0))


func _pose(p: Dictionary) -> void:
	var sy := _v(p, "sy")
	var sxz := 1.0 / sqrt(sy)
	var bi: int = _i["Body"]
	_lpos[bi] = _rest_pos[bi] + Vector3(_v(p, "ox"), _v(p, "oy") + BELLY * (1.0 - sy), _v(p, "oz"))
	_lrot[bi] = _q(_v(p, "bp"), _v(p, "by"), _v(p, "br"))
	_lscl[bi] = Vector3(sxz, sy, sxz)
	_lrot[_i["Head"]] = _q(_v(p, "hp"), _v(p, "hy"), _v(p, "hr"))
	_lrot[_i["Crown"]] = _q(_v(p, "cp"), 0.0, 0.0)
	var fx := _v(p, "fx")
	var fl: int = _i["Foot_L"]
	var fr: int = _i["Foot_R"]
	_lpos[fl] = _rest_pos[fl] + Vector3(fx, _v(p, "fl_y"), _v(p, "fl_z"))
	_lpos[fr] = _rest_pos[fr] + Vector3(-fx, _v(p, "fr_y"), _v(p, "fr_z"))
	_lrot[fl] = _q(_v(p, "flp"), 0.0, 0.0)
	_lrot[fr] = _q(_v(p, "frp"), 0.0, 0.0)


## หมุนด้วยลำดับ yaw -> roll -> pitch (แกนโมเดล: หน้า = +Z, ขึ้น = +Y)
func _q(pitch: float, yaw: float, roll: float) -> Quaternion:
	return Quaternion(Vector3.UP, deg_to_rad(yaw)) * Quaternion(Vector3.BACK, deg_to_rad(roll)) * Quaternion(Vector3.RIGHT, deg_to_rad(pitch))


func _make_anim(anim_name: String, length: float, loop: bool, pose: Callable, steps := 30) -> void:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var count := _skel.get_bone_count()
	for i in count:
		var t := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, NodePath(_skel_path + ":" + _skel.get_bone_name(i)))
	var pos_bones := [_i["Body"], _i["Foot_L"], _i["Foot_R"]]
	var pos_tracks := {}
	for bi in pos_bones:
		var t := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(t, NodePath(_skel_path + ":" + _skel.get_bone_name(bi)))
		pos_tracks[bi] = t
	var scl_track := anim.add_track(Animation.TYPE_SCALE_3D)
	anim.track_set_path(scl_track, NodePath(_skel_path + ":" + _skel.get_bone_name(_i["Body"])))
	for k in steps + 1:
		var u := float(k) / steps
		_lrot = _rest_rot.duplicate()
		_lpos = _rest_pos.duplicate()
		_lscl = []
		for i in count:
			_lscl.append(Vector3.ONE)
		pose.call(u)
		for i in count:
			anim.rotation_track_insert_key(i, length * u, _lrot[i])
		for bi in pos_bones:
			anim.position_track_insert_key(pos_tracks[bi], length * u, _lpos[bi])
		anim.scale_track_insert_key(scl_track, length * u, _lscl[_i["Body"]])
	_lib.add_animation(anim_name, anim)


## ประมาณค่าระหว่าง keyframe: keys = [[เวลา 0..1, {พารามิเตอร์}], ...]
func _kf(keys: Array, u: float) -> Dictionary:
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if u <= b[0]:
			var t := smoothstep(a[0], b[0], u)
			var out := {}
			var names := {}
			for k in a[1]:
				names[k] = true
			for k in b[1]:
				names[k] = true
			for k in names:
				out[k] = lerpf(_v(a[1], k), _v(b[1], k), t)
			return out
	return keys[-1][1]


func _play_kf(keys: Array, u: float) -> void:
	_pose(_kf(keys, u))


func _env(u: float, peak: float, hold: float, end := 1.0) -> float:
	if u < peak:
		return smoothstep(0.0, peak, u)
	if u < hold:
		return 1.0
	return 1.0 - smoothstep(hold, end, u)


func _bounce_curve(p: float) -> float:
	if p < 0.6:
		return sin(PI * 0.5 * p / 0.6)
	return cos(PI * 0.5 * (p - 0.6) / 0.4)


## ก้าวเท้าตามตัวที่พุ่ง (เท้าที่ยังไม่ก้าวติดพื้น ไม่ไถล) -> [เท้าซ้าย, เท้าขวา] เป็น {y, z} หน่วยโมเดล
func _step_feet(a: String, u: float) -> Array:
	if not a in step_dist or float(step_dist[a]) < 0.01:
		return [{"y": 0.0, "z": 0.0}, {"y": 0.0, "z": 0.0}]
	var d: float = float(step_dist[a]) * UNIT
	var k := FighterRig.lunge_k(a, u)
	var disp := d * (1.0 - cos(PI * k)) * 0.5
	var s_lead := smoothstep(0.0, 0.65, k)
	var s_rear := smoothstep(0.4, 1.0, k)
	var lift := clampf(d / 0.3, 0.5, 1.0) * 0.12
	return [
		{"y": lift * sin(PI * s_lead), "z": -disp + s_lead * d},
		{"y": lift * sin(PI * s_rear), "z": -disp + s_rear * d},
	]


# ======================= ท่าต่างๆ =======================

## ยืนตั้งท่า: ตัวบีบ-ยืดเด้งเป็นจังหวะ (ลงเร็ว ขึ้นช้า) หัวเด้งตามช้ากว่าเล็กน้อย เท้าถ่ายน้ำหนัก + หายใจ
func _pose_idle(u: float) -> void:
	var beats := 4.0
	var h := _bounce_curve(fmod(u * beats, 1.0))
	var h_head := _bounce_curve(fmod(u * beats - 0.2 + 1.0, 1.0))
	var sway := sin(TAU * u)
	var breath := sin(TAU * 2.0 * u)
	var squash := (idle_crouch * 0.6 + idle_bounce) * UNIT
	var sy := 1.0 - squash * (1.0 - h) * 1.2
	var wl := maxf(0.0, sin(TAU * u))            # ถ่ายน้ำหนักซ้าย-ขวาช้าๆ
	var wr := maxf(0.0, -sin(TAU * u))
	_pose({
		"sy": sy, "bp": 6.0 + 1.2 * breath - 2.0 * h, "br": 2.5 * sway, "by": 3.0 * sin(TAU * u + 1.0),
		"hp": -3.0 + 3.0 * (h_head - h) , "hr": -2.5 * sway, "hy": 5.0 * sin(TAU * u + 1.6), "cp": 4.0 * (h - h_head),
		"fl_y": 0.03 * wl, "fr_y": 0.03 * wr, "fx": 0.02 * (1.0 - h),
	})


## เดิน/วิ่งแบบเป็ดวอดเดิล: เท้าสลับก้าว ตัวโยกซ้ายขวา เด้งขึ้นลง (amp = ระยะก้าว, lift = ยกเท้า, wob = องศาโยก)
func _pose_walk(u: float, amp: float, lift: float, wob: float, bob: float, lean: float) -> void:
	var ph := TAU * u
	var step_l := sin(ph)
	var step_r := sin(ph + PI)
	var bounce := absf(sin(ph))
	_pose({
		"bp": lean + 2.0 * cos(2.0 * ph), "br": wob * sin(ph), "by": wob * 0.5 * sin(ph + 0.6),
		"oy": bob * bounce, "sy": 1.0 - 0.04 * (1.0 - bounce) * (lean / 17.0 + 0.4),
		"hp": -lean * 0.6, "hr": -wob * 0.8 * sin(ph), "hy": 2.0 * sin(ph + 1.0), "cp": 3.0 * sin(2.0 * ph - 0.8),
		"fl_z": amp * step_l, "fl_y": lift * maxf(0.0, cos(ph)), "flp": -18.0 * maxf(0.0, cos(ph)) * (lift / 0.1) * 0.5,
		"fr_z": amp * step_r, "fr_y": lift * maxf(0.0, cos(ph + PI)), "frp": -18.0 * maxf(0.0, cos(ph + PI)) * (lift / 0.1) * 0.5,
		"fx": 0.0,
	})


## ยืนหน้าเมนู (แบบเพนกวินสงสัย): เด้งเบาๆ แล้วหันซ้าย-ขวามองนั่นนี่ เอียงหัวสงสัย โยกตัวถ่ายน้ำหนัก กระโดดตุ๊บเล็กๆ
func _pose_menu_idle(u: float) -> void:
	var base := {"bp": 6.0, "hp": -3.0}
	var keys := [
		[0.00, base],
		[0.05, {"sy": 0.94, "bp": 9.0, "hp": -2.0, "cp": 4.0}],
		[0.09, {"sy": 1.04, "oy": 0.03, "bp": 3.0, "hp": -5.0, "cp": -4.0}],
		[0.13, base],
		[0.22, {"hy": -34.0, "hr": 3.0, "hp": -8.0, "by": -10.0, "bp": 5.0, "cp": -4.0}],
		[0.30, {"hy": -38.0, "hr": 5.0, "hp": -6.0, "by": -12.0, "br": 2.0, "cp": 3.0}],
		[0.36, {"hy": -34.0, "hr": 4.0, "hp": -7.0, "by": -10.0}],
		[0.41, {"hy": 32.0, "hr": -3.0, "hp": -9.0, "by": 9.0, "br": -2.0, "cp": -6.0}],
		[0.50, {"hy": 38.0, "hr": -5.0, "hp": -7.0, "by": 11.0, "br": -2.0}],
		[0.55, {"hy": 6.0, "hr": 2.0, "hp": -7.0, "by": 3.0, "sy": 1.03}],
		[0.58, {"hy": -5.0, "hr": -2.0, "hp": -6.0, "by": -3.0}],
		[0.62, base],
		[0.68, {"br": -9.0, "by": -6.0, "ox": -0.035, "hr": 3.0, "hp": -6.0, "fl_y": 0.07, "flp": -12.0, "fx": 0.04}],
		[0.74, {"br": 9.0, "by": 6.0, "ox": 0.035, "hr": -3.0, "hp": -6.0, "fr_y": 0.07, "frp": -12.0, "fx": 0.04}],
		[0.80, {"br": -8.0, "by": -5.0, "ox": -0.03, "hr": 3.0, "hp": -6.0, "fl_y": 0.06, "flp": -10.0, "fx": 0.04}],
		[0.85, base],
		[0.89, {"sy": 0.88, "bp": 12.0, "hp": -4.0, "cp": 8.0, "fx": 0.06}],
		[0.93, {"sy": 1.12, "oy": 0.10, "bp": -4.0, "hp": -10.0, "cp": -12.0, "fl_y": 0.10, "fr_y": 0.10, "flp": 20.0, "frp": 20.0}],
		[0.97, {"sy": 0.95, "bp": 8.0, "hp": 0.0, "cp": 6.0}],
		[1.00, base],
	]
	var p := _kf(keys, u)
	# หายใจ/โยกเบาๆ ตลอดเวลา ให้ดูมีชีวิตแม้ช่วงหยุด
	p["oy"] = _v(p, "oy") + 0.006 * sin(TAU * 9.0 * u)
	p["br"] = _v(p, "br") + 1.2 * sin(TAU * 3.0 * u)
	_pose(p)


## เดินแบบเพนกวิน: ก้าวสั้นถี่ ตัวโยกซ้าย-ขวาแรงๆ (หัวตั้งตรงสวนกับตัว) ปลายเท้ากางออก เด้งทุกก้าว
func _pose_waddle(u: float) -> void:
	var ph := TAU * u * 1.0
	var s1 := sin(ph)
	var hop := absf(cos(ph))
	var lead_l := maxf(0.0, cos(ph))
	var lead_r := maxf(0.0, -cos(ph))
	_pose({
		"bp": 9.0 + 2.0 * cos(2.0 * ph), "br": 17.0 * s1, "by": 9.0 * s1,
		"oy": 0.035 * hop, "ox": 0.035 * s1, "sy": 1.0 - 0.05 * (1.0 - hop),
		"hp": -5.0, "hr": -15.0 * s1, "hy": -7.0 * s1, "cp": 7.0 * sin(2.0 * ph - 0.8),
		"fl_z": 0.17 * -cos(ph), "fl_y": 0.07 * lead_l, "flp": -14.0 * lead_l,
		"fr_z": 0.17 * cos(ph), "fr_y": 0.07 * lead_r, "frp": -14.0 * lead_r,
		"fx": 0.05,
	})


## วิ่งแบบเพนกวิน: ทิ้งตัวนอนคว่ำท้องไถลไปข้างหน้า เท้าเตะไปด้านหลัง ตัวส่ายเป็นคลื่น หัวเงยมองเป้าหมาย
func _pose_toboggan(u: float) -> void:
	var ph := TAU * u
	var wob := sin(ph)
	var push := maxf(0.0, sin(ph * 2.0))
	_pose({
		"bp": 66.0 + 3.0 * cos(2.0 * ph), "br": 5.0 * wob, "by": 7.0 * wob,
		"oy": -0.05 + 0.02 * cos(2.0 * ph), "oz": 0.10, "sy": 0.96,
		"hp": -52.0, "hr": -4.0 * wob, "hy": -8.0 * wob, "cp": -10.0,
		"fl_z": -0.30 + 0.10 * sin(ph * 2.0), "fl_y": 0.30 + 0.08 * push, "flp": 38.0,
		"fr_z": -0.30 - 0.10 * sin(ph * 2.0), "fr_y": 0.30 + 0.08 * (maxf(0.0, -sin(ph * 2.0))), "frp": 38.0,
		"fx": 0.06,
	})


## หมัด (ปีกฟาด): side 1 = ปีกซ้ายฟาด, -1 = ปีกขวา — ตัวง้างไปด้านหลังนิดก่อน แล้วโน้มพุ่ง หัวโขกไปข้างหน้า
func _pose_punch(u: float, side: int, a: String) -> void:
	var wind := {"bp": -6.0, "by": side * 16.0, "br": side * 4.0, "hp": -8.0, "hy": side * 14.0, "sy": 1.04, "oz": -0.04, "cp": -6.0}
	var strike := {"bp": 20.0, "by": -side * 22.0, "br": -side * 6.0, "hp": 16.0, "hy": -side * 16.0, "sy": 0.94, "oz": 0.14, "cp": 12.0}
	var hold := {"bp": 12.0, "by": -side * 12.0, "br": -side * 3.0, "hp": 8.0, "hy": -side * 8.0, "sy": 0.97, "oz": 0.06, "cp": 4.0}
	var guard := {"bp": 6.0, "hp": -3.0}
	var p := _kf([[0.0, guard], [0.14, wind], [0.32, strike], [0.55, hold], [1.0, guard]], u)
	_add_feet(p, _step_feet(a, u))
	_pose(p)


func _add_feet(p: Dictionary, f: Array) -> void:
	p["fl_y"] = _v(p, "fl_y") + float(f[0]["y"])
	p["fl_z"] = _v(p, "fl_z") + float(f[0]["z"])
	p["fr_y"] = _v(p, "fr_y") + float(f[1]["y"])
	p["fr_z"] = _v(p, "fr_z") + float(f[1]["z"])


## หมัด 1 — หมุนตัวปัดปีก: ย่อตัวบิดไปด้านหลัง แล้วหมุนรอบตัว 1 รอบเหมือนลูกข่าง (เท้าติดพื้น ตัวเอียงนิดๆ)
func _pose_spin_sweep(u: float, side: int) -> void:
	var guard := {"bp": 6.0, "hp": -3.0}
	var wind := {"bp": 10.0, "by": side * 38.0, "br": side * 6.0, "hp": 6.0, "hy": side * 20.0, "sy": 0.84, "cp": 6.0, "fx": 0.06}
	var p: Dictionary
	if u < 0.2:
		p = _kf([[0.0, guard], [0.2, wind]], u)
	elif u < 0.86:
		var k := smoothstep(0.0, 1.0, (u - 0.2) / 0.66)
		var arc := sin(PI * k)
		p = {"by": lerpf(side * 38.0, -side * 360.0, k), "bp": 12.0, "br": -side * 16.0 * arc, "sy": 1.0 - 0.05 * arc,
			"oy": 0.05 * arc, "hp": 4.0, "hy": 0.0, "cp": -12.0 * arc, "fx": 0.05}
	else:
		var k2 := smoothstep(0.86, 1.0, u)
		p = {"bp": lerpf(12.0, 6.0, k2), "hp": lerpf(4.0, -3.0, k2), "sy": lerpf(0.97, 1.0, k2), "fx": lerpf(0.05, 0.0, k2)}
	_add_feet(p, _step_feet("Punch1", u))
	_pose(p)


## หมัด 2 — กระโดดตบ: ย่อตัวแล้วดีดขึ้น ตกลงมาทิ้งท้องใส่ศัตรูเต็มตัว (ตัวคว่ำไปข้างหน้า ขาเตะไปด้านหลัง)
func _pose_hop_slam(u: float) -> void:
	var guard := {"bp": 6.0, "hp": -3.0}
	var crouch := {"sy": 0.70, "bp": 16.0, "hp": 12.0, "cp": 8.0, "fx": 0.08}
	var air := {"sy": 1.20, "oy": 0.40, "bp": -16.0, "hp": -16.0, "cp": -14.0, "fl_y": 0.45, "fr_y": 0.45, "flp": 30.0, "frp": 30.0, "oz": 0.05}
	var slam := {"sy": 0.80, "oy": 0.0, "bp": 42.0, "hp": 20.0, "cp": 18.0, "oz": 0.24, "fl_y": 0.12, "fr_y": 0.12, "fl_z": -0.32, "fr_z": -0.32, "flp": 55.0, "frp": 55.0}
	var p := _kf([[0.0, guard], [0.16, crouch], [0.38, air], [0.52, slam], [0.76, slam], [1.0, guard]], u)
	_pose(p)


## หมัด 3 — พายุหมุน: ย่อตัว ลอยขึ้นพร้อมหมุน 2 รอบ กางปีกกระพือ แล้วลงพื้นทิ้งตัวกระแทก (ท่าแรง)
func _pose_tornado(u: float) -> void:
	var guard := {"bp": 6.0, "hp": -3.0}
	var crouch := {"sy": 0.70, "bp": 18.0, "hp": 14.0, "cp": 8.0, "fx": 0.08}
	var p: Dictionary
	if u < 0.18:
		p = _kf([[0.0, guard], [0.18, crouch]], u)
	elif u < 0.86:
		var k := smoothstep(0.0, 1.0, (u - 0.18) / 0.68)
		var arc := sin(PI * k)
		p = {"by": -720.0 * k, "bp": 8.0 - 22.0 * arc, "br": 12.0 * sin(k * TAU * 2.0), "sy": 1.0 + 0.16 * arc,
			"oy": 0.40 * arc, "hp": -8.0 * arc, "cp": -22.0 * arc, "fl_y": 0.30 * arc, "fr_y": 0.30 * arc, "flp": 28.0 * arc, "frp": 28.0 * arc}
		var drop := smoothstep(0.78, 1.0, k)       # ท้ายท่าทิ้งตัวคว่ำลงกระแทก
		p["bp"] = _v(p, "bp") + 30.0 * drop
		p["oz"] = 0.2 * drop
	else:
		var k2 := smoothstep(0.86, 1.0, u)
		p = {"bp": lerpf(34.0, 6.0, k2), "hp": lerpf(14.0, -3.0, k2), "sy": lerpf(0.82, 1.0, k2), "oz": lerpf(0.2, 0.0, k2)}
	_add_feet(p, _step_feet("Punch3", u))
	_pose(p)


## หมัด 1 — จิกรัว: โยกหัวจิกลงไปข้างหน้าถี่ๆ 3 ที ตัวเด้งตามจังหวะ (เร็ว เบา)
func _pose_peck(u: float) -> void:
	var guard := {"bp": 6.0, "hp": -3.0}
	var up := {"bp": -4.0, "hp": -16.0, "sy": 1.06, "oz": -0.04, "cp": -10.0}
	var peck := {"bp": 30.0, "hp": 34.0, "sy": 0.9, "oz": 0.2, "cp": 20.0, "oy": -0.02}
	var p := _kf([[0.0, guard], [0.10, up], [0.20, peck], [0.30, up], [0.42, peck], [0.52, up], [0.66, peck], [0.82, peck], [1.0, guard]], u)
	p["by"] = 8.0 * sin(u * TAU * 3.0)
	_add_feet(p, _step_feet("Punch1", u))
	_pose(p)


## หมัด 2 — เกลียวเสย: ย่อตัว ดีดขึ้นฟ้าหมุนเกลียวครึ่งรอบ ท้องแอ่นเงยหน้า ปีกตวัดขึ้น (ส่งศัตรูลอยขึ้น)
func _pose_rising_spiral(u: float) -> void:
	var guard := {"bp": 6.0, "hp": -3.0}
	var crouch := {"sy": 0.62, "bp": 20.0, "hp": 16.0, "cp": 10.0, "fx": 0.08, "by": 20.0}
	var p: Dictionary
	if u < 0.2:
		p = _kf([[0.0, guard], [0.2, crouch]], u)
	elif u < 0.82:
		var k := smoothstep(0.0, 1.0, (u - 0.2) / 0.62)
		var arc := sin(PI * k)
		p = {"by": lerpf(20.0, -200.0, k), "bp": -26.0 * arc, "br": 14.0 * sin(k * TAU), "sy": 1.0 + 0.2 * arc, "oy": 0.55 * arc,
			"hp": -30.0 * arc, "cp": -24.0 * arc, "fl_y": 0.22 * arc, "fr_y": 0.30 * arc, "flp": 26.0 * arc, "frp": 34.0 * arc}
	else:
		var k2 := smoothstep(0.82, 1.0, u)
		p = {"bp": lerpf(8.0, 6.0, k2), "by": lerpf(-200.0, -360.0, k2) , "hp": lerpf(8.0, -3.0, k2), "sy": lerpf(0.88, 1.0, k2)}
	_add_feet(p, _step_feet("Punch2", u))
	_pose(p)


## หมัด 3 — ราชันทุบ (ท่าจบ): เอนหลังกระโดดกางปีก -> ตีลังกาไปข้างหน้า 1 รอบ -> ทิ้งตัวทุบ ศัตรูกระเด็นไปชนขอบลาน
func _pose_royal_smash(u: float) -> void:
	var guard := {"bp": 6.0, "hp": -3.0}
	var wind := {"bp": -30.0, "hp": -22.0, "sy": 1.16, "oy": 0.22, "cp": -20.0, "fl_y": 0.12, "fr_y": 0.12, "flp": 20.0, "frp": 20.0}
	var p: Dictionary
	if u < 0.22:
		var k0 := smoothstep(0.0, 1.0, u / 0.22)
		p = {"bp": lerpf(6.0, -30.0, k0), "hp": lerpf(-3.0, -22.0, k0), "sy": lerpf(1.0, 0.7, sin(PI * k0)) + 0.16 * k0, "oy": 0.22 * k0, "cp": -20.0 * k0}
	elif u < 0.52:
		var k := smoothstep(0.0, 1.0, (u - 0.22) / 0.30)
		var arc := sin(PI * k)
		p = {"bp": lerpf(-30.0, 335.0, k), "oy": 0.22 + 0.55 * arc, "sy": 1.0 + 0.1 * arc, "hp": lerpf(-22.0, 20.0, k), "cp": -20.0 + 38.0 * k,
			"fl_y": 0.2 * arc, "fr_y": 0.2 * arc, "flp": 30.0 * arc, "frp": 30.0 * arc}
	elif u < 0.8:
		p = _kf([[0.52, {"bp": 335.0, "oy": 0.0, "sy": 0.7, "oz": 0.30, "hp": 24.0, "cp": 20.0, "fl_y": 0.1, "fr_y": 0.1, "flp": 55.0, "frp": 55.0}],
			[0.62, {"bp": 360.0 + 36.0, "oy": 0.0, "sy": 0.72, "oz": 0.32, "hp": 24.0, "cp": 20.0, "fl_y": 0.1, "fr_y": 0.1, "flp": 55.0, "frp": 55.0}],
			[0.8, {"bp": 360.0 + 36.0, "oy": 0.0, "sy": 0.78, "oz": 0.28, "hp": 20.0, "cp": 14.0}]], u)
	else:
		var k2 := smoothstep(0.8, 1.0, u)
		p = {"bp": lerpf(396.0, 366.0, k2), "hp": lerpf(20.0, -3.0, k2), "sy": lerpf(0.78, 1.0, k2), "oz": lerpf(0.28, 0.0, k2)}
	_add_feet(p, _step_feet("Punch3", u))
	_pose(p)


## (เก่า) หมัดที่ 3: ย่อตัวสะสมแรง แล้วดีดตัวขึ้นเสยฟ้า หัวเงย ปีกสองข้างฟาดขึ้น (ท่าแรง)
func _pose_uppercut(u: float) -> void:
	var guard := {"bp": 6.0, "hp": -3.0}
	var load_p := {"bp": 22.0, "hp": 14.0, "sy": 0.78, "oz": -0.05, "cp": 8.0, "fx": 0.06}
	var impact := {"bp": -16.0, "hp": -26.0, "sy": 1.14, "oy": 0.10, "oz": 0.16, "cp": -14.0, "fl_y": 0.14, "fr_y": 0.14, "flp": 22.0, "frp": 22.0}
	var sky := {"bp": -24.0, "hp": -34.0, "sy": 1.18, "oy": 0.20, "oz": 0.10, "cp": -18.0, "fl_y": 0.24, "fr_y": 0.24, "flp": 30.0, "frp": 30.0}
	var p := _kf([[0.0, guard], [0.3, load_p], [0.44, impact], [0.56, sky], [0.68, sky], [1.0, guard]], u)
	_add_feet(p, _step_feet("Punch3", u))
	_pose(p)


## ท่ากลางอากาศ — หมุนฟัน: side 1 = หมุนรอบตัวแนวนอน (ใบพัดฮอ) ปีกกางข้างฟันเป็นวง,
## side -1 = ตีลังกาวงล้อแนวตั้ง ปีกกางข้างกวาดเป็นวงใหญ่ ทั้งสองท่าหมุนเต็ม 1 รอบ
func _pose_air_cutter(u: float, side: int) -> void:
	var k := smoothstep(0.0, 0.9, u)
	var tuck := {"fl_y": 0.28, "fr_y": 0.24, "flp": 40.0, "frp": 45.0}
	var p: Dictionary
	if side == 1:
		p = {"by": -360.0 * k, "bp": 14.0, "br": 0.0, "hp": 6.0, "sy": 0.95, "cp": -10.0}
	else:
		p = {"bp": 360.0 * k, "by": 0.0, "hp": 10.0, "sy": 0.92, "oy": 0.1 * sin(PI * k), "cp": 8.0}
	for kk in tuck: p[kk] = tuck[kk]
	_pose(p)


func _pose_air_punch(u: float, side: int) -> void:
	var guard := {"bp": 10.0, "hp": -8.0, "fl_y": 0.30, "fl_z": -0.2, "fr_y": 0.22, "fr_z": -0.32, "flp": 40.0, "frp": 50.0}
	var strike := {"bp": 26.0, "by": -side * 60.0, "br": -side * 26.0, "hp": 14.0, "hy": -side * 14.0, "sy": 0.96, "oz": 0.12, "cp": 10.0,
		"fl_y": 0.34, "fl_z": -0.3, "fr_y": 0.28, "fr_z": -0.4, "flp": 45.0, "frp": 55.0}
	var p := _kf([[0.0, guard], [0.32, strike], [0.6, strike], [1.0, guard]], u)
	_pose(p)


## ตั้งการ์ด (บล็อก): หดตัว ก้มหัวซุก มงกุฎเอียงบังหน้า สั่นเบาๆ
func _pose_block(u: float) -> void:
	var b := _bounce_curve(fmod(u * 2.0, 1.0))
	_pose({"sy": 0.84 + 0.015 * b, "bp": 18.0, "hp": 22.0, "br": 2.0 * sin(TAU * u), "cp": 10.0, "fx": 0.08, "hr": 3.0 * sin(TAU * u)})


func _pose_block_hit(u: float) -> void:
	var e := _env(u, 0.12, 0.2)
	_pose({"sy": 0.84 - 0.06 * e, "bp": 18.0 - 8.0 * e, "hp": 22.0 + 6.0 * e, "oz": -0.12 * e, "br": 5.0 * e * sin(u * 60.0), "cp": 10.0 + 12.0 * e, "fx": 0.08})


## โดนต่อย: หัวสะบัดไปหลัง ตัวเอนถอย บีบตัวแล้วเด้งกลับ (power = ความแรง)
func _pose_hit(u: float, power: float) -> void:
	var e := _env(u, 0.1, 0.3)
	_pose({
		"bp": 6.0 - 22.0 * e * power, "by": 10.0 * e * power, "br": 5.0 * e * power,
		"hp": -3.0 - 20.0 * e * power, "hr": 6.0 * e * power, "oz": -0.12 * e * power, "sy": 1.0 + 0.05 * e * power,
		"cp": -16.0 * e * power, "fl_y": 0.02 * e, "fr_y": 0.02 * e,
	})


## Dash: โน้มตัวพุ่ง (DashF) / ถอยหลัง (DashB) เท้าเฉียดพื้น
func _pose_dash(u: float, side: int) -> void:
	var a := "DashF" if side > 0 else "DashB"
	var d: float = float(step_dist.get(a, 2.0 if side > 0 else 1.5)) * UNIT
	var e := _env(u, 0.12, 0.5)
	var disp := d * (1.0 - pow(1.0 - u, 2.5))
	var s1 := smoothstep(0.0, 0.5, u)
	var s2 := smoothstep(0.3, 0.85, u)
	var p := {"sy": 0.88 + 0.0 * e, "bp": (6.0 + 26.0 * e) * side, "hp": -18.0 * e * side, "oz": 0.1 * e * side, "cp": 8.0 * e * side}
	if side > 0:
		p["fl_z"] = -disp + s1 * d
		p["fr_z"] = -disp + s2 * d
		p["fl_y"] = 0.06 * sin(PI * s1)
		p["fr_y"] = 0.06 * sin(PI * s2)
	else:
		p["fr_z"] = disp - s1 * d
		p["fl_z"] = disp - s2 * d
		p["fr_y"] = 0.06 * sin(PI * s1)
		p["fl_y"] = 0.06 * sin(PI * s2)
	_pose(p)


## อัลติเมต - รวมพลัง: หดตัวสั่นเกร็ง แล้วยืดตัวเงยหน้า "กางปีก" ปล่อยพลัง
func _pose_ult_charge(u: float) -> void:
	var start := {"bp": 6.0, "hp": -3.0}
	var gather := {"sy": 0.80, "bp": 24.0, "hp": 22.0, "cp": 10.0, "fx": 0.1}
	var tense := {"sy": 0.74, "bp": 28.0, "hp": 26.0, "cp": 12.0, "fx": 0.12}
	var roar := {"sy": 1.16, "bp": -14.0, "hp": -34.0, "oy": 0.06, "cp": -20.0, "fl_y": 0.06, "fr_y": 0.06}
	var p := _kf([[0.0, start], [0.2, gather], [0.55, tense], [0.7, roar], [1.0, roar]], u)
	var tr: float = sin(u * 90.0) * 0.012 * smoothstep(0.15, 0.3, u) * (1.0 - smoothstep(0.55, 0.62, u))
	p["ox"] = _v(p, "ox") + tr
	_pose(p)


func _pose_ult_windup(u: float) -> void:
	var e := smoothstep(0.0, 0.35, u)
	var tr := sin(u * 110.0) * 0.016 * smoothstep(0.3, 1.0, u)
	_pose({"sy": lerpf(1.0, 0.76, e), "bp": lerpf(6.0, 28.0, e), "by": -lerpf(0.0, 34.0, e), "br": lerpf(0.0, 8.0, e),
		"hp": lerpf(-3.0, 18.0, e), "hy": lerpf(0.0, 30.0, e), "ox": tr, "fx": 0.1 * e, "cp": 10.0 * e})


# ---------- ท่าที่เป็น keyframe ล้วน ----------

const _KF_JUMP_PREP := [
	[0.0, {"bp": 6.0, "hp": -3.0}],
	[1.0, {"sy": 0.70, "bp": 16.0, "hp": 12.0, "cp": 8.0, "fx": 0.08}],
]
const _KF_JUMP_UP := [
	[0.0, {"sy": 1.22, "bp": 4.0, "hp": -8.0, "fl_y": 0.0, "fr_y": 0.0}],
	[1.0, {"sy": 1.06, "bp": 10.0, "hp": -2.0, "cp": -8.0, "fl_y": 0.34, "fr_y": 0.26, "fl_z": 0.06, "fr_z": 0.0, "flp": 25.0, "frp": 30.0}],
]
const _KF_JUMP_FALL := [
	[0.0, {"sy": 1.06, "bp": 10.0, "hp": -2.0, "fl_y": 0.34, "fr_y": 0.26, "flp": 25.0, "frp": 30.0}],
	[1.0, {"sy": 1.0, "bp": 8.0, "hp": 6.0, "cp": 6.0, "fl_y": 0.14, "fr_y": 0.12, "fl_z": 0.1, "fr_z": 0.08, "flp": 20.0, "frp": 20.0, "fx": 0.1}],
]
const _KF_LAND := [
	[0.0, {"sy": 0.68, "bp": 18.0, "hp": 16.0, "cp": 12.0, "fx": 0.12}],
	[0.4, {"sy": 0.76, "bp": 16.0, "hp": 12.0, "fx": 0.1}],
	[1.0, {"bp": 6.0, "hp": -3.0}],
]
const _KF_DIVE := [
	[0.0, {"sy": 0.86, "bp": 8.0, "hp": 6.0, "fx": 0.06}],
	[0.22, {"bp": -30.0, "hp": -10.0, "sy": 1.10, "fl_y": 0.35, "fr_y": 0.35, "flp": 30.0, "frp": 30.0, "cp": -14.0}],
	[0.40, {"bp": 48.0, "hp": 22.0, "sy": 0.84, "oz": 0.14, "fl_y": 0.5, "fl_z": -0.35, "fr_y": 0.5, "fr_z": -0.35, "flp": 55.0, "frp": 55.0, "cp": 22.0}],
	[0.66, {"bp": 48.0, "hp": 22.0, "sy": 0.84, "oz": 0.14, "fl_y": 0.5, "fl_z": -0.35, "fr_y": 0.5, "fr_z": -0.35, "flp": 55.0, "frp": 55.0, "cp": 22.0}],
	[0.84, {"bp": 24.0, "hp": 10.0, "sy": 0.92, "fl_y": 0.2, "fr_y": 0.2, "flp": 30.0, "frp": 30.0}],
	[1.0, {"sy": 0.9, "bp": 10.0, "hp": 8.0, "fl_y": 0.1, "fr_y": 0.1, "fx": 0.1}],
]
const _KF_KICK := [
	[0.0, {"sy": 0.86, "bp": 8.0, "hp": 6.0, "fx": 0.06}],
	[0.26, {"bp": -6.0, "hp": -6.0, "sy": 1.08, "fr_y": 0.38, "fr_z": 0.16, "frp": -10.0, "fl_y": 0.30, "flp": 30.0}],
	[0.38, {"bp": -24.0, "hp": -10.0, "sy": 1.06, "oz": 0.08, "fr_y": 0.62, "fr_z": 0.9, "frp": -35.0, "fl_y": 0.30, "fl_z": -0.1, "flp": 35.0, "cp": -14.0}],
	[0.52, {"bp": -24.0, "hp": -10.0, "sy": 1.06, "oz": 0.08, "fr_y": 0.62, "fr_z": 0.9, "frp": -35.0, "fl_y": 0.30, "fl_z": -0.1, "flp": 35.0, "cp": -14.0}],
	[0.70, {"bp": -4.0, "hp": -4.0, "sy": 1.04, "fr_y": 0.38, "fr_z": 0.16, "frp": -10.0, "fl_y": 0.28, "flp": 30.0}],
	[1.0, {"sy": 0.9, "bp": 10.0, "hp": 8.0, "fl_y": 0.1, "fr_y": 0.1, "fx": 0.1}],
]
const _KF_ULT_STRIKE := [
	[0.0, {"sy": 0.76, "bp": 28.0, "by": -34.0, "br": 8.0, "hp": 18.0, "hy": 30.0, "fx": 0.1, "cp": 10.0}],
	[0.28, {"sy": 1.15, "bp": -18.0, "by": 25.0, "br": -6.0, "hp": -22.0, "hy": -12.0, "oy": 0.05, "oz": 0.15, "cp": -16.0, "fl_y": 0.10, "fr_y": 0.10}],
	[0.5, {"sy": 1.22, "bp": -26.0, "by": 30.0, "br": -8.0, "hp": -34.0, "hy": -16.0, "oy": 0.16, "oz": 0.10, "cp": -20.0, "fl_y": 0.24, "fr_y": 0.24, "flp": 30.0, "frp": 30.0}],
	[1.0, {"sy": 1.22, "bp": -26.0, "by": 30.0, "br": -8.0, "hp": -34.0, "hy": -16.0, "oy": 0.16, "oz": 0.10, "cp": -20.0, "fl_y": 0.24, "fr_y": 0.24, "flp": 30.0, "frp": 30.0}],
]
## ล้มหงาย: ท้องฟ้า หัวไปด้านหลัง ขาชี้ฟ้า (ลำตัวหมุนรอบจุด Body จึงต้องยกตัวขึ้นให้หลังไม่จมพื้น)
const _KF_KNOCKDOWN := [
	[0.0, {"bp": -22.0, "hp": -22.0, "oy": 0.04, "oz": -0.10, "cp": -16.0}],
	[0.45, {"bp": -88.0, "hp": -8.0, "oy": 0.32, "oz": -0.05, "fl_y": 0.78, "fl_z": 0.32, "fr_y": 0.78, "fr_z": 0.32, "flp": -70.0, "frp": -70.0, "fx": 0.05}],
	[0.6, {"bp": -84.0, "hp": -10.0, "oy": 0.30, "oz": -0.05, "fl_y": 0.72, "fl_z": 0.30, "fr_y": 0.76, "fr_z": 0.30, "flp": -66.0, "frp": -72.0, "fx": 0.06}],
	[1.0, {"bp": -88.0, "hp": -8.0, "oy": 0.32, "oz": -0.05, "fl_y": 0.78, "fl_z": 0.32, "fr_y": 0.78, "fr_z": 0.32, "flp": -70.0, "frp": -70.0, "fx": 0.05}],
]
const _KF_GETUP := [
	[0.0, {"bp": -88.0, "hp": -8.0, "oy": 0.32, "oz": -0.05, "fl_y": 0.78, "fl_z": 0.32, "fr_y": 0.78, "fr_z": 0.32, "flp": -70.0, "frp": -70.0, "fx": 0.05}],
	[0.35, {"bp": -45.0, "hp": 6.0, "oy": 0.20, "oz": -0.02, "fl_y": 0.4, "fl_z": 0.4, "fr_y": 0.4, "fr_z": 0.4, "flp": -30.0, "frp": -30.0, "fx": 0.08}],
	[0.55, {"bp": 18.0, "hp": 14.0, "sy": 0.74, "oy": 0.0, "fx": 0.1, "cp": 10.0}],
	[0.8, {"bp": -4.0, "hp": -10.0, "sy": 1.12, "oy": 0.04, "cp": -8.0}],
	[1.0, {"bp": 6.0, "hp": -3.0}],
]
