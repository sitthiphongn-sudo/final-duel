extends Node
## เอฟเฟกต์ตัวละครถูกทุบกระแทกพื้น (สมจริง):
## 1) ฝุ่นก้อนใหญ่แผ่ออกเลียดพื้นเป็นวง แล้วค่อยๆ ลอยฟุ้ง/จางช้าๆ
## 2) ฝุ่นพวยพุ่งขึ้นเป็นลำตรงจุดกระแทก
## 3) ก้อนหินจริง (RigidBody) กระเด็นเป็นวิถีโค้ง ตกกระดอนบนพื้นแล้วค่อยหายไป
## 4) เศษกรวดเล็กๆ ปลิวเร็ว
## 5) รอยแตกร้าวบนพื้น + คลื่นกระแทก
## เรียก: GroundImpact.spawn(self, ตำแหน่งเท้า, กำลัง 0-1)

const Vfx := preload("res://scripts/vfx.gd")
const GameState := preload("res://scripts/game_state.gd")

const DUST := Color(0.86, 0.8, 0.7)      ## สีฝุ่นหินทรายโทนเดียวกับแมพ
const ROCK_COLORS := [Color(0.42, 0.39, 0.35), Color(0.52, 0.48, 0.42), Color(0.35, 0.33, 0.31), Color(0.58, 0.53, 0.45)]

static var _smoke_tex: Texture2D
static var _crack_tex: Texture2D
static var _rock_meshes: Array = []


static func spawn(node: Node, pos: Vector3, power := 1.0) -> void:
	var tree := node.get_tree()
	var root := tree.current_scene
	if root == null:
		return
	# หาผิวพื้นจริงและทิศตั้งฉาก
	var normal := Vector3.UP
	var world := (node as Node3D).get_world_3d() if node is Node3D else null
	if world:
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 1.0, pos + Vector3.DOWN * 3.0)
		if node is CollisionObject3D:
			q.exclude = [(node as CollisionObject3D).get_rid()]
		q.collision_mask = 1
		var r := world.direct_space_state.intersect_ray(q)
		if r:
			pos = r.position
			normal = r.normal
	var basis := _basis_from_up(normal)

	_dust_ring(tree, root, pos, basis, power)
	_dust_plume(tree, root, pos, basis, power)
	_grit(tree, root, pos, basis, power)
	_rocks(tree, root, pos, normal, power)
	_crack(tree, root, pos, basis, power)
	Vfx.ring(node, pos + normal * 0.08, normal, Color(DUST.r, DUST.g, DUST.b, 0.9), 0.4, 4.0 * power, 0.35)
	Vfx.ring(node, pos + normal * 0.05, normal, Color(1, 1, 1, 0.5), 0.3, 2.4 * power, 0.22)


static func _basis_from_up(n: Vector3) -> Basis:
	var x := n.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = n.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(n).normalized()
	return Basis(x, n, z)


# ---------- เท็กซ์เจอร์ที่สร้างเองตอนรัน ----------

## กลุ่มควันขอบฟูไม่เรียบ (noise) — หมุนสุ่มต่ออนุภาคเลยไม่ซ้ำกัน
static func smoke_texture() -> Texture2D:
	if _smoke_tex:
		return _smoke_tex
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.035
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 4
	n.seed = 7
	var sz := 128
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in sz:
		for x in sz:
			var dx := (x - sz * 0.5) / (sz * 0.5)
			var dy := (y - sz * 0.5) / (sz * 0.5)
			var d := sqrt(dx * dx + dy * dy)
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			var edge := 1.0 - smoothstep(0.35 + 0.35 * v, 1.0, d)
			var a := clampf(edge * (0.45 + 0.75 * v), 0.0, 1.0)
			var shade := 0.86 + 0.14 * v                      # ด้านในมีเงาเข้มอ่อนให้ดูเป็นก้อน
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	_smoke_tex = ImageTexture.create_from_image(img)
	return _smoke_tex


