extends RefCounted
## ชุดแอนิเมชันต่อสู้ที่สร้างจากโค้ด ใช้ได้กับทุกตัวละคร Meshy (โครงกระดูก mixamo เดียวกัน)
## ใช้: var rig = FighterRig.new(); rig.setup(model, anim_player); rig.build_all({...ความยาวท่า...})

var model: Node3D
var anim_player: AnimationPlayer
var L := {}
var idle_period := 2.4
var idle_crouch := 0.12
var idle_bounce := 0.03
## ระยะที่ตัวพุ่งไปข้างหน้าระหว่างท่า (เมตร) ใช้ให้เท้าก้าวตามตัวพอดี ไม่ไถล
var step_dist := {}

## ช่วงเวลาที่ตัวพุ่ง: เริ่มที่สัดส่วนนี้ของท่า และยาว LUNGE_LEN ของท่า
const LUNGE_START := {"Punch1": 0.0, "Punch2": 0.0, "Punch3": 0.3}
const LUNGE_LEN := 0.45


## 0..1 ความคืบหน้าของช่วงพุ่ง (ความเร็วพุ่ง = sin(PI * k))
static func lunge_k(a: String, t01: float) -> float:
	return clampf((t01 - LUNGE_START[a]) / LUNGE_LEN, 0.0, 1.0)


## ดึงแอนิเมชันจากไฟล์ glb อื่นของ Meshy (โครงกระดูกเดียวกัน) มาใส่ตัวละครนี้
func import_anim(path: String, new_name: String) -> String:
	if not ResourceLoader.exists(path):
		push_warning("ไม่พบไฟล์ " + path)
		return ""
	var res := load(path)
	if res is Animation:          # ท่าที่แยกไว้เป็นไฟล์ .res แล้ว (เวอร์ชันเบา ไม่ต้องโหลดโมเดลทั้งตัว)
		var an := (res as Animation).duplicate() as Animation
		an.loop_mode = Animation.LOOP_LINEAR
		_lib.add_animation(new_name, an)
		return new_name
	var inst := (res as PackedScene).instantiate()
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var result := ""
	if ap:
		for n in ap.get_animation_list():
			if not n.contains("001") and n != "RESET":
				var anim := ap.get_animation(n).duplicate() as Animation
				anim.loop_mode = Animation.LOOP_LINEAR
				_lib.add_animation(new_name, anim)
				result = new_name
				break
	inst.free()
	return result



# ===========================================================================
# แอนิเมชันที่สร้างจากโค้ด (อ้างอิง sprite sheet)
# พิกัดในพื้นที่ของโมเดล: หน้า = +Z, ซ้ายของตัวละคร = +X, บน = +Y
# เวกเตอร์ของแขน/ขาเขียนสำหรับข้างซ้าย แล้วสะท้อนแกน X ให้ข้างขวาอัตโนมัติ
# ===========================================================================
var _lib: AnimationLibrary
var _skel: Skeleton3D
var _skel_path := ""
var B := {}
var _rest_rot: Array = []
var _rest_pos: Array = []
var _foot_rest := {}
var _lrot: Array = []
var _lpos: Array = []

const GUARD_UP := Vector3(0.38, -0.62, 0.40)
const GUARD_FORE := Vector3(-0.30, 0.62, 0.72)


func build_all(lengths: Dictionary) -> void:
	L = lengths
	_make_anim("FightIdle", idle_period, true, _pose_idle)
	_make_anim("Punch1", L.Punch1, false, func(u): _pose_punch(u, 1))
	_make_anim("Punch2", L.Punch2, false, func(u): _pose_punch(u, -1))
	_make_anim("Punch3", L.Punch3, false, _pose_fire_uppercut)
	_make_anim("JumpPrep", L.get("JumpPrep", 0.1), false, _pose_jump_prep)
	_make_anim("JumpUp", 0.3, false, _pose_jump_up)
	_make_anim("JumpFall", 0.3, false, _pose_jump_fall)
	_make_anim("Block", 1.2, true, _pose_block)
	_make_anim("BlockHit", L.get("BlockHit", 0.3), false, _pose_block_hit)
	_make_anim("JumpKick", L.JumpKick, false, _pose_jump_kick)
	_make_anim("Land", L.Land, false, _pose_land)
	_make_anim("Hit", L.get("Hit", 0.4), false, func(u): _pose_hit(u, 1.0))
	_make_anim("HitHeavy", L.get("HitHeavy", 0.7), false, func(u): _pose_hit(u, 1.8))
	_make_anim("UltCharge", 1.1, false, _pose_ult_charge)
	_make_anim("AirPunch1", L.get("Punch1", 0.26), false, func(u): _pose_air_punch(u, 1))
	_make_anim("AirPunch2", L.get("Punch2", 0.26), false, func(u): _pose_air_punch(u, -1))
	_make_anim("UltWindup", 1.3, false, _pose_ult_windup)
	_make_anim("UltStrike", 0.5, false, _pose_ult_strike)
	_make_anim("KnockDown", 0.7, false, _pose_knockdown)
	_make_anim("GetUp", 1.0, false, _pose_getup)
	_make_anim("DashF", L.get("DashF", 0.3), false, func(u): _pose_dash(u, 1))
	_make_anim("DashB", L.get("DashB", 0.28), false, func(u): _pose_dash(u, -1))


# ---------- ท่าต่างๆ ----------

