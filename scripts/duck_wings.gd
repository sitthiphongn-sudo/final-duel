extends Node3D
## ปีกใสของเป็ดราชา: ปกติซ่อนอยู่ ตอนออกท่า (boost) ปีกจะ "โผล่ออกมาเป็นแสงใส" ฟาดไปข้างหน้าแล้วจางหาย
## ใช้แทนไฟที่มือ (HandFire) -> player.gd เรียก fire_l.boost(...) / fire_r.boost(...) เหมือนเดิมทุกที่
## ไม่ต้องผูกกับปีกจริงที่ตัวเป็ด (โมเดลไม่มีปีก/แขน) ปีกนี้เป็นแค่เอฟเฟกต์ที่ติดกับกระดูกลำตัว

@export var side := 1                       ## 1 = ปีกซ้ายของตัวละคร (+X), -1 = ปีกขวา
@export var tint := Color(1.0, 0.72, 0.25)  ## สีแสงของปีก (ทองครีม)
@export var tint_edge := Color(1.0, 0.95, 0.75)
@export var wing_len := 1.7                ## ความยาวปีก (หน่วยของโมเดลเป็ด)
@export var feathers := 9

static var _mesh_cache: ArrayMesh = null
static var _shader_cache: Shader = null

var appear := 0.0 : set = _set_appear     ## 0 = มองไม่เห็น, 1 = เต็มที่
var sweep := 0.0                          ## องศาที่ปีกกวาดไปข้างหน้า (หมุนรอบแกนตั้ง)
var flap := 0.0                           ## องศาที่ปีกพับ/กางขึ้นลง (หมุนรอบแกนหน้า-หลัง)
var power := 1.0
var trail := 0.0                          ## องศาที่ปีกเงาตามหลัง (ใช้กับท่าหมุนฟัน)
var _pivot: Node3D
var _mats: Array[ShaderMaterial] = []
var _tw: Tween


## ติดปีกคู่เข้ากับกระดูกลำตัวของเป็ด คืนค่าปีกข้างที่ขอ (เรียกครั้งละข้าง)
static func attach(skel: Skeleton3D, bone_name: String, p_side: int, pos: Vector3) -> Node3D:
	var att := BoneAttachment3D.new()
	att.bone_name = bone_name
	skel.add_child(att)
	var w := (load("res://scripts/duck_wings.gd") as GDScript).new() as Node3D
	w.side = p_side
	w.position = pos * Vector3(p_side, 1, 1)
	att.add_child(w)
	return w


func _ready() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	if _mesh_cache == null:
		_mesh_cache = _build_wing_mesh()
	if _shader_cache == null:
		_shader_cache = _build_shader()
	# 3 ชั้นซ้อนกัน (ตัวจริง + เงาตามหลัง 2 ชั้น) ให้เหมือนแสงเคลื่อนไหวพร่าๆ
	for i in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh_cache
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := ShaderMaterial.new()
		m.shader = _shader_cache
		m.set_shader_parameter("tint", tint)
		m.set_shader_parameter("tint_edge", tint_edge)
		m.set_shader_parameter("appear", 0.0)
		m.set_shader_parameter("ghost", float(i))
		mi.material_override = m
		# ปีกซ้าย = สร้างเป็นรูปปีกที่ชี้ออกทาง +X ปีกขวา = สะท้อนแกน X (กลับด้านหน้าแบนด้วย cull_disabled)
		mi.scale = Vector3(side, 1, 1) * (1.0 - 0.08 * i)
		mi.set_meta("lag", 0.05 * i)
		_pivot.add_child(mi)
		_mats.append(m)
	_apply()


func _set_sweep(v: float) -> void:
	sweep = v
	_apply()


func _set_flap(v: float) -> void:
	flap = v
	_apply()


func _set_appear(v: float) -> void:
	appear = v
	_apply()


func _apply() -> void:
	if _pivot == null:
		return
	visible = appear > 0.01
	var s := (0.6 + 0.4 * appear) * (0.95 + 0.12 * minf(power, 3.0))
	# กวาดไปหน้า (yaw) + พับขึ้นลง (roll รอบแกนหน้า) ; ปีกซ้าย +X กวาดเข้าหาแกนกลางด้านหน้า
	var b := Basis(Vector3.UP, deg_to_rad(-side * sweep)) * Basis(Vector3.BACK, deg_to_rad(side * flap))
	_pivot.basis = b.scaled(Vector3.ONE * s)
	for i in _mats.size():
		_mats[i].set_shader_parameter("appear", appear * (1.0 if i == 0 else 0.45 / i))
		var mi := _pivot.get_child(i) as MeshInstance3D
		# เงาที่ตามหลัง: เอียงกลับไปทางที่ปีกมาจาก
		var lag: float = mi.get_meta("lag")
		mi.rotation.y = (deg_to_rad(side * lag * sweep * -1.2) + deg_to_rad(trail * i)) if i > 0 else 0.0


