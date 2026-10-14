extends "res://scripts/fighter_rig.gd"
## ชุดแอนิเมชันของกาจอมยุทธ์ — ใช้ท่าพื้นฐานของ FighterRig (โครงกระดูกชื่อเดียวกับ mixamo)
## แต่เปลี่ยนท่าโจมตีเป็น "ฟันดาบสองมือ" : มือทั้งสองจับด้ามดาบเดียวกัน (IK แขน) ใบดาบชี้ตามแกน +Y ของมือขวา
## ท่าทั้งหมดอิงกรอบของอก (Spine2): +X = ซ้ายของตัวละคร, +Y = บน, +Z = หน้า

const Blade := preload("res://scripts/crow_blade.gd")
var blade: Node3D
var _tm := 0.0

## ท่าพร้อมรบ (ถือดาบกลางตัว ปลายดาบชี้ไปข้างหน้าเฉียงขึ้น)
const READY := {
	"drop": 0.10, "lean": 10.0, "yaw": -10.0, "twist": -6.0,
	"g": Vector3(-0.10, -0.14, 0.34), "b": Vector3(0.05, 0.75, 0.66),
	"lf": Vector3.ZERO, "rf": Vector3.ZERO, "fwd": 0.0,
}


func setup(p_model: Node3D, p_anim_player: AnimationPlayer) -> bool:
	if not p_anim_player.has_animation_library(""):
		p_anim_player.add_animation_library("", AnimationLibrary.new())
	if not super.setup(p_model, p_anim_player):
		return false
	var att := BoneAttachment3D.new()
	att.name = "BladeAttach"
	att.bone_name = _skel.get_bone_name(B.RightHand)
	_skel.add_child(att)
	blade = Blade.new()
	blade.name = "Katana"
	blade.position = Vector3(0, -0.06, 0)
	att.add_child(blade)
	var vc := StandardMaterial3D.new()          # สีของกาเก็บเป็นสีที่จุดยอด (COLOR_0)
	vc.vertex_color_use_as_albedo = true
	vc.roughness = 0.85
	vc.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mi in _skel.find_children("*", "MeshInstance3D", true, false):
		blade.back_mesh = mi
		blade.back_mat = vc
		for si in (mi as MeshInstance3D).mesh.get_surface_count():
			(mi as MeshInstance3D).set_surface_override_material(si, vc)
		break
	return true


## เรียกจาก player: ชักดาบออกมาตลอดท่า (sec วินาที)
func draw_blade(sec: float) -> void:
	if blade:
		blade.draw(sec)


func import_anim(_path: String, new_name: String) -> String:
	return new_name if _lib.has_animation(new_name) else ""


func build_all(lengths: Dictionary) -> void:
	super.build_all(lengths)
	for n in ["Punch1", "Punch2", "Punch3", "JumpKick", "AirPunch1", "AirPunch2", "UltWindup", "UltStrike", "FightIdle"]:
		if _lib.has_animation(n):
			_lib.remove_animation(n)
	_make_anim("FightIdle", idle_period, true, _pose_idle_sword)
	_make_anim("Punch1", L.Punch1, false, _slash_rl)
	_make_anim("Punch2", L.Punch2, false, _slash_kesa)
	_make_anim("Punch3", L.Punch3, false, _slash_spin)
	_make_anim("JumpKick", L.JumpKick, false, _slash_thrust)
	_make_anim("AirPunch1", L.get("Punch1", 0.3), false, func(u): _air_slash(u, 1))
	_make_anim("AirPunch2", L.get("Punch2", 0.3), false, _air_kesa)
	_make_anim("UltWindup", 1.3, false, _ult_windup)
	_make_anim("UltStrike", 0.5, false, _ult_strike)
	_make_anim("Walking", 1.0, true, func(u): _locomotion(u, 0.0))
	_make_anim("Run", 0.62, true, func(u): _locomotion(u, 1.0))


# ---------- ตัวช่วย ----------

