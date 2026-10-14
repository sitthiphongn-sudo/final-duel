extends Node3D
## ดาบคาตานะของกาจอมยุทธ์ (สร้างจากโค้ด ไม่ใช้โมเดล) ติดที่มือขวา ปลายดาบชี้ตามแกน +Y ของกระดูกมือ
## draw(sec) = ชักดาบออกมา sec วินาที แล้วเก็บเข้าฝักเอง (ด้ามที่สะพายหลังจะหายไปตอนดาบอยู่ในมือ)

var hold := 0.0
var back_mesh: MeshInstance3D       ## เมชตัวกา (ซ่อนผิวที่ 1 = ด้ามดาบบนหลัง ตอนชักดาบ)
var back_mat: Material
var _hide_mat: StandardMaterial3D
var glow: MeshInstance3D


func _init() -> void:
	visible = false
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.62, 0.66, 0.74)
	steel.metallic = 0.85
	steel.roughness = 0.32
	steel.emission_enabled = true
	steel.emission = Color(1.0, 0.18, 0.12)
	steel.emission_energy_multiplier = 0.25
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.095, 0.95, 0.02)
	blade.mesh = bm
	blade.material_override = steel
	blade.position = Vector3(0, 0.12 + 0.475, 0)
	add_child(blade)
	# เส้นสันดาบเรืองแสงสีแดง (ให้เห็นชัดตอนฟัน)
	var edge_mat := StandardMaterial3D.new()
	edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge_mat.albedo_color = Color(1.0, 0.25, 0.2)
	glow = MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.008, 0.93, 0.016)
	glow.mesh = gm
	glow.material_override = edge_mat
	glow.position = Vector3(0.046, 0.12 + 0.475, 0)
	add_child(glow)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.78, 0.25)
	gold.metallic = 0.8
	gold.roughness = 0.3
	var guard := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.075
	cm.bottom_radius = 0.075
	cm.height = 0.014
	guard.mesh = cm
	guard.material_override = gold
	guard.position = Vector3(0, 0.11, 0)
	add_child(guard)
	var wrap := StandardMaterial3D.new()
	wrap.albedo_color = Color(0.55, 0.04, 0.05)
	wrap.roughness = 0.8
	var handle := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.024
	hm.bottom_radius = 0.026
	hm.height = 0.32
	handle.mesh = hm
	handle.material_override = wrap
	handle.position = Vector3(0, -0.06, 0)
	add_child(handle)
	var pommel := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.034
	sm.height = 0.068
	pommel.mesh = sm
	pommel.material_override = gold
	pommel.position = Vector3(0, -0.225, 0)
	add_child(pommel)
	for mi in [blade, glow, guard, handle, pommel]:
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hide_mat = StandardMaterial3D.new()
	_hide_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hide_mat.albedo_color = Color(1, 1, 1, 0.0)


func draw(sec: float) -> void:
	hold = maxf(hold, sec)
	if not visible:
		visible = true
		if back_mesh and back_mesh.mesh and back_mesh.mesh.get_surface_count() > 1:
			back_mesh.set_surface_override_material(1, _hide_mat)
	set_process(true)


func sheathe() -> void:
	hold = 0.0
	visible = false
	if back_mesh and is_instance_valid(back_mesh) and back_mesh.mesh and back_mesh.mesh.get_surface_count() > 1:
		back_mesh.set_surface_override_material(1, back_mat)


func _process(delta: float) -> void:
	if not visible:
		return
	hold -= delta
	if hold <= 0.0:
		sheathe()
