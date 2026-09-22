extends Node
## เอฟเฟกต์ภาพที่ใช้ร่วมกันทุกตัวละคร: วงแหวนกระแทก, ลมพัด, ประกายไฟ, ลำแสงวาร์ป, โล่ป้องกัน
## ทุกฟังก์ชันเป็น static เรียกใช้ได้เลย เช่น Vfx.ring(self, xf, สี, ...)

## ความเข้มรวมของเอฟเฟกต์ (0.5 = โปร่งใสกว่าเดิมครึ่งหนึ่ง)
static var intensity := 0.45

static var _ring_tex: Texture2D
static var _soft_tex: Texture2D
static var _shield_tex: Texture2D
static var _line_tex: Texture2D


## วงแหวนบาง (ใช้ทำคลื่นกระแทก / วงวาร์ป)
static func ring_texture() -> Texture2D:
	if _ring_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 0.78, 0.92, 1.0])
		g.colors = PackedColorArray([
			Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0),
			Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
		_ring_tex = _radial(g)
	return _ring_tex


## จุดฟุ้งนุ่ม (ใช้ทำลม/ประกาย)
static func soft_texture() -> Texture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		_soft_tex = _radial(g)
	return _soft_tex


## แผ่นโล่: ตรงกลางจางๆ ขอบสว่าง
static func shield_texture() -> Texture2D:
	if _shield_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 0.82, 0.95, 1.0])
		g.colors = PackedColorArray([
			Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0.85),
			Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.0)])
		_shield_tex = _radial(g)
	return _shield_tex


