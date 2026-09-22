extends Node3D
## เปลวไฟที่มือ: เปลวไฟแบบ flipbook (ภาพเคลื่อนไหว 64 เฟรม) + แกนไฟ + ไฟฟุ้ง + ประกายไฟ + แสงกะพริบ
## เรียก boost(แรง) ตอนออกหมัด ไฟจะลุกแรงขึ้นชั่วขณะแล้วค่อยๆ กลับมา

@export var size := 1.0
@export var light_energy := 1.4
@export_range(0.2, 2.0) var fire_speed := 0.55   ## ความเร็วของไฟ (1 = เร็วแบบเดิม, น้อย = ช้าลง)
@export var flipbook: Texture2D = preload("res://vfx/fire_flipbook_8x8.png")
## สีของไฟ (เปลี่ยนชุดนี้ + flipbook เพื่อทำไฟสีอื่น เช่น ไฟน้ำเงินของ Frostfang)
@export var color_core := Color(1.0, 0.95, 0.75)      ## แกนไฟ (สว่างสุด)
@export var color_mid := Color(1.0, 0.55, 0.12)       ## เปลวไฟหลัก
@export var color_tail := Color(0.85, 0.2, 0.03)      ## ปลายเปลวก่อนมอด
@export var color_ember := Color(1.0, 0.8, 0.4)       ## ประกายไฟ
@export var color_light := Color(1.0, 0.52, 0.18)     ## สีแสงที่ส่องออกมา

var flames: CPUParticles3D
var tongues: CPUParticles3D
var core: CPUParticles3D
var embers: CPUParticles3D
var light: OmniLight3D
var _boost := 0.0
var _flicker := 0.0


func _ready() -> void:
	var tex := _soft_texture()

	# แกนไฟ: เล็ก สว่างเกือบขาว อยู่ติดมือ
	core = _particles(24, 0.25 / fire_speed, 0.07 * size, tex)
	core.emission_sphere_radius = 0.035 * size
	core.initial_velocity_min = 0.05 * fire_speed
	core.initial_velocity_max = 0.2 * fire_speed
	core.color_ramp = _gradient([
		[0.0, _c(color_core, 0.9)], [0.4, _c(color_core.lerp(color_mid, 0.5), 0.7)], [1.0, _c(color_mid, 0.0)]])
	add_child(core)

	# เปลวไฟหลัก: ลอยขึ้นตามแรงลอยตัว ทิ้งหางเวลาขยับมือ (local_coords = false)
	flames = _particles(28, 0.45 / fire_speed, 0.13 * size, tex)
	flames.emission_sphere_radius = 0.05 * size
	flames.initial_velocity_min = 0.15 * fire_speed
	flames.initial_velocity_max = 0.45 * fire_speed
	flames.gravity = Vector3(0, 2.2, 0) * fire_speed * fire_speed
	flames.damping_min = 1.5
	flames.damping_max = 3.0
	flames.color_ramp = _gradient([
		[0.0, _c(color_core.lerp(color_mid, 0.4), 0.95)], [0.2, _c(color_mid, 0.85)],
		[0.55, _c(color_tail, 0.45)], [1.0, _c(color_tail.darkened(0.8), 0.0)]])
	add_child(flames)

	# ลิ้นไฟ: ภาพเปลวไฟเคลื่อนไหว (flipbook 8x8) ตั้งตรง ลอยขึ้นช้าๆ ซ้อนกันหลายชั้น
	if flipbook:
		tongues = _particles(9, 0.55 / fire_speed, 0.22 * size, flipbook)
		(tongues.mesh as QuadMesh).size = Vector2(0.2, 0.3) * size
		(tongues.mesh as QuadMesh).center_offset = Vector3(0, 0.1, 0) * size
		var m := (tongues.mesh as QuadMesh).material as StandardMaterial3D
		m.particles_anim_h_frames = 8
		m.particles_anim_v_frames = 8
		m.particles_anim_loop = true
		tongues.anim_speed_min = 1.5   # เล่น 1.5-2.5 รอบต่อช่วงชีวิต (ชีวิตยาวขึ้นเมื่อ fire_speed น้อย = ไฟพลิ้วช้าลง)
		tongues.anim_speed_max = 2.5
		tongues.anim_offset_min = 0.0
		tongues.anim_offset_max = 1.0
		tongues.angle_min = -12.0
		tongues.angle_max = 12.0
		tongues.angular_velocity_min = 0.0
		tongues.angular_velocity_max = 0.0
		tongues.emission_sphere_radius = 0.025 * size
		tongues.initial_velocity_min = 0.05 * fire_speed
		tongues.initial_velocity_max = 0.25 * fire_speed
		tongues.gravity = Vector3(0, 1.2, 0) * fire_speed * fire_speed
		var c := Curve.new()
		c.add_point(Vector2(0.0, 0.5))
		c.add_point(Vector2(0.2, 1.0))
		c.add_point(Vector2(1.0, 0.6))
		tongues.scale_amount_curve = c
		tongues.color_ramp = _gradient([
			[0.0, Color(1, 1, 1, 0.0)], [0.15, Color(1, 1, 1, 1.0)],
			[0.7, Color(1.0, 0.85, 0.7, 0.8)], [1.0, Color(1.0, 0.6, 0.4, 0.0)]])
		add_child(tongues)

	# ประกายไฟ: จุดเล็กๆ สว่าง ลอยขึ้นแล้วดับ
	embers = _particles(12, 0.9 / fire_speed, 0.018 * size, tex)
	embers.emission_sphere_radius = 0.06 * size
	embers.initial_velocity_min = 0.4 * fire_speed
	embers.initial_velocity_max = 1.1 * fire_speed
	embers.spread = 45.0
	embers.gravity = Vector3(0, 0.6, 0) * fire_speed * fire_speed
	embers.scale_amount_curve = null
	embers.color_ramp = _gradient([[0.0, _c(color_ember, 1.0)], [0.7, _c(color_mid, 0.8)], [1.0, _c(color_tail, 0.0)]])
	add_child(embers)

	light = OmniLight3D.new()
	light.light_color = color_light
	light.light_energy = light_energy
	light.omni_range = 1.8
	light.shadow_enabled = false
	add_child(light)