## Idle ท่าตั้งหมัด (อ้างอิง sprite sheet แถว 1-2 + หลักการ fighting idle):
## - ย่อเข่ากว้าง เข่าชี้ออก ขาซ้ายหน้า ลำตัวเฉียงเล็กน้อย ศอกกาง กำปั้นอยู่หน้าท้อง
## - เด้งแบบ "ลงเร็ว ขึ้นช้า" (ขึ้นใช้ 60% ของจังหวะ ลง 40%) ให้รู้สึกถึงน้ำหนัก
## - แขนเด้งตามลำตัวช้ากว่าเล็กน้อย (overlap) หัวนิ่งกว่าลำตัว
## - กำปั้นซ้าย/ขวาขยับสลับกัน + อกขยายเหมือนหายใจ + ถ่ายน้ำหนักช้าๆ
func _pose_idle(u: float) -> void:
	var beats := 4.0
	var h := _bounce_curve(fmod(u * beats, 1.0))
	var h_arm := _bounce_curve(fmod(u * beats - 0.12 + 1.0, 1.0))
	var h_head := _bounce_curve(fmod(u * beats - 0.2 + 1.0, 1.0))
	var sway := sin(TAU * u)
	var breath := sin(TAU * 2.0 * u)
	var alt := sin(TAU * 2.0 * u)

	# yaw/twist ติดลบ = ไหล่ซ้ายนำหน้า (สแตนซ์ขาซ้ายหน้า) หัวหมุนชดเชยให้มองตรง
	_p_hips(Vector3(0.02 * sway, -(idle_crouch - idle_bounce * h), 0.0), -8.0 + 3.0 * sway, -2.0 * sway)
	var lean := 18.0 - 3.0 * h
	_p_spine(lean - 1.5 * breath, -6.0)
	_p_head(-lean * 0.8 + 3.0 * h_head - 3.0 * h, 10.0 - 3.0 * sway)

	var up := Vector3(0.62, -0.62, 0.22) + Vector3(0.0, 0.05 * h_arm, 0.0)
	var fo := Vector3(-0.18, -0.20, 0.95)
	_p_arm(1, up + Vector3(0, 0.03 * alt, 0.02 * alt), fo + Vector3(0, 0.10 * alt, 0))
	_p_arm(-1, up + Vector3(0, -0.03 * alt, -0.02 * alt), fo + Vector3(0, -0.10 * alt, 0))

	_p_leg(1, Vector3(0.12, 0, 0.07), 0.55)
	_p_leg(-1, Vector3(0.12, 0, -0.05), 0.55)


## 0 = ต่ำสุด, 1 = สูงสุด : ขึ้นช้า (60%) ลงเร็ว (40%)
func _bounce_curve(p: float) -> float:
	if p < 0.6:
		return sin(PI * 0.5 * p / 0.6)
	return cos(PI * 0.5 * (p - 0.6) / 0.4)


## ท่าตั้งการ์ด (ฐานของการต่อย): ขาซ้ายหน้า ขาขวาหลัง ย่อเข่า
## lf / rf = ระยะเลื่อนเท้าซ้าย/ขวาเพิ่ม (จาก _step_feet)
func _stance(drop := 0.09, lean := 12.0, yaw := 0.0, twist := 0.0, fwd := 0.0, lf := Vector3.ZERO, rf := Vector3.ZERO) -> void:
	_p_hips(Vector3(0, -drop, fwd), yaw)
	_p_spine(lean, twist)
	_p_head(-lean * 0.8, -(yaw + twist) * 0.7)
	_p_leg(1, Vector3(0.08, 0, 0.09) + lf, 0.45)
	_p_leg(-1, Vector3(0.08, 0, -0.09) + rf, 0.45)


## ก้าวเท้าตามตัวที่พุ่งไปข้างหน้า: เท้าหน้า (ซ้าย) ก้าวนำก่อน แล้วเท้าหลัง (ขวา) ก้าวตาม
## เท้าที่ยังไม่ก้าวจะ "ติดพื้น" (เลื่อนถอยหลังในพื้นที่โมเดลเท่ากับที่ตัวพุ่งไป) จึงไม่ไถล
## คืนค่า [ระยะเลื่อนเท้าซ้าย, ระยะเลื่อนเท้าขวา]
func _step_feet(a: String, u: float) -> Array:
	if not a in step_dist or float(step_dist[a]) < 0.01:
		return [Vector3.ZERO, Vector3.ZERO]
	var d: float = step_dist[a]
	var k := lunge_k(a, u)
	var disp := d * (1.0 - cos(PI * k)) * 0.5        # ตัวพุ่งไปแล้วเท่าไร
	var s_lead := smoothstep(0.0, 0.65, k)
	var s_rear := smoothstep(0.4, 1.0, k)
	var lift := clampf(d / 0.3, 0.5, 1.0) * 0.09
	var lf := Vector3(0, lift * sin(PI * s_lead), -disp + s_lead * d)
	var rf := Vector3(0, lift * sin(PI * s_rear), -disp + s_rear * d)
	return [lf, rf]


## ต่อยตรง: side 1 = หมัดซ้าย (Jab), -1 = หมัดขวา (Cross)
func _pose_punch(u: float, side: int) -> void:
	var e := _env(u, 0.3, 0.45)
	var yaw := -side * 12.0 * e
	var twist := -side * 22.0 * e
	var feet := _step_feet("Punch1" if side > 0 else "Punch2", u)
	_stance(0.09, 12.0 + 4.0 * e, yaw, twist, 0.05 * e, feet[0], feet[1])
	var hit_up := Vector3(0.06, 0.02, 1.0)
	var hit_fore := Vector3(0.0, 0.03, 1.0)
	_p_arm(side, GUARD_UP.lerp(hit_up, e), GUARD_FORE.lerp(hit_fore, e))
	_p_arm(-side, GUARD_UP, GUARD_FORE)


## ต่อยกลางอากาศ (สไตล์ Dragon Ball): ท่อนบนเหมือนหมัดตรง แต่ขาพับไปด้านหลังลอยตัว ปลายเท้าชี้
## (อัลติเมตจะเอียงทั้งตัวลง ~45° ให้เป็นหมัดทิ่มลงจากด้านบน)
func _pose_air_punch(u: float, side: int) -> void:
	var e := _env(u, 0.3, 0.45)
	_p_hips(Vector3(0, 0, 0), -side * 12.0 * e, 0.0, -8.0)
	_p_spine(10.0 + 6.0 * e, -side * 24.0 * e)
	_p_head(-(10.0 + 6.0 * e) * 0.8 - 12.0, side * 10.0 * e)
	_p_arm(side, GUARD_UP.lerp(Vector3(0.06, 0.02, 1.0), e), GUARD_FORE.lerp(Vector3(0.0, 0.03, 1.0), e))
	_p_arm(-side, GUARD_UP, GUARD_FORE)
	_p_leg(1, Vector3(0.05, 0.32, -0.12), 0.3, 45.0)
	_p_leg(-1, Vector3(0.05, 0.18, -0.34), 0.3, 55.0)