## ออกท่า: ปีกโผล่ -> ฟาด -> ค้างนิด -> จางหาย
##   p     = ความแรง (1 = ปกติ, ~2.5 = ท่าแรง, 3+ = อัลติเมต)
##   style = "swat"  ปีกเงื้อแล้วตบไปข้างหน้า (ค่าเริ่มต้น)
##           "slam"  ยกปีกสูงแล้วฟาดลงตรงๆ (กระโดดตบ)
##           "spin"  กางปีกออกข้างสองข้างแล้วกระพือระหว่างหมุนตัว (hold = เวลาที่กางค้าง วินาที)
func boost(p := 1.0, style := "swat", hold := 0.4) -> void:
	if not is_inside_tree():
		return
	power = p
	trail = 0.0
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.set_parallel(false)
	var heavy := p >= 2.0
	match style:
		"spin":
			sweep = 0.0
			flap = 10.0
			_tw.tween_method(_set_appear, appear, 1.0, 0.06)
			_tw.tween_method(_spin_flap, 0.0, 1.0, hold)
			_tw.tween_method(_set_appear, 1.0, 0.0, 0.25).set_trans(Tween.TRANS_SINE)
		"cutter":
			# ปีกกางตรงออกข้างแนวนอนเหมือนใบมีด ตัวหมุนปีกจึงกวาดเป็นวงฟันรอบตัว
			sweep = 0.0
			flap = 0.0
			trail = 60.0
			_tw.tween_method(_set_appear, appear, 1.0, 0.03)
			_tw.tween_method(_cutter_pulse, 0.0, 1.0, hold)
			_tw.tween_method(_set_appear, 1.0, 0.0, 0.16).set_trans(Tween.TRANS_SINE)
		"flurry":
			# ปีกรัวสลับฟาดไปข้างหน้าเร็วๆ ตามจังหวะจิกหัว
			sweep = 0.0
			flap = 20.0
			_tw.tween_method(_set_appear, appear, 1.0, 0.04)
			_tw.tween_method(_flurry_flap, 0.0, 1.0, hold)
			_tw.tween_method(_set_appear, 1.0, 0.0, 0.2).set_trans(Tween.TRANS_SINE)
		"rise":
			# ปีกตวัดขึ้นฟ้าแล้วกระพือค้างตอนลอยตัวเป็นเกลียว
			sweep = 10.0
			flap = -30.0
			_tw.tween_method(_set_appear, appear, 1.0, 0.05)
			_tw.set_parallel(true)
			_tw.tween_method(_set_flap, -30.0, 95.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tw.set_parallel(false)
			_tw.tween_method(_rise_flap, 0.0, 1.0, hold)
			_tw.tween_method(_set_appear, 1.0, 0.0, 0.28).set_trans(Tween.TRANS_SINE)
		"smash":
			# กางปีกกว้างสุดกระพือหนักๆ ระหว่างตีลังกา แล้วฟาดลงพร้อมกันตอนกระแทก
			sweep = 0.0
			flap = 70.0
			_tw.tween_method(_set_appear, appear, 1.0, 0.08)
			_tw.tween_method(_smash_flap, 0.0, 1.0, hold)
			_tw.set_parallel(true)
			_tw.tween_method(_set_flap, 100.0, -72.0, 0.1).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
			_tw.tween_method(_set_sweep, 0.0, 38.0, 0.1)
			_tw.set_parallel(false)
			_tw.tween_interval(0.22)
			_tw.tween_method(_set_appear, 1.0, 0.0, 0.4).set_trans(Tween.TRANS_SINE)
		"slam":
			sweep = 6.0
			flap = 88.0
			_tw.tween_method(_set_appear, appear, 1.0, 0.05)
			_tw.tween_interval(0.05)
			_tw.set_parallel(true)
			_tw.tween_method(_set_flap, 88.0, -58.0, 0.11).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
			_tw.tween_method(_set_sweep, 6.0, 26.0, 0.11)
			_tw.set_parallel(false)
			_tw.tween_interval(0.14)
			_tw.tween_method(_set_appear, 1.0, 0.0, 0.3).set_trans(Tween.TRANS_SINE)
		_:
			var from_sweep := -62.0
			var to_sweep := 60.0 if not heavy else 76.0
			var from_flap := 42.0 if not heavy else 78.0
			var to_flap := -18.0 if not heavy else -52.0
			sweep = from_sweep
			flap = from_flap
			_tw.tween_method(_set_appear, appear, 1.0, 0.05)
			_tw.set_parallel(true)
			_tw.tween_method(_set_sweep, from_sweep, to_sweep, 0.13).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			_tw.tween_method(_set_flap, from_flap, to_flap, 0.13).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			_tw.set_parallel(false)
			_tw.tween_interval(0.07 + 0.04 * minf(p, 3.0))
			_tw.tween_method(_set_appear, 1.0, 0.0, 0.3 + 0.06 * minf(p, 3.0)).set_trans(Tween.TRANS_SINE)


func _cutter_pulse(t: float) -> void:
	flap = 5.0 * sin(t * TAU * 3.0)
	sweep = 0.0
	trail = 60.0 * (1.0 - 0.4 * t)
	_apply()


func _flurry_flap(t: float) -> void:
	var ph := t * TAU * 3.0
	sweep = 34.0 * maxf(0.0, sin(ph))
	flap = 24.0 - 52.0 * maxf(0.0, sin(ph))
	_apply()


func _rise_flap(t: float) -> void:
	flap = 70.0 + 28.0 * sin(t * TAU * 2.0)
	sweep = 12.0 + 10.0 * sin(t * TAU * 2.0 + 1.0)
	_apply()


func _smash_flap(t: float) -> void:
	flap = 30.0 + 70.0 * sin(t * TAU * 1.5)
	sweep = 6.0 * sin(t * TAU * 3.0)
	_apply()


func _spin_flap(t: float) -> void:
	flap = 10.0 + 34.0 * sin(t * TAU * 2.5)
	sweep = 0.0
	_apply()


# ---------- สร้างโมเดลปีกด้วยโค้ด (ไม่ต้องมีไฟล์โมเดล) ----------

## จุดบนกระดูกปีก (ขอบหน้าของปีก) ที่ s = 0..1 : ไหล่ -> ศอก -> ข้อมือ -> ปลายปีก
func _arm_point(s: float) -> Vector3:
	var L := wing_len
	var pts := [Vector3(0, 0, 0), Vector3(0.30, 0.22, 0.0) * L, Vector3(0.60, 0.18, 0.0) * L, Vector3(0.84, 0.06, 0.0) * L]
	var f := clampf(s, 0.0, 1.0) * 3.0
	var i := mini(int(f), 2)
	return (pts[i] as Vector3).lerp(pts[i + 1], f - i)


## ปีกนกจริง: กระดูกปีกโค้ง + แผ่นเยื่อพลังงาน + ขนยาว 3 ชุด (ขนปีกใน / ขนกลาง / ขนปลายปีกยาว) ระนาบ XY ยื่นไปทาง +X
## สีจุดยอด r = 0 ขนนก, 1 = เยื่อ/ขอบปีก (ใช้ใน shader แยกแสง)
func _build_wing_mesh() -> ArrayMesh:
	var L := wing_len
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	# ---- เยื่อปีก (coverts): แถบจากขอบหน้าลงมา ----
	var n := 10
	var base := verts.size()
	for j in n + 1:
		var s := float(j) / n
		var top := _arm_point(s)
		var depth := L * 0.24 * (1.0 - 0.55 * s)
		verts.append(top)
		verts.append(top + Vector3(0.02 * L * s, -depth, -0.04 * L))
		uvs.append(Vector2(s, 0.0))
		uvs.append(Vector2(s, 1.0))
		cols.append(Color(1, 0, 0))
		cols.append(Color(1, 0, 0))
	for j in n:
		var a := base + j * 2
		idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	# ---- ขอบหน้าปีกเป็นเส้นแสงหนา ----
	base = verts.size()
	for j in n + 1:
		var s := float(j) / n
		var c := _arm_point(s)
		var w := L * 0.035 * (1.0 - 0.6 * s)
		verts.append(c + Vector3(0, w, 0))
		verts.append(c - Vector3(0, w, 0))
		uvs.append(Vector2(s, 0.0))
		uvs.append(Vector2(s, 0.0))
		cols.append(Color(1, 0, 0))
		cols.append(Color(1, 0, 0))
	for j in n:
		var a := base + j * 2
		idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	# ---- ขนนก: [จำนวน, s เริ่ม, s จบ, มุมเริ่ม, มุมจบ (องศาจากแกน +X ลงล่างเป็นลบ), ยาวเริ่ม, ยาวจบ, กว้าง] ----
	var groups := [
		[4, 0.04, 0.34, -122.0, -98.0, 0.34, 0.48, 0.085],
		[6, 0.38, 0.70, -92.0, -62.0, 0.50, 0.64, 0.100],
		[7, 0.74, 1.00, -50.0, -6.0, 0.66, 0.46, 0.085],
	]
	for g in groups:
		var cnt: int = g[0]
		for f in cnt:
			var t := float(f) / float(maxi(cnt - 1, 1))
			var root := _arm_point(lerpf(g[1], g[2], t))
			var ang := deg_to_rad(lerpf(g[3], g[4], t))
			var length: float = L * lerpf(g[5], g[6], t)
			var dir := Vector3(cos(ang), sin(ang), -0.10).normalized()
			var side_v := dir.cross(Vector3(0, 0, 1)).normalized()
			var wmax: float = L * float(g[7])
			var steps := 6
			var b0 := verts.size()
			for s in steps + 1:
				var k := float(s) / steps
				var w := wmax * sin(PI * pow(k, 0.62)) * (1.0 - 0.2 * k) + 0.008
				var c := root + dir * (length * k) + Vector3(0, -0.07 * k * k * length, 0)
				verts.append(c - side_v * w)
				verts.append(c + side_v * w)
				uvs.append(Vector2(0.0, k))
				uvs.append(Vector2(1.0, k))
				cols.append(Color(0, 0, 0))
				cols.append(Color(0, 0, 0))
			for s in steps:
				var a := b0 + s * 2
				idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _build_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.72, 0.25, 1.0);