## รอยแตก: หลุมตรงกลางสีเข้ม + รอยร้าวหยักๆ แผ่ออก (โปร่งใส ทับบนพื้น)
static func crack_texture() -> Texture2D:
	if _crack_tex:
		return _crack_tex
	var sz := 256
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	var c := Vector2(sz, sz) * 0.5
	# หลุมกลางไล่เข้ม
	for y in sz:
		for x in sz:
			var d := Vector2(x, y).distance_to(c) / (sz * 0.5)
			var k := 1.0 - 0.55 * (1.0 - smoothstep(0.0, 0.42, d))
			k *= 1.0 - 0.18 * (1.0 - smoothstep(0.3, 0.75, d))
			img.set_pixel(x, y, Color(k, k * 0.98, k * 0.95, 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var arms := 11
	for i in arms:
		var ang := TAU * i / arms + rng.randf_range(-0.25, 0.25)
		_crack_line(img, rng, c + Vector2.from_angle(ang) * 14.0, ang, rng.randf_range(70, 118), 3.0)
	# แปลงความเข้ม -> สีดินเข้ม + alpha (ขอบภาพใสสนิท)
	for y in sz:
		for x in sz:
			var k := img.get_pixel(x, y).r
			var edge := 1.0 - smoothstep(0.8, 1.0, Vector2(x, y).distance_to(c) / (sz * 0.5))
			img.set_pixel(x, y, Color(0.1, 0.085, 0.07, clampf((1.0 - k) * 1.1, 0.0, 1.0) * edge))
	_crack_tex = ImageTexture.create_from_image(img)
	return _crack_tex


static func _crack_line(img: Image, rng: RandomNumberGenerator, p: Vector2, ang: float, length: float, width: float) -> void:
	var travelled := 0.0
	while travelled < length and width > 0.6:
		ang += rng.randf_range(-0.45, 0.45)
		var step := rng.randf_range(4.0, 8.0)
		var q := p + Vector2.from_angle(ang) * step
		_stroke(img, p, q, width, 0.22 + 0.4 * travelled / length)
		p = q
		travelled += step
		width *= 0.965
		if rng.randf() < 0.12 and width > 1.2:        # แตกกิ่ง
			_crack_line(img, rng, p, ang + rng.randf_range(-0.9, 0.9), (length - travelled) * 0.5, width * 0.6)


static func _stroke(img: Image, a: Vector2, b: Vector2, w: float, val: float) -> void:
	var n := int(a.distance_to(b)) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		var r := int(ceil(w))
		for oy in range(-r, r + 1):
			for ox in range(-r, r + 1):
				var x := int(p.x) + ox
				var y := int(p.y) + oy
				if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
					continue
				var dd := Vector2(ox, oy).length()
				if dd > w:
					continue
				var old := img.get_pixel(x, y)
				var k := lerpf(val, 1.0, dd / maxf(w, 0.01))
				img.set_pixel(x, y, Color(minf(old.r, k), minf(old.g, k), minf(old.b, k), 1))


## หินเหลี่ยมไม่เรียบ (icosahedron บิดสุ่ม เงาแบนแบบหินจริง) สร้างไว้ 5 แบบ
static func rock_meshes() -> Array:
	if not _rock_meshes.is_empty():
		return _rock_meshes
	var t := (1.0 + sqrt(5.0)) * 0.5
	var base := [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var faces := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
		[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5],
		[2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for v in 5:
		var pts: Array[Vector3] = []
		var squash := Vector3(rng.randf_range(0.8, 1.3), rng.randf_range(0.5, 0.85), rng.randf_range(0.8, 1.2))
		for p in base:
			pts.append((p as Vector3).normalized() * rng.randf_range(0.72, 1.12) * squash)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(-1)
		for f in faces:
			st.add_vertex(pts[f[0]])
			st.add_vertex(pts[f[2]])
			st.add_vertex(pts[f[1]])
		st.generate_normals()
		_rock_meshes.append(st.commit())
	return _rock_meshes


# ---------- ชิ้นส่วนเอฟเฟกต์ ----------

static func _smoke_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = smoke_texture()
	mat.albedo_color = color
	return mat


static func _emitter(root: Node, pos: Vector3, basis: Basis, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.local_coords = false
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)
	p.global_transform = Transform3D(basis, pos)
	p.lifetime = life
	return p


## ฝุ่นแผ่เลียดพื้นเป็นวง: ออกเร็วแล้วเบรกแรง (แรงต้านอากาศ) ก้อนขยายใหญ่ ลอยขึ้นช้าๆ จางยาว
static func _dust_ring(tree: SceneTree, root: Node, pos: Vector3, basis: Basis, power: float) -> void:
	var life := 2.6
	var p := _emitter(root, pos + basis.y * 0.15, basis, life)
	p.amount = int((52 * power + 8) * GameState.fx_scale())
	p.explosiveness = 0.95
	p.randomness = 0.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.direction = Vector3(1, 0, 0)
	p.spread = 180.0
	p.flatness = 0.88                                  # เกือบขนานพื้น
	p.initial_velocity_min = 3.0 * power
	p.initial_velocity_max = 8.5 * power
	p.damping_min = 5.0
	p.damping_max = 8.0
	p.gravity = Vector3(0, 0.35, 0)                   # ฝุ่นร้อนลอยขึ้นช้าๆ
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -25.0
	p.angular_velocity_max = 25.0
	p.scale_amount_min = 0.9 * power + 0.3
	p.scale_amount_max = 1.9 * power + 0.4
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.35))
	sc.add_point(Vector2(0.15, 0.8))
	sc.add_point(Vector2(1.0, 1.6))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.06, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.55), Color(0.97, 0.97, 0.97, 0.32), Color(0.95, 0.95, 0.95, 0.0)])
	p.color_ramp = g
	var q := QuadMesh.new()
	q.material = _smoke_mat(DUST)
	p.mesh = q
	p.restart()
	tree.create_timer(life + 0.5, false).timeout.connect(p.queue_free)