## หมัดที่ 3: อัปเปอร์คัตหมัดขวา (อ้างอิงหลักมวย)
## 1) Load: ย่อเข่าลง เอียงตัวไปทางขวา บิดสะโพก/ไหล่ขวาไปหลัง หมัดขวาลดลงระดับท้อง ศอกงอ ~90°
## 2) Drive: ดันขาขึ้น ยกส้นเท้าขวาหมุนเข่าเข้า บิดสะโพกและไหล่ไปหน้า
##    หมัดพุ่ง "ขึ้นและไปข้างหน้า" โดยศอกยังงอ แล้วตามด้วยการชูขึ้นฟ้า
## 3) ค้างจังหวะกระแทกสั้นๆ  4) ดึงกลับการ์ด  มือซ้ายป้องคางตลอด
func _pose_fire_uppercut(u: float) -> void:
	var guard := {
		"drop": 0.09, "lean": 12.0, "yaw": 0.0, "twist": 0.0, "roll": 0.0, "look": 0.0, "heel": 0.0,
		"rup": GUARD_UP, "rfo": GUARD_FORE, "lup": GUARD_UP, "lfo": GUARD_FORE,
	}
	var load_p := {
		"drop": 0.21, "lean": 24.0, "yaw": -14.0, "twist": -20.0, "roll": 7.0, "look": -6.0, "heel": 0.0,
		"rup": Vector3(0.28, -0.95, -0.12), "rfo": Vector3(-0.05, 0.12, 1.0),
		"lup": Vector3(0.30, -0.55, 0.45), "lfo": Vector3(-0.45, 0.70, 0.55),
	}
	var impact := {
		"drop": 0.04, "lean": 2.0, "yaw": 20.0, "twist": 30.0, "roll": -5.0, "look": 10.0, "heel": 35.0,
		"rup": Vector3(0.05, 0.10, 1.0), "rfo": Vector3(-0.20, 1.0, 0.30),
		"lup": Vector3(0.40, -0.60, 0.35), "lfo": Vector3(-0.40, 0.72, 0.55),
	}
	var sky := {
		"drop": 0.02, "lean": -4.0, "yaw": 22.0, "twist": 32.0, "roll": -6.0, "look": 16.0, "heel": 40.0,
		"rup": Vector3(0.08, 0.75, 0.62), "rfo": Vector3(-0.10, 1.0, 0.05),
		"lup": Vector3(0.40, -0.60, 0.35), "lfo": Vector3(-0.40, 0.72, 0.55),
	}
	var p := _kf([[0.0, guard], [0.3, load_p], [0.44, impact], [0.56, sky], [0.68, sky], [1.0, guard]], u)

	_p_hips(Vector3(0, -p.drop, 0), p.yaw, p.roll)
	_p_spine(p.lean, p.twist)
	_p_head(-p.lean * 0.8 - p.look, -(p.yaw + p.twist) * 0.6)
	_p_arm(-1, p.rup, p.rfo)
	_p_arm(1, p.lup, p.lfo)
	var feet := _step_feet("Punch3", u)
	_p_leg(1, Vector3(0.08, 0, 0.09) + feet[0], 0.45)
	var heel_k: float = p.heel / 40.0
	_p_leg(-1, Vector3(0.08, 0.05 * heel_k, -0.09) + feet[1], lerpf(0.45, -0.15, heel_k), p.heel)


## ประมาณค่าระหว่าง keyframe: keys = [[เวลา 0..1, {พารามิเตอร์}], ...]
func _kf(keys: Array, u: float) -> Dictionary:
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if u <= b[0]:
			var t := smoothstep(a[0], b[0], u)
			var out := {}
			for k in a[1]:
				out[k] = lerp(a[1][k], b[1][k], t)
			return out
	return keys[-1][1]


## กระโดด 3 ช่วง (ตามหลักแอนิเมชัน: anticipation -> action -> follow-through)
## 1) JumpPrep: ย่อตัวลงเร็ว เหวี่ยงแขนไปหลัง เตรียมส่งแรง
func _pose_jump_prep(u: float) -> void:
	var e := smoothstep(0.0, 1.0, u)
	_p_hips(Vector3(0, -lerpf(0.09, 0.22, e), -0.02 * e))
	_p_spine(lerpf(12.0, 28.0, e))
	_p_head(-lerpf(12.0, 28.0, e) * 0.8 - 6.0 * e)
	var up := GUARD_UP.lerp(Vector3(0.30, -0.80, -0.50), e)
	var fo := GUARD_FORE.lerp(Vector3(0.10, -0.80, -0.35), e)
	_p_arm(1, up, fo)
	_p_arm(-1, up, fo)
	_p_leg(1, Vector3(0.06, 0, 0.05), 0.5)
	_p_leg(-1, Vector3(0.06, 0, -0.03), 0.5)


## 2) JumpUp: ส่งตัวขึ้น ขาเหยียดตรง ปลายเท้าชี้ลง แขนเหวี่ยงขึ้นหน้า -> ใกล้จุดสูงสุดพับเข่าขึ้น
func _pose_jump_up(u: float) -> void:
	var e := smoothstep(0.15, 1.0, u)
	_p_hips(Vector3(0, 0.0, 0.0), 0.0, 0.0, 6.0 * e)
	_p_spine(lerpf(-4.0, 14.0, e))
	_p_head(-lerpf(-4.0, 14.0, e) * 0.8 - 8.0 * (1.0 - e))
	var up := Vector3(0.30, 0.55, 0.75).lerp(Vector3(0.50, -0.45, 0.40), e)
	var fo := Vector3(0.00, 0.95, 0.35).lerp(Vector3(-0.20, 0.70, 0.60), e)
	_p_arm(1, up, fo)
	_p_arm(-1, up, fo)
	_p_leg(1, Vector3(0.02, lerpf(-0.02, 0.34, e), lerpf(-0.02, 0.08, e)), 0.3, lerpf(45.0, 25.0, e))
	_p_leg(-1, Vector3(0.02, lerpf(-0.02, 0.24, e), lerpf(-0.06, 0.0, e)), 0.3, lerpf(50.0, 30.0, e))