## จัดท่าจากพารามิเตอร์ (ลำตัว + เท้า + แขนจับดาบ)
func _sword_pose(p: Dictionary, air := false) -> void:
	if air:
		_p_hips(Vector3(0, 0, 0), p.yaw, 0.0, -6.0)
		_p_spine(p.lean, p.twist)
		_p_head(-p.lean * 0.8 - 8.0, -(p.yaw + p.twist) * 0.6)
		_p_leg(1, Vector3(0.05, 0.30, -0.12), 0.3, 45.0)
		_p_leg(-1, Vector3(0.05, 0.16, -0.32), 0.3, 55.0)
	else:
		_stance(p.drop, p.lean, p.yaw, p.twist, p.get("fwd", 0.0), p.get("lf", Vector3.ZERO), p.get("rf", Vector3.ZERO))
	_hold_sword(p.g, p.b)


## แขนทั้งสองจับด้ามดาบ: g = ตำแหน่งมือขวา (กรอบอก), b = ทิศใบดาบ (กรอบอก)
func _hold_sword(g: Vector3, b: Vector3) -> void:
	var t2 := _glob(B.Spine2)
	var bd: Vector3 = (t2.basis * b).normalized()
	var gp: Vector3 = t2 * g
	_arm_ik(-1, gp, Vector3(-0.9, -0.5, -0.3))
	_arm_ik(1, gp - bd * 0.15, Vector3(0.9, -0.5, -0.3))
	var up := Vector3.UP if absf(bd.dot(Vector3.UP)) < 0.95 else Vector3.BACK
	var x := bd.cross(up).normalized()
	var z := x.cross(bd).normalized()
	var hb := Basis(x, bd, z)
	_set_global_rot(_b(-1, "Hand"), hb)
	_set_global_rot(_b(1, "Hand"), hb)


func _arm_ik(side: int, target: Vector3, pole: Vector3) -> void:
	_leg_ik(_b(side, "Arm"), _b(side, "ForeArm"), _b(side, "Hand"), target, pole)


func _pose_idle_sword(u: float) -> void:
	# ท่ายืนรอ: ไม่ชักดาบ มือทั้งสองลดต่ำใกล้สะโพก (เหมือนวางมือบนด้าม) เด้งเบาๆ
	var beats := 4.0
	var h := _bounce_curve(fmod(u * beats, 1.0))
	var sway := sin(TAU * u)
	var lean := 14.0 - 2.0 * h
	_p_hips(Vector3(0.02 * sway, -(idle_crouch - idle_bounce * h), 0.0), -10.0 + 3.0 * sway, -2.0 * sway)
	_p_spine(lean, -6.0)
	_p_head(-lean * 0.8 + 3.0 * h, 10.0 - 3.0 * sway)
	_p_arm(-1, Vector3(-0.15, -0.55, 0.45), Vector3(0.1, -0.30, 0.95))
	_p_arm(1, Vector3(0.40, -0.80, 0.25), Vector3(-0.15, -0.55, 0.65))
	_p_leg(1, Vector3(0.12, 0, 0.07), 0.55)
	_p_leg(-1, Vector3(0.12, 0, -0.05), 0.55)


# ---------- ท่าฟัน ----------

func _k(drop: float, lean: float, yaw: float, twist: float, g: Vector3, b: Vector3, lf := Vector3.ZERO, rf := Vector3.ZERO, fwd := 0.0) -> Dictionary:
	return {"drop": drop, "lean": lean, "yaw": yaw, "twist": twist, "g": g, "b": b, "lf": lf, "rf": rf, "fwd": fwd}


## ฟันขวา -> ซ้าย (แนวนอน) ปะทะที่ u ~0.38
func _slash_rl(u: float) -> void:
	var feet := _step_feet("Punch1", u)
	var p := _kf([
		[0.0, READY],
		[0.18, _k(0.16, 16.0, -36.0, -32.0, Vector3(-0.44, -0.04, 0.10), Vector3(-0.88, 0.12, 0.30))],
		[0.38, _k(0.12, 14.0, 4.0, 6.0, Vector3(-0.02, -0.04, 0.46), Vector3(0.15, 0.10, 0.98))],
		[0.55, _k(0.10, 12.0, 34.0, 34.0, Vector3(0.42, -0.04, 0.28), Vector3(0.92, 0.08, 0.30))],
		[1.0, READY],
	], u)
	p.lf = (p.lf as Vector3) + feet[0]
	p.rf = (p.rf as Vector3) + feet[1]
	_sword_pose(p)