## เส้นตรง: ทึบตรงกลาง จางที่ปลายทั้งสองข้าง (ใช้ทำเส้นความเร็ว)
static func line_texture() -> Texture2D:
	if _line_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.12, 0.5, 0.88, 1.0])
		g.colors = PackedColorArray([
			Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.85), Color(1, 1, 1, 1.0),
			Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_LINEAR
		t.fill_from = Vector2(0.5, 0.0)
		t.fill_to = Vector2(0.5, 1.0)
		t.width = 8
		t.height = 128
		_line_tex = t
	return _line_tex


static func _radial(g: Gradient) -> Texture2D:
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


static func _quad(tex: Texture2D, color: Color, size: Vector2, billboard := BaseMaterial3D.BILLBOARD_DISABLED, additive := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex
	mat.albedo_color = color
	mat.billboard_mode = billboard
	q.material = mat
	m.mesh = q
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## คลื่นกระแทกวงแหวน: โผล่ที่ pos หันตาม normal แล้วขยายออกพร้อมจางหาย
static func ring(node: Node, pos: Vector3, normal: Vector3, color: Color, from_size: float, to_size: float, dur := 0.3) -> void:
	var root := node.get_tree().current_scene
	if root == null:
		return
	var m := _quad(ring_texture(), Color(color.r, color.g, color.b, color.a * intensity), Vector2.ONE)
	root.add_child(m)
	var n := normal.normalized()
	if absf(n.dot(Vector3.UP)) > 0.95:
		m.global_transform = Transform3D(Basis(), pos).looking_at(pos + n, Vector3.FORWARD)
	else:
		m.global_transform = Transform3D(Basis(), pos).looking_at(pos + n, Vector3.UP)
	m.scale = Vector3.ONE * from_size
	var t := m.create_tween().set_ignore_time_scale(true).set_parallel(true)
	t.tween_property(m, "scale", Vector3.ONE * to_size, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(m.mesh.material, "albedo_color:a", 0.0, dur)
	t.chain().tween_callback(m.queue_free)


## โล่ป้องกัน: แผ่นกลมสว่างหน้าตัวละคร กะพริบแล้วจาง
static func shield(node: Node, pos: Vector3, normal: Vector3, color: Color, size := 1.0, dur := 0.35) -> void:
	var root := node.get_tree().current_scene
	if root == null:
		return
	var m := _quad(shield_texture(), Color(color.r, color.g, color.b, color.a * clampf(intensity * 1.6, 0.0, 1.0)), Vector2.ONE)
	root.add_child(m)
	m.global_transform = Transform3D(Basis(), pos).looking_at(pos + normal.normalized(), Vector3.UP)
	m.scale = Vector3.ONE * size * 0.6
	var t := m.create_tween().set_ignore_time_scale(true).set_parallel(true)
	t.tween_property(m, "scale", Vector3.ONE * size * 1.15, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(m.mesh.material, "albedo_color:a", 0.0, dur).set_delay(dur * 0.35)
	t.chain().tween_callback(m.queue_free)
	ring(node, pos, normal, color, size * 0.5, size * 1.6, dur * 0.8)


## ลำแสงวาร์ป: เส้นยาวจากจุด a ไป b
static func streak(node: Node, a: Vector3, b: Vector3, color: Color, width := 0.5, dur := 0.25, sharp := false) -> void:
	var root := node.get_tree().current_scene
	if root == null:
		return
	var dir := b - a
	var len := dir.length()
	if len < 0.05:
		return
	var tex := line_texture() if sharp else soft_texture()
	var m := _quad(tex, Color(color.r, color.g, color.b, color.a * intensity * (1.6 if sharp else 0.8)), Vector2(width, len), BaseMaterial3D.BILLBOARD_DISABLED, sharp)
	root.add_child(m)
	# หันด้านหน้าของเส้นเข้าหากล้อง โดยให้แกนยาวของเส้นอยู่ตามแนวที่พุ่ง
	var mid := (a + b) * 0.5
	var y := dir.normalized()
	var cam := node.get_viewport().get_camera_3d()
	var to_cam := (cam.global_position - mid).normalized() if cam else Vector3.BACK
	var z := (to_cam - y * to_cam.dot(y))
	if z.length() < 0.05:
		z = y.cross(Vector3.UP)
		if z.length() < 0.05:
			z = Vector3.RIGHT
	z = z.normalized()
	var x := y.cross(z).normalized()
	m.global_transform = Transform3D(Basis(x, y, z), mid)
	var t := m.create_tween().set_ignore_time_scale(true)
	t.tween_property(m.mesh.material, "albedo_color:a", 0.0, dur)
	t.tween_callback(m.queue_free)


## เส้นความเร็วหลายเส้น (สไตล์การ์ตูนตอนวาร์ป): เส้นตรงบางๆ ขนานไปตามแนวที่พุ่ง
## count = จำนวนเส้น, radius = กระจายออกจากแนวกลางกี่เมตร
static func speed_lines(node: Node, a: Vector3, b: Vector3, color: Color, count := 9, radius := 0.7, width := 0.06, dur := 0.26) -> void:
	var dir := b - a
	if dir.length() < 0.05:
		return
	var y := dir.normalized()
	var x := y.cross(Vector3.UP).normalized()
	if x.length() < 0.1:
		x = Vector3.RIGHT
	var z := x.cross(y).normalized()
	for i in count:
		# สุ่มตำแหน่งรอบแนวกลาง + สุ่มความยาว/ตำแหน่งตามแนว ให้เส้นไม่เท่ากัน
		var ang := randf() * TAU
		var r := radius * sqrt(randf())
		var off := x * (cos(ang) * r) + z * (sin(ang) * r) + Vector3.UP * randf_range(-0.15, 0.35)
		var t0 := randf_range(-0.1, 0.35)
		var t1 := t0 + randf_range(0.55, 1.1)
		var p0 := a.lerp(b, clampf(t0, -0.2, 1.0)) + off
		var p1 := a.lerp(b, clampf(t1, 0.0, 1.2)) + off
		var c := Color(color.r, color.g, color.b, color.a * randf_range(0.5, 1.0))
		streak(node, p0, p1, c, width * randf_range(0.7, 1.4), dur * randf_range(0.7, 1.2), true)


## ฝุ่น/ลมพุ่งไปทางหนึ่ง (ใช้ตอนออกหมัด) หรือกระจายรอบตัว (spread สูง)
static func puff(node: Node, pos: Vector3, dir: Vector3, color: Color, amount := 14, speed := 6.0, life := 0.35, size := 0.22, spread := 25.0) -> void:
	var root := node.get_tree().current_scene
	if root == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12
	p.direction = dir.normalized()
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.damping_min = 6.0
	p.damping_max = 12.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.35))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1.0, 0.2))
	p.scale_amount_curve = c
	var a0 := 0.9 * intensity
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(color.r, color.g, color.b, a0), Color(color.r, color.g, color.b, a0 * 0.55), Color(color.r, color.g, color.b, 0.0)])
	p.color_ramp = g
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = soft_texture()
	mesh.material = mat
	p.mesh = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	p.position = pos
	root.add_child(p)
	p.global_position = pos
	p.restart()
	node.get_tree().create_timer(life + 0.6, true, false, true).timeout.connect(p.queue_free)


## ประกายเล็กๆ กระจายรอบจุด (ตอนหมัดโดน / โล่รับหมัด)
static func sparks(node: Node, pos: Vector3, color: Color, amount := 12, speed := 5.0) -> void:
	puff(node, pos, Vector3.UP, color, amount, speed, 0.45, 0.06, 180.0)