## 3) JumpFall: ขาคลายลงเตรียมรับพื้น กางเท้า แขนกางออกข้างทรงตัว (ค้างท่าจนแตะพื้น)
func _pose_jump_fall(u: float) -> void:
	var e := smoothstep(0.0, 1.0, u)
	_p_hips(Vector3(0, 0.0, 0.0), 0.0, 0.0, 6.0 * (1.0 - e))
	_p_spine(lerpf(14.0, 10.0, e))
	_p_head(-lerpf(14.0, 10.0, e) * 0.8 + 4.0 * e)
	var up := Vector3(0.50, -0.45, 0.40).lerp(Vector3(0.85, -0.15, 0.25), e)
	var fo := Vector3(-0.20, 0.70, 0.60).lerp(Vector3(0.55, 0.25, 0.45), e)
	_p_arm(1, up, fo)
	_p_arm(-1, up, fo)
	_p_leg(1, Vector3(lerpf(0.02, 0.09, e), lerpf(0.34, 0.08, e), lerpf(0.08, 0.05, e)), 0.4, lerpf(25.0, 12.0, e))
	_p_leg(-1, Vector3(lerpf(0.02, 0.09, e), lerpf(0.24, 0.06, e), lerpf(0.0, -0.03, e)), 0.4, lerpf(30.0, 12.0, e))


## บล็อก (peek-a-boo): ย่อต่ำ ก้มหัว ศอกชิดลำตัว ท่อนแขนตั้งบังหน้า กำปั้นอยู่ระดับหน้าผาก
func _block_base(bounce: float, push: float) -> void:
	_p_hips(Vector3(0, -0.13 + 0.015 * bounce, -0.06 * push), -8.0, 0.0)
	var lean := 22.0 - 12.0 * push
	_p_spine(lean, -4.0)
	_p_head(-lean * 0.6 + 8.0, 8.0)
	var up := Vector3(0.18, -0.45, 0.88).lerp(Vector3(0.30, -0.35, 0.60), push)
	var fo := Vector3(-0.15, 0.95, 0.25).lerp(Vector3(-0.10, 0.95, -0.05), push)
	_p_arm(1, up, fo)
	_p_arm(-1, up, fo)
	_p_leg(1, Vector3(0.10, 0, 0.07), 0.5)
	_p_leg(-1, Vector3(0.10, 0, -0.07), 0.5)


func _pose_block(u: float) -> void:
	_block_base(_bounce_curve(fmod(u * 2.0, 1.0)), 0.0)


## โดนตีตอนบล็อก: แขนถูกดันเข้าหาหน้า ตัวถอยไปหลังนิดหนึ่ง แล้วกลับท่าบล็อก
func _pose_block_hit(u: float) -> void:
	_block_base(0.0, _env(u, 0.12, 0.2))


## กระโดดเตะหน้า (อ้างอิงหลัก flying front kick):
## 1) Takeoff: เข่าซ้ายดันขึ้นส่งตัว "ไปข้างหน้า" ขาขวาเหยียดส่งแรงจากพื้น
## 2) Chamber: ยกเข่าขวาสูงระดับสะโพก ขาท่อนล่างพับ มือป้องหน้า
## 3) Extension: เหยียดขาขวาออกเร็ว (snap) กระดกปลายเท้า ใช้โคนนิ้วเท้ากระแทก ตัวเอนหลังถ่วงน้ำหนัก
##    แขนขวาเหวี่ยงลงหลังสวนทางขา มือซ้ายอยู่ที่หน้า
## 4) Retract: ดึงขากลับเป็นท่า chamber  5) Landing: ขาคลายลงเตรียมรับพื้น
func _pose_jump_kick(u: float) -> void:
	var takeoff := {
		"lean": 10.0, "pitch": 0.0, "yaw": 0.0, "lf": Vector3(0.02, 0.28, 0.10),
		"th": Vector3(0.0, -1.0, -0.25), "sh": Vector3(0.0, -1.0, -0.35), "fp": 40.0,
		"lup": GUARD_UP, "lfo": GUARD_FORE, "rup": GUARD_UP, "rfo": GUARD_FORE,
	}
	var chamber := {
		"lean": 2.0, "pitch": 0.0, "yaw": 8.0, "lf": Vector3(0.03, 0.30, 0.02),
		"th": Vector3(-0.05, 0.40, 1.0), "sh": Vector3(0.0, -1.0, -0.05), "fp": 20.0,
		"lup": Vector3(0.30, -0.55, 0.50), "lfo": Vector3(-0.35, 0.75, 0.55),
		"rup": Vector3(0.30, -0.55, 0.50), "rfo": Vector3(-0.35, 0.75, 0.55),
	}
	var extend := {
		"lean": -18.0, "pitch": -12.0, "yaw": 14.0, "lf": Vector3(0.03, 0.26, -0.02),
		"th": Vector3(-0.05, 0.32, 1.0), "sh": Vector3(-0.03, 0.22, 1.0), "fp": -10.0,
		"lup": Vector3(0.30, -0.55, 0.50), "lfo": Vector3(-0.35, 0.75, 0.55),
		"rup": Vector3(0.45, -0.60, -0.45), "rfo": Vector3(0.10, -0.60, -0.50),
	}
	var land := {
		"lean": 10.0, "pitch": 0.0, "yaw": 0.0, "lf": Vector3(0.09, 0.08, 0.05),
		"th": Vector3(0.05, -1.0, 0.25), "sh": Vector3(0.0, -1.0, -0.15), "fp": 12.0,
		"lup": GUARD_UP, "lfo": GUARD_FORE, "rup": GUARD_UP, "rfo": GUARD_FORE,
	}
	var p := _kf([[0.0, takeoff], [0.26, chamber], [0.38, extend], [0.52, extend], [0.7, chamber], [1.0, land]], u)
	_p_hips(Vector3.ZERO, p.yaw, 0.0, p.pitch)
	_p_spine(p.lean, p.yaw * 0.5)
	_p_head(-p.lean * 0.8 + 4.0, -p.yaw * 1.2)
	_p_arm(1, p.lup, p.lfo)
	_p_arm(-1, p.rup, p.rfo)
	_p_leg(1, p.lf, 0.3, 30.0)
	# ขาเตะ (ขวา): กำหนดทิศต้นขา/หน้าแข้งตรงๆ แล้วหมุนเท้า
	var up_i: int = _b(-1, "UpLeg")
	var low_i: int = _b(-1, "Leg")
	var foot_i: int = _b(-1, "Foot")
	_aim(up_i, low_i, p.th * Vector3(-1, 1, 1))
	_aim(low_i, foot_i, p.sh * Vector3(-1, 1, 1))
	var shin_q := Quaternion(Vector3.DOWN, (p.sh as Vector3).normalized())
	_set_global_rot(foot_i, Basis(shin_q) * Basis(Vector3.RIGHT, deg_to_rad(p.fp)) * (_foot_rest[-1] as Transform3D).basis)