## ฟันกลับซ้าย -> ขวา (เฉียงขึ้นเล็กน้อย)
func _slash_lr(u: float) -> void:
	var feet := _step_feet("Punch2", u)
	var p := _kf([
		[0.0, READY],
		[0.18, _k(0.16, 16.0, 36.0, 34.0, Vector3(0.40, -0.02, 0.22), Vector3(0.90, -0.08, 0.30))],
		[0.38, _k(0.12, 12.0, -4.0, -2.0, Vector3(0.0, 0.06, 0.46), Vector3(-0.15, 0.20, 0.97))],
		[0.55, _k(0.10, 10.0, -36.0, -34.0, Vector3(-0.44, 0.18, 0.20), Vector3(-0.90, 0.30, 0.28))],
		[1.0, READY],
	], u)
	p.lf = (p.lf as Vector3) + feet[0]
	p.rf = (p.rf as Vector3) + feet[1]
	_sword_pose(p)


## ฟันเสยขึ้นจากล่าง (หนัก) ปะทะที่ u ~0.44 แล้วยกดาบข้ามหัว
func _slash_rise(u: float) -> void:
	var feet := _step_feet("Punch3", u)
	var p := _kf([
		[0.0, READY],
		[0.26, _k(0.24, 24.0, 14.0, 22.0, Vector3(0.22, -0.46, 0.24), Vector3(0.42, -0.52, 0.72))],
		[0.44, _k(0.06, 4.0, -16.0, -22.0, Vector3(-0.06, 0.22, 0.52), Vector3(0.0, 0.92, 0.38))],
		[0.58, _k(0.02, -8.0, -22.0, -30.0, Vector3(-0.06, 0.56, 0.22), Vector3(0.0, 0.55, -0.82))],
		[0.72, _k(0.02, -8.0, -22.0, -30.0, Vector3(-0.06, 0.56, 0.22), Vector3(0.0, 0.55, -0.82))],
		[1.0, READY],
	], u)
	p.lf = (p.lf as Vector3) + feet[0]
	p.rf = (p.rf as Vector3) + feet[1]
	_sword_pose(p)


## กระโดดหมุนฟันลง (ท่า K) : หมุนตัว 1 รอบแล้วฟันทิ้งตัวลง
func _slash_dive(u: float) -> void:
	var spin := -330.0 * smoothstep(0.0, 0.62, u)
	var p := _kf([
		[0.0, READY],
		[0.30, _k(0.05, 6.0, 0.0, -10.0, Vector3(-0.04, 0.50, 0.12), Vector3(0.0, 0.45, -0.90))],
		[0.55, _k(0.02, 14.0, 0.0, 6.0, Vector3(-0.02, 0.18, 0.56), Vector3(0.0, -0.45, 0.90))],
		[0.78, _k(0.02, 14.0, 0.0, 6.0, Vector3(-0.02, 0.10, 0.56), Vector3(0.0, -0.50, 0.86))],
		[1.0, READY],
	], u)
	p.yaw = float(p.yaw) + spin
	_p_hips(Vector3(0, 0, 0), p.yaw, 0.0, -4.0)
	_p_spine(p.lean, p.twist)
	_p_head(-p.lean * 0.8, 0.0)
	_p_leg(1, Vector3(0.06, 0.30, -0.05), 0.3, 40.0)
	_p_leg(-1, Vector3(0.06, 0.22, -0.20), 0.3, 50.0)
	_hold_sword(p.g, p.b)


## คอมโบ KARASU (ต่างจากเป็ด): 1 ฟันนอนเร็ว -> 2 ฟันเฉียงลงจากบ่าขวา (เคสะ) -> 3 หมุนตัวฟันรอบทิศ -> K พุ่งแทง
func _slash_kesa(u: float) -> void:
	var feet := _step_feet("Punch2", u)
	var p := _kf([
		[0.0, READY],
		[0.20, _k(0.14, 14.0, -30.0, -28.0, Vector3(-0.40, 0.58, 0.12), Vector3(-0.30, 0.80, -0.50))],
		[0.38, _k(0.14, 20.0, 6.0, 8.0, Vector3(-0.02, 0.10, 0.52), Vector3(0.30, -0.35, 0.88))],
		[0.56, _k(0.12, 22.0, 26.0, 28.0, Vector3(0.34, -0.42, 0.30), Vector3(0.82, -0.52, 0.24))],
		[1.0, READY],
	], u)
	p.lf = (p.lf as Vector3) + feet[0]
	p.rf = (p.rf as Vector3) + feet[1]
	_sword_pose(p)