## ลำฝุ่นพวยขึ้นตรงจุดกระแทก (ก้อนใหญ่ เข้มกว่า)
static func _dust_plume(tree: SceneTree, root: Node, pos: Vector3, basis: Basis, power: float) -> void:
	var life := 2.0
	var p := _emitter(root, pos + basis.y * 0.3, basis, life)
	p.amount = int((14 * power + 4) * GameState.fx_scale())
	p.explosiveness = 0.85
	p.randomness = 0.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.direction = Vector3(0, 1, 0)
	p.spread = 28.0
	p.initial_velocity_min = 2.5 * power
	p.initial_velocity_max = 6.0 * power
	p.damping_min = 3.0
	p.damping_max = 5.0
	p.gravity = Vector3(0, 0.2, 0)
	p.angle_max = 360.0
	p.angular_velocity_min = -30.0
	p.angular_velocity_max = 30.0
	p.scale_amount_min = 0.7 * power + 0.3
	p.scale_amount_max = 1.4 * power + 0.4
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.4))
	sc.add_point(Vector2(1.0, 1.5))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.05, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(0.92, 0.92, 0.92, 0.55), Color(0.95, 0.95, 0.95, 0.28), Color(1, 1, 1, 0.0)])
	p.color_ramp = g
	var q := QuadMesh.new()
	q.material = _smoke_mat(DUST.darkened(0.06))
	p.mesh = q
	p.restart()
	tree.create_timer(life + 0.5, false).timeout.connect(p.queue_free)


## กรวดเล็กๆ ปลิวแรง ตกด้วยแรงโน้มถ่วง
static func _grit(tree: SceneTree, root: Node, pos: Vector3, basis: Basis, power: float) -> void:
	var life := 0.9
	var p := _emitter(root, pos + basis.y * 0.12, basis, life)
	p.amount = int((40 * power + 8) * GameState.fx_scale())
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3(0, 1, 0)
	p.spread = 62.0
	p.initial_velocity_min = 3.5 * power + 1.0
	p.initial_velocity_max = 9.0 * power + 1.0
	p.gravity = Vector3(0, -14.0, 0)
	p.angle_max = 360.0
	p.scale_amount_min = 0.025
	p.scale_amount_max = 0.07
	var m := BoxMesh.new()
	m.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.37, 0.33)
	mat.roughness = 1.0
	m.material = mat
	p.mesh = m
	p.restart()
	tree.create_timer(life + 0.5, false).timeout.connect(p.queue_free)


## ก้อนหินจริง: ฟิสิกส์ตกกระดอนบนพื้น แล้วหดหายหลังจากนิ่ง
static func _rocks(tree: SceneTree, root: Node, pos: Vector3, normal: Vector3, power: float) -> void:
	var meshes := rock_meshes()
	var count := int((12 * power + 3) * GameState.fx_scale())
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.25
	pm.friction = 0.9
	for i in count:
		var rb := RigidBody3D.new()
		rb.collision_layer = 0                     # ไม่ชนตัวละคร (ไม่ขวางทาง)
		rb.collision_mask = 1                      # ชนพื้นแมพ
		rb.physics_material_override = pm
		var s := randf_range(0.06, 0.2) * (0.6 + 0.6 * power)
		if i < 3:
			s *= 1.6                               # มีก้อนใหญ่ปนนิดหน่อย
		rb.mass = s * 8.0
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[i % meshes.size()]
		mi.scale = Vector3.ONE * s
		var mat := StandardMaterial3D.new()
		mat.albedo_color = ROCK_COLORS[randi() % ROCK_COLORS.size()]
		mat.roughness = 1.0
		mi.material_override = mat
		rb.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = s * 0.8
		cs.shape = sh
		rb.add_child(cs)
		root.add_child(rb)
		var ang := randf() * TAU
		var out := Vector3(cos(ang), 0, sin(ang))
		rb.global_position = pos + normal * (0.15 + s) + out * randf_range(0.1, 0.45)
		rb.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		rb.linear_velocity = out * randf_range(1.5, 5.5) * power + normal * randf_range(3.0, 8.0) * (0.5 + 0.5 * power)
		rb.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 14.0
		var stay := randf_range(2.8, 4.2)
		var tw := rb.create_tween()
		tw.tween_interval(stay)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.001, 0.6).set_ease(Tween.EASE_IN)
		tw.tween_callback(rb.queue_free)


## รอยแตกบนพื้น: โผล่ทันที ค้างไว้สักพักแล้วค่อยจาง
static func _crack(tree: SceneTree, root: Node, pos: Vector3, basis: Basis, power: float) -> void:
	var mi := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	var size := 3.2 * power + 0.6
	pl.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = crack_texture()
	mat.albedo_color = Color(1, 1, 1, 1)
	pl.material = mat
	mi.mesh = pl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.global_transform = Transform3D(basis.rotated(basis.y, randf() * TAU), pos + basis.y * 0.03)
	var tw := mi.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.5)
	tw.tween_callback(mi.queue_free)