## Dash (ก้าวพุ่งแบบนักมวย): side 1 = พุ่งหน้า, -1 = ถอยหลัง
## ย่อต่ำ โน้มตัวเข้าหาทิศที่พุ่ง การ์ดชิดตัว เท้าไม่ยกสูง (ไถลเฉียดพื้น)
## เท้าที่อยู่ทางทิศพุ่งก้าวนำก่อน เท้าอีกข้างดัน (ยกส้น) แล้วตามไปทีหลัง ระยะก้าวตรงกับระยะที่ตัวพุ่ง
func _pose_dash(u: float, side: int) -> void:
	var a := "DashF" if side > 0 else "DashB"
	var d: float = step_dist.get(a, 2.0 if side > 0 else 1.5)
	var e := _env(u, 0.12, 0.5)
	var disp := d * (1.0 - pow(1.0 - u, 2.5))          # ความเร็ว ~ (1-u)^1.5 : ออกตัวแรง แล้วเบรก
	var s_first := smoothstep(0.0, 0.5, u)
	var s_second := smoothstep(0.3, 0.85, u)
	var lift := 0.05
	var lf: Vector3
	var rf: Vector3
	if side > 0:
		_p_hips(Vector3(0, -(0.09 + 0.08 * e), 0.04 * e), -6.0 * e, 0.0, 6.0 * e)
		var lean := 12.0 + 22.0 * e
		_p_spine(lean, -4.0 * e)
		_p_head(-lean * 0.9)
		lf = Vector3(0, lift * sin(PI * s_first), -disp + s_first * d)
		rf = Vector3(0, lift * sin(PI * s_second), -disp + s_second * d)
		_p_leg(1, Vector3(0.08, 0, 0.09) + lf, 0.45)
		_p_leg(-1, Vector3(0.08, 0.03 * e * (1.0 - s_second), -0.09) + rf, 0.45, 30.0 * e * (1.0 - s_second))
	else:
		_p_hips(Vector3(0, -(0.09 + 0.05 * e), -0.03 * e), 4.0 * e, 0.0, -4.0 * e)
		var lean2 := 12.0 - 6.0 * e
		_p_spine(lean2, 4.0 * e)
		_p_head(-lean2 * 0.8)
		rf = Vector3(0, lift * sin(PI * s_first), disp - s_first * d)
		lf = Vector3(0, lift * sin(PI * s_second), disp - s_second * d)
		_p_leg(1, Vector3(0.08, 0.03 * e * (1.0 - s_second), 0.09) + lf, 0.45, 30.0 * e * (1.0 - s_second))
		_p_leg(-1, Vector3(0.08, 0, -0.09) + rf, 0.45)
	var up := GUARD_UP.lerp(Vector3(0.25, -0.70, 0.45), e)
	var fo := GUARD_FORE.lerp(Vector3(-0.38, 0.68, 0.62), e)
	_p_arm(1, up, fo)
	_p_arm(-1, up, fo)


## อัลติเมต - รวมพลัง: ย่อลึก ดึงกำปั้นไว้ข้างเอว ศอกไปหลัง ก้มหัวเก็บแรง
## แล้วช่วงท้ายยืดอก กางแขนลงข้างลำตัว เงยหน้าคำราม (ปลดปล่อยพลัง)
func _pose_ult_charge(u: float) -> void:
	var gather := {
		"drop": 0.2, "lean": 26.0, "look": -18.0, "twist": 0.0,
		"up": Vector3(0.22, -0.75, -0.55), "fo": Vector3(0.05, 0.1, 1.0), "spread": 0.14,
	}
	var tense := {
		"drop": 0.22, "lean": 30.0, "look": -22.0, "twist": 0.0,
		"up": Vector3(0.25, -0.70, -0.62), "fo": Vector3(0.0, 0.2, 1.0), "spread": 0.15,
	}
	var roar := {
		"drop": 0.12, "lean": -12.0, "look": 22.0, "twist": 0.0,
		"up": Vector3(0.80, -0.55, -0.15), "fo": Vector3(0.55, -0.35, 0.25), "spread": 0.16,
	}
	var start := {
		"drop": 0.09, "lean": 12.0, "look": 0.0, "twist": 0.0,
		"up": GUARD_UP, "fo": GUARD_FORE, "spread": 0.08,
	}
	var p := _kf([[0.0, start], [0.2, gather], [0.55, tense], [0.7, roar], [1.0, roar]], u)
	# สั่นเกร็งระหว่างรวมพลัง
	var tremble: float = sin(u * 90.0) * 0.006 * smoothstep(0.15, 0.3, u) * (1.0 - smoothstep(0.55, 0.62, u))
	_p_hips(Vector3(tremble, -p.drop, 0))
	_p_spine(p.lean)
	_p_head(-p.lean * 0.8 - p.look)
	_p_arm(1, p.up, p.fo)
	_p_arm(-1, p.up, p.fo)
	_p_leg(1, Vector3(p.spread, 0, 0.04), 0.7)
	_p_leg(-1, Vector3(p.spread, 0, -0.04), 0.7)