func boost(amount := 1.0) -> void:
	_boost = maxf(_boost, amount)


func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	_boost = move_toward(_boost, 0.0, real_delta * 2.5)
	var k := 1.0 + _boost
	flames.scale_amount_min = 0.6 * k
	flames.scale_amount_max = 1.0 * k
	flames.initial_velocity_max = (0.45 + 0.8 * _boost) * fire_speed
	core.scale_amount_max = 1.0 + 0.5 * _boost
	if tongues:
		tongues.scale_amount_min = 0.7 * (1.0 + 0.8 * _boost)
		tongues.scale_amount_max = 1.0 * (1.0 + 0.8 * _boost)
	# แสงกะพริบแบบสุ่มนุ่มๆ เหมือนเปลวไฟจริง
	_flicker = lerpf(_flicker, randf_range(-1.0, 1.0), clampf(real_delta * 18.0 * fire_speed, 0.0, 1.0))
	light.light_energy = light_energy * (1.0 + 0.25 * _flicker) * (1.0 + 1.5 * _boost)
	light.omni_range = 1.8 + 1.2 * _boost


func _particles(amount: int, lifetime: float, quad: float, tex: Texture2D) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.lifetime_randomness = 0.35
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.direction = Vector3.UP
	p.spread = 18.0
	p.gravity = Vector3(0, 1.0, 0)
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -120.0 * fire_speed
	p.angular_velocity_max = 120.0 * fire_speed
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.15))
	p.scale_amount_curve = curve
	var mesh := QuadMesh.new()
	mesh.size = Vector2(quad, quad)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.no_depth_test = false
	mat.disable_receive_shadows = true
	mesh.material = mat
	p.mesh = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## สี + ค่าความโปร่งใส
func _c(col: Color, a: float) -> Color:
	return Color(col.r, col.g, col.b, a)


func _gradient(points: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for pt in points:
		g.add_point(pt[0], pt[1])
	return g


## texture วงกลมฟุ้ง (ขาวตรงกลาง -> โปร่งใสที่ขอบ)
func _soft_texture() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t