## หมุนตัวฟันวงกลม (ปะทะ u ~0.44)
func _slash_spin(u: float) -> void:
	var feet := _step_feet("Punch3", u)
	var p := _kf([
		[0.0, READY],
		[0.20, _k(0.22, 18.0, -40.0, -30.0, Vector3(-0.44, -0.10, 0.08), Vector3(-0.90, 0.10, -0.30))],
		[0.30, _k(0.14, 12.0, -40.0, -10.0, Vector3(-0.10, 0.0, 0.50), Vector3(0.10, 0.05, 1.0))],
		[0.60, _k(0.14, 12.0, -40.0, -10.0, Vector3(-0.10, 0.0, 0.50), Vector3(0.10, 0.05, 1.0))],
		[0.78, _k(0.10, 10.0, -20.0, -10.0, Vector3(-0.10, -0.10, 0.40), Vector3(0.0, 0.40, 0.90))],
		[1.0, READY],
	], u)
	p.yaw = float(p.yaw) + 360.0 * smoothstep(0.22, 0.58, u)
	p.lf = (p.lf as Vector3) + feet[0]
	p.rf = (p.rf as Vector3) + feet[1]
	_sword_pose(p)


## พุ่งแทงไปข้างหน้ากลางอากาศ (ท่า K)
func _slash_thrust(u: float) -> void:
	var p := _kf([
		[0.0, READY],
		[0.30, _k(0.05, 14.0, -20.0, -26.0, Vector3(-0.36, -0.02, 0.04), Vector3(0.0, 0.10, 1.0))],
		[0.50, _k(0.02, 32.0, 14.0, 20.0, Vector3(0.0, 0.0, 0.66), Vector3(0.0, 0.05, 1.0))],
		[0.78, _k(0.02, 32.0, 14.0, 20.0, Vector3(0.0, 0.0, 0.64), Vector3(0.0, 0.05, 1.0))],
		[1.0, READY],
	], u)
	_p_hips(Vector3(0, 0, 0), p.yaw, 0.0, -10.0)
	_p_spine(p.lean, p.twist)
	_p_head(-p.lean * 0.9, 0.0)
	_p_leg(1, Vector3(0.06, 0.26, -0.28), 0.3, 40.0)
	_p_leg(-1, Vector3(0.06, 0.32, -0.40), 0.3, 55.0)
	_hold_sword(p.g, p.b)


## ฟันกลางอากาศ (ใช้ตอนลอยต่อสู้/อัลติ) side 1 = ขวา->ซ้าย, -1 = ซ้าย->ขวา
func _air_slash(u: float, side: int) -> void:
	var s := float(side)
	var p := _kf([
		[0.0, READY],
		[0.20, _k(0.0, 14.0, -34.0 * s, -30.0 * s, Vector3(-0.44 * s, -0.02, 0.10), Vector3(-0.88 * s, 0.10, 0.30))],
		[0.42, _k(0.0, 12.0, 4.0 * s, 4.0 * s, Vector3(0.0, 0.0, 0.48), Vector3(0.15 * s, 0.10, 0.98))],
		[0.60, _k(0.0, 10.0, 34.0 * s, 32.0 * s, Vector3(0.42 * s, 0.0, 0.26), Vector3(0.92 * s, 0.06, 0.30))],
		[1.0, READY],
	], u)
	_sword_pose(p, true)


## ฟันเฉียงลงกลางอากาศ (AirPunch2) — ท่าเดียวกับ J2 แต่ลอยตัว
func _air_kesa(u: float) -> void:
	var p := _kf([
		[0.0, READY],
		[0.20, _k(0.0, 14.0, -30.0, -28.0, Vector3(-0.40, 0.58, 0.12), Vector3(-0.30, 0.80, -0.50))],
		[0.40, _k(0.0, 20.0, 6.0, 8.0, Vector3(-0.02, 0.10, 0.52), Vector3(0.30, -0.35, 0.88))],
		[0.60, _k(0.0, 22.0, 26.0, 28.0, Vector3(0.34, -0.42, 0.30), Vector3(0.82, -0.52, 0.24))],
		[1.0, READY],
	], u)
	_sword_pose(p, true)