## ง้างหมัดจากด้านล่าง (ปิดท้ายอัลติเมต): ย่อลึกมาก เอียงไหล่ขวาลงต่ำ บิดตัวไปทางขวา
## หมัดขวาลดต่ำอยู่ระดับเข่า ศอกงอ ~90° มือซ้ายป้องหน้า เงยมองเป้า ยิ่งนานยิ่งสั่นเกร็ง
func _pose_ult_windup(u: float) -> void:
	var e := smoothstep(0.0, 0.35, u)
	var tremble := sin(u * 110.0) * 0.008 * smoothstep(0.3, 1.0, u)
	_p_hips(Vector3(tremble, -lerpf(0.09, 0.27, e), -0.03 * e), -lerpf(0.0, 26.0, e), lerpf(0.0, 9.0, e))
	var lean := lerpf(12.0, 30.0, e)
	_p_spine(lean, -lerpf(0.0, 34.0, e))
	_p_head(-lean * 0.8 - 14.0 * e, lerpf(0.0, 45.0, e))
	_p_arm(-1, GUARD_UP.lerp(Vector3(0.30, -0.92, -0.25), e), GUARD_FORE.lerp(Vector3(0.0, -0.25, 1.0), e))
	_p_arm(1, GUARD_UP.lerp(Vector3(0.30, -0.55, 0.50), e), GUARD_FORE.lerp(Vector3(-0.38, 0.75, 0.55), e))
	_p_leg(1, Vector3(lerpf(0.08, 0.14, e), 0, lerpf(0.09, 0.22, e)), 0.6)
	_p_leg(-1, Vector3(lerpf(0.08, 0.14, e), 0, lerpf(-0.09, -0.2, e)), 0.6, 10.0 * e)


## ปล่อยหมัดเสยจากด้านล่าง: ดันขาเหยียดขึ้นทั้งตัว สะโพก-ไหล่หมุนไปหน้า
## หมัดขวาพุ่งขึ้นและไปหน้า ผ่านคาง แล้วชูสุดเหนือหัว ตัวเอนหลัง ยกส้นเท้าหลัง มือซ้ายดึงกลับอก
func _pose_ult_strike(u: float) -> void:
	var cocked := {
		"drop": 0.27, "yaw": -26.0, "roll": 9.0, "lean": 30.0, "twist": -34.0, "look": 14.0, "hy": 45.0, "heel": 10.0, "lift": 0.0,
		"rup": Vector3(0.30, -0.92, -0.25), "rfo": Vector3(0.0, -0.25, 1.0),
		"lup": Vector3(0.30, -0.55, 0.50), "lfo": Vector3(-0.38, 0.75, 0.55),
	}
	var impact := {
		"drop": 0.02, "yaw": 20.0, "roll": -6.0, "lean": -4.0, "twist": 32.0, "look": 18.0, "hy": -20.0, "heel": 40.0, "lift": 0.05,
		"rup": Vector3(0.06, 0.35, 1.0), "rfo": Vector3(-0.15, 1.0, 0.35),
		"lup": Vector3(0.45, -0.60, 0.25), "lfo": Vector3(-0.45, 0.70, 0.45),
	}
	var sky := {
		"drop": 0.0, "yaw": 24.0, "roll": -8.0, "lean": -12.0, "twist": 36.0, "look": 30.0, "hy": -24.0, "heel": 45.0, "lift": 0.07,
		"rup": Vector3(0.08, 0.92, 0.38), "rfo": Vector3(-0.08, 1.0, 0.02),
		"lup": Vector3(0.45, -0.60, 0.25), "lfo": Vector3(-0.45, 0.70, 0.45),
	}
	var p := _kf([[0.0, cocked], [0.28, impact], [0.5, sky], [1.0, sky]], u)
	_p_hips(Vector3(0, -p.drop + p.lift, 0.05), p.yaw, p.roll)
	_p_spine(p.lean, p.twist)
	_p_head(-p.lean * 0.8 - p.look, p.hy)
	_p_arm(-1, p.rup, p.rfo)
	_p_arm(1, p.lup, p.lfo)
	_p_leg(1, Vector3(0.14, 0.0, 0.22), 0.6, 20.0 * (p.lift as float) / 0.07)
	var hk: float = (p.heel as float) / 45.0
	_p_leg(-1, Vector3(0.14, 0.05 * hk, -0.2), lerpf(0.6, -0.1, hk), p.heel)


## ท่าล้มหงาย (หลังโดนหมัดปิดท้าย): ก้นกระแทกพื้น -> หลังลงนอนราบ ขาเหยียดไปหน้า แขนกางบนพื้น
func _pose_knockdown(u: float) -> void:
	var hit := smoothstep(0.0, 0.45, u)
	var settle := sin(PI * clampf((u - 0.45) / 0.3, 0.0, 1.0)) * 0.04      # เด้งเล็กน้อยตอนกระแทก
	_lie(lerpf(-35.0, -84.0, hit), lerpf(0.3, 0.56, hit) - settle, lerpf(0.0, -0.25, hit), hit)