uniform vec4 tint_edge : source_color = vec4(1.0, 0.95, 0.75, 1.0);
uniform float appear = 0.0;
uniform float ghost = 0.0;
varying float v_kind;
void vertex() {
	v_kind = COLOR.r;
	// ขนปลายปีกพลิ้วเป็นคลื่น ไม่แข็งทื่อ
	float along = UV.y;
	float w = sin(along * 6.0 - TIME * 15.0 + VERTEX.x * 3.0 + ghost) * 0.06 * along;
	if (COLOR.r < 0.5) {
		VERTEX.y += w;
		VERTEX.z += w * 0.8;
	} else {
		VERTEX.y += sin(UV.x * 8.0 - TIME * 10.0) * 0.02 * UV.x;
	}
}
void fragment() {
	float kind = COLOR.r;                                   // 0 = ขนนก, 1 = เยื่อ/ขอบปีก
	vec3 col;
	float a;
	if (kind < 0.5) {
		float across = 1.0 - abs(UV.x * 2.0 - 1.0);
		float along = UV.y;
		float vein = smoothstep(0.70, 1.0, across);
		float soft = smoothstep(0.0, 0.5, across);
		float streak = 0.5 + 0.5 * sin(along * 16.0 - TIME * 16.0 + ghost * 1.9);   // แสงวิ่งตามขน
		float fade = (1.0 - 0.45 * along) * smoothstep(0.0, 0.06, along);
		float glow = 0.30 + 0.55 * vein + 0.30 * streak * soft;
		col = mix(tint.rgb, tint_edge.rgb, vein * 0.85 + (1.0 - along) * 0.2 + 0.25 * streak);
		col *= glow * 1.25;
		a = soft * fade * 0.9;
	} else {
		float edge = 1.0 - smoothstep(0.0, 0.30, UV.y);
		float body = 1.0 - smoothstep(0.0, 1.0, UV.y);
		float pulse = 0.85 + 0.15 * sin(UV.x * 10.0 - TIME * 9.0);
		col = mix(tint.rgb, tint_edge.rgb, edge) * (0.30 * body + 1.1 * edge) * pulse;
		a = 0.35 * body + 0.65 * edge;
	}
	ALBEDO = col;
	ALPHA = clamp(a * appear, 0.0, 1.0);
}
"""
	return sh