func _ult_windup(u: float) -> void:
	var sh := sin(u * 38.0) * 0.012 * u
	var p := _k(0.20 + 0.04 * u, 18.0, -16.0, -22.0, Vector3(-0.20 + sh, 0.60, 0.10), Vector3(0.0, 0.40, -0.92))
	_sword_pose(p)


func _ult_strike(u: float) -> void:
	# ฟันผ่านแล้วค้างท่า: ย่อต่ำมาก ตัวเอนไปหน้า ดาบเหวี่ยงไปด้านข้างชี้ไปหลัง (ท่า Zoro)
	var p := _kf([
		[0.0, _k(0.24, 18.0, -16.0, -22.0, Vector3(-0.20, 0.60, 0.10), Vector3(0.0, 0.40, -0.92))],
		[0.25, _k(0.20, 24.0, 6.0, 8.0, Vector3(-0.02, 0.0, 0.58), Vector3(0.0, -0.20, 0.95))],
		[0.50, _k(0.40, 30.0, 24.0, 28.0, Vector3(-0.56, -0.26, 0.04), Vector3(-1.0, 0.06, -0.16))],
		[1.0, _k(0.40, 30.0, 24.0, 28.0, Vector3(-0.56, -0.26, 0.04), Vector3(-1.0, 0.06, -0.16))],
	], u)
	_sword_pose(p)


# ---------- เดิน / วิ่ง ----------

func _locomotion(u: float, run: float) -> void:
	var ph := TAU * u
	var stride := lerpf(0.22, 0.34, run)
	var lift := lerpf(0.10, 0.22, run)
	var bob := absf(sin(ph)) * lerpf(0.02, 0.03, run)
	# วิ่งแบบนารูโตะ: ตัวพุ่งไปข้างหน้าเกือบขนานพื้น หัวยื่น แขนทั้งสองเหวี่ยงเหยียดตรงไปด้านหลัง
	var lean := lerpf(6.0, 38.0, run)
	_p_hips(Vector3(0, -lerpf(0.04, 0.16, run) + bob, lerpf(0.0, 0.10, run)), sin(ph) * lerpf(5.0, 5.0, run), sin(ph) * 2.0, lerpf(-6.0, 6.0, run))
	_p_spine(lean, -sin(ph) * lerpf(8.0, 5.0, run))
	_p_head(-lean * lerpf(0.8, 1.05, run), sin(ph) * 2.0)
	var sl := sin(ph)
	var sr := -sl
	_p_leg(1, Vector3(0.08, maxf(0.0, cos(ph)) * lift, sl * stride), 0.3)
	_p_leg(-1, Vector3(0.08, maxf(0.0, -cos(ph)) * lift, sr * stride), 0.3)
	var sw := lerpf(0.35, 0.6, run)
	var w1 := Vector3(0.30, -0.85, -sr * sw)
	var w2 := Vector3(0.30 - 0.1, -0.55, 0.45)
	var n1 := Vector3(0.18, -0.30 + 0.05 * sr, -1.0)
	var n2 := Vector3(0.12, -0.20, -1.0)
	_p_arm(1, w1.lerp(n1, run).normalized(), w2.lerp(n2, run).normalized())
	_p_arm(-1, Vector3(w1.x, w1.y, -sl * sw).lerp(Vector3(n1.x, -0.30 + 0.05 * sl, -1.0), run).normalized(), w2.lerp(n2, run).normalized())
	if run > 0.5:
		# ดาบในมือขวาชี้ไปทางด้านหลังตามแขน (ท่าวิ่งนารูโตะ)
		var bd := Vector3(0.1, 0.12, -1.0).normalized()
		var x := bd.cross(Vector3.UP).normalized()
		var z := x.cross(bd).normalized()
		_set_global_rot(_b(-1, "Hand"), Basis(x, bd, z))