## ลุกขึ้น: นอน -> ลุกนั่งเท้าแขน -> ย่อยองชันเข่า -> ยืดตัวกลับท่าตั้งการ์ด
func _pose_getup(u: float) -> void:
	if u < 0.35:
		var k := smoothstep(0.0, 0.35, u)
		_lie(lerpf(-84.0, -25.0, k), lerpf(0.56, 0.5, k), lerpf(-0.25, -0.15, k), 1.0 - 0.5 * k)
	else:
		var k2 := smoothstep(0.35, 1.0, u)
		_p_hips(Vector3(0, -lerpf(0.42, 0.09, k2), lerpf(-0.1, 0.0, k2)), 0.0, 0.0, lerpf(-10.0, 0.0, k2))
		_p_spine(lerpf(40.0, 12.0, k2))
		_p_head(-lerpf(40.0, 12.0, k2) * 0.8)
		_p_arm(1, Vector3(0.45, -0.8, 0.35).lerp(GUARD_UP, k2), Vector3(0.1, -0.6, 0.8).lerp(GUARD_FORE, k2))
		_p_arm(-1, Vector3(0.45, -0.8, 0.35).lerp(GUARD_UP, k2), Vector3(0.1, -0.6, 0.8).lerp(GUARD_FORE, k2))
		_p_leg(1, Vector3(0.1, 0, lerpf(0.15, 0.09, k2)), 0.6)
		_p_leg(-1, Vector3(0.1, 0, lerpf(0.0, -0.09, k2)), 0.6)


## ท่านอน/ครึ่งนอน: pitch = เอนหลัง (องศาติดลบ), drop = สะโพกลงกี่เมตร, back = สะโพกถอยหลัง, flat = 0..1 ความราบ
func _lie(pitch: float, drop: float, back: float, flat: float) -> void:
	_p_hips(Vector3(0, -drop, back), 0.0, 0.0, pitch)
	_p_spine(lerpf(10.0, 4.0, flat))
	_p_head(lerpf(-6.0, 12.0, flat))
	# แขน: ท้าวหลัง -> กางราบบนพื้น
	_p_arm(1, Vector3(0.5, -0.8, -0.2).lerp(Vector3(0.95, -0.05, -0.3), flat), Vector3(0.1, -0.9, 0.2).lerp(Vector3(0.9, 0.05, 0.4), flat))
	_p_arm(-1, Vector3(0.5, -0.8, -0.2).lerp(Vector3(0.95, -0.05, -0.3), flat), Vector3(0.1, -0.9, 0.2).lerp(Vector3(0.9, 0.05, 0.4), flat))
	# ขา: เท้าวางพื้นด้านหน้า เข่าชันขึ้นเมื่อยังไม่ราบ
	for side in [1, -1]:
		var rest: Transform3D = _foot_rest[side]
		var target := rest.origin + Vector3(0.12 * side, 0.0, lerpf(0.35, 0.75, flat))
		_leg_ik(_b(side, "UpLeg"), _b(side, "Leg"), _b(side, "Foot"), target, Vector3(0.2 * side, 1.0, 0.3))
		_set_global_rot(_b(side, "Foot"), Basis(Vector3.RIGHT, deg_to_rad(-60.0 * flat)) * rest.basis)


## ลงพื้น (ตาม sprite sheet): นั่งยองลึก เข่ากางออก ตัวงุ้ม แขนห้อยไปข้างหน้าระหว่างเข่า
func _pose_land(u: float) -> void:
	var e := 1.0 - smoothstep(0.35, 1.0, u)          # ค้างท่ายองช่วงแรกแล้วค่อยลุก
	var hit := smoothstep(0.0, 0.12, u)               # ยุบลงเร็วตอนเท้าแตะพื้น
	var k := e * hit + (1.0 - hit) * 0.4
	_p_hips(Vector3(0, -lerpf(0.13, 0.33, k), -0.03 * k))
	var lean := lerpf(21.0, 42.0, k)
	_p_spine(lean)
	_p_head(-lean * 0.85)
	var up := Vector3(0.72, -0.62, 0.05).lerp(Vector3(0.35, -0.80, 0.40), k)
	var fo := Vector3(0.10, -0.75, 0.55).lerp(Vector3(-0.05, -0.70, 0.70), k)
	_p_arm(1, up, fo)
	_p_arm(-1, up, fo)
	var spread := lerpf(0.13, 0.15, k)
	_p_leg(1, Vector3(spread, 0, 0.03), lerpf(0.6, 0.9, k))
	_p_leg(-1, Vector3(spread, 0, -0.02), lerpf(0.6, 0.9, k))


## โดนต่อย: หัวสะบัดไปหลัง ลำตัวเอนหลัง แขนหลุดการ์ด แล้วค่อยกลับท่าตั้งการ์ด (power = ความแรง)
func _pose_hit(u: float, power: float) -> void:
	var e := _env(u, 0.1, 0.3)
	_p_hips(Vector3(0, -0.09 - 0.04 * e * power, -0.05 * e * power), -8.0 * e * power, 4.0 * e * power)
	var lean := 12.0 - 22.0 * e * power
	_p_spine(lean, 12.0 * e * power)
	_p_head(-lean * 0.8 - 18.0 * e * power, 10.0 * e * power)
	var up := GUARD_UP.lerp(Vector3(0.75, -0.35 + 0.2 * (power - 1.0), 0.05), e)
	var fo := GUARD_FORE.lerp(Vector3(0.20, 0.40, 0.60), e)
	_p_arm(1, up, fo)
	_p_arm(-1, up, fo)
	_p_leg(1, Vector3(0.08, 0, 0.09), 0.45)
	_p_leg(-1, Vector3(0.08, 0, -0.09), 0.45)


## ขึ้นเร็วถึง 1 ที่ peak ค้างไว้ถึง hold แล้วค่อยลดกลับเป็น 0 ที่ end
func _env(u: float, peak: float, hold: float, end := 1.0) -> float:
	if u < peak:
		return smoothstep(0.0, peak, u)
	if u < hold:
		return 1.0
	return 1.0 - smoothstep(hold, end, u)


# ---------- ตัวช่วยจัดท่า ----------

func _p_hips(offset: Vector3, yaw := 0.0, roll := 0.0, pitch := 0.0) -> void:
	_lpos[B.Hips] = _rest_pos[B.Hips] + offset
	_rot_global(B.Hips, Quaternion(Vector3.UP, deg_to_rad(yaw)) * Quaternion(Vector3.BACK, deg_to_rad(roll)) * Quaternion(Vector3.RIGHT, deg_to_rad(pitch)))


## lean = องศาโน้มหน้ารวม (กระจาย 3 ข้อ), twist = บิดลำตัว (+ = ไหล่ขวาไปหน้า)
func _p_spine(lean: float, twist := 0.0) -> void:
	for b in [B.Spine, B.Spine1, B.Spine2]:
		_rot_global(b, Quaternion(Vector3.UP, deg_to_rad(twist / 3.0)) * Quaternion(Vector3.RIGHT, deg_to_rad(lean / 3.0)))


func _p_head(pitch: float, yaw := 0.0) -> void:
	_rot_global(B.Neck, Quaternion(Vector3.RIGHT, deg_to_rad(pitch * 0.45)))
	_rot_global(B.Head, Quaternion(Vector3.UP, deg_to_rad(yaw)) * Quaternion(Vector3.RIGHT, deg_to_rad(pitch * 0.55)))


func _p_arm(side: int, upper_dir: Vector3, fore_dir: Vector3) -> void:
	var m := Vector3(side, 1, 1)
	_aim(_b(side, "Arm"), _b(side, "ForeArm"), upper_dir * m)
	_aim(_b(side, "ForeArm"), _b(side, "Hand"), fore_dir * m)


## foot_offset = ระยะเท้าจากตำแหน่ง rest (y > 0 = ยกเท้า), pole_out = เข่าชี้ออกนอกแค่ไหน
## toe_down = องศาที่ปลายเท้าชี้ลง (ใช้ตอนลอยตัว)
func _p_leg(side: int, foot_offset: Vector3, pole_out := 0.4, toe_down := 0.0) -> void:
	var m := Vector3(side, 1, 1)
	var rest: Transform3D = _foot_rest[side]
	_leg_ik(_b(side, "UpLeg"), _b(side, "Leg"), _b(side, "Foot"), rest.origin + foot_offset * m, Vector3(pole_out * side, 0.0, 1.0))
	_set_global_rot(_b(side, "Foot"), Basis(Vector3.RIGHT, deg_to_rad(toe_down)) * rest.basis)


func _b(side: int, part: String) -> int:
	return B[("Left" if side > 0 else "Right") + part]


# ---------- ระบบโครงกระดูก ----------

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
		push_warning("ไม่พบ Skeleton3D")
		return false
	for n in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
			"LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand",
			"LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]:
		B[n] = _bone(n)
		if B[n] < 0:
			push_warning("ไม่พบกระดูก " + n)
			return false
	for i in _skel.get_bone_count():
		var r := _skel.get_bone_rest(i)
		_rest_rot.append(r.basis.get_rotation_quaternion())
		_rest_pos.append(r.origin)
	_lrot = _rest_rot.duplicate()
	_lpos = _rest_pos.duplicate()
	_foot_rest[1] = _glob(B.LeftFoot)
	_foot_rest[-1] = _glob(B.RightFoot)
	_skel_path = String(anim_player.get_node(anim_player.root_node).get_path_to(_skel))
	return true


func _make_anim(anim_name: String, length: float, loop: bool, pose: Callable, steps := 30) -> void:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var count := _skel.get_bone_count()
	for i in count:
		var t := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, NodePath(_skel_path + ":" + _skel.get_bone_name(i)))
	var hips_track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hips_track, NodePath(_skel_path + ":" + _skel.get_bone_name(B.Hips)))
	for k in steps + 1:
		var u := float(k) / steps
		_lrot = _rest_rot.duplicate()
		_lpos = _rest_pos.duplicate()
		pose.call(u)
		for i in count:
			anim.rotation_track_insert_key(i, length * u, _lrot[i])
		anim.position_track_insert_key(hips_track, length * u, _lpos[B.Hips])
	_lib.add_animation(anim_name, anim)


func _bone(n: String) -> int:
	for i in _skel.get_bone_count():
		var bn := _skel.get_bone_name(i)
		if bn == n or bn.ends_with(":" + n) or bn.ends_with("_" + n):
			return i
	return -1


func _glob(i: int) -> Transform3D:
	var t := Transform3D(Basis(_lrot[i] as Quaternion), _lpos[i] as Vector3)
	var p := _skel.get_bone_parent(i)
	return _glob(p) * t if p >= 0 else t


func _parent_basis(i: int) -> Basis:
	var p := _skel.get_bone_parent(i)
	return _glob(p).basis.orthonormalized() if p >= 0 else Basis()


func _set_global_rot(i: int, global_basis: Basis) -> void:
	_lrot[i] = (_parent_basis(i).inverse() * global_basis.orthonormalized()).get_rotation_quaternion()


func _rot_global(i: int, q: Quaternion) -> void:
	_set_global_rot(i, Basis(q) * _glob(i).basis.orthonormalized())


func _aim(i: int, child: int, dir: Vector3) -> void:
	var cur := (_glob(child).origin - _glob(i).origin).normalized()
	_rot_global(i, Quaternion(cur, dir.normalized()))


func _leg_ik(up: int, low: int, foot: int, target: Vector3, pole: Vector3) -> void:
	var a := _glob(up).origin
	var l1 := a.distance_to(_glob(low).origin)
	var l2 := _glob(low).origin.distance_to(_glob(foot).origin)
	var to := target - a
	var d := clampf(to.length(), 0.01, l1 + l2 - 0.001)
	var dir := to.normalized()
	var p := (pole - dir * pole.dot(dir)).normalized()
	var ca := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var knee := a + dir * (l1 * ca) + p * (l1 * sqrt(1.0 - ca * ca))
	_aim(up, low, knee - a)
	_aim(low, foot, (a + dir * d) - _glob(low).origin)
