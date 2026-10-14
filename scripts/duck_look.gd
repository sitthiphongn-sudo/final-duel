extends Node3D
## ปรับหน้าตาผิวขนของเป็ดให้นุ่มฟูใกล้ใน Blender (แตะเฉพาะ material "Duck_Skin" = ผิว/ขนตัวเป็ด)
## เสื้อคลุม (Fur_Cloth) มงกุฎ ฯลฯ ไม่ถูกแตะ
@export var skin_tint := Color(1.0, 1.0, 1.0)   # สีผิวอบอุ่นอบเข้าไปใน texture แล้ว
@export var skin_normal := 0.25
@export var skin_rim := 0.0
@export var neck_color := Color(1.0, 0.92, 0.62)
@export var ruff_radius := 0.42
@export var ruff_thick := 0.05
@export var ruff_y := 0.0
@export var ruff_color := Color(0.90, 0.81, 0.54)
@export var skin_roughness := 1.0

func _ready() -> void:
	apply(get_parent())

## ขนคอสีขาว (ruff) คาดรอยต่อหัวกับตัว: รอยต่อเป็นเส้นแยกของโมเดลสองชิ้น ปิดด้วยวงขนให้เนียนเหมือนปกเสื้อ
func _add_neck_ruff(root: Node) -> void:
	for sk in root.find_children("*", "Skeleton3D", true, false):
		var skel := sk as Skeleton3D
		if skel.find_bone("Head") < 0 or skel.get_node_or_null("NeckRuff") != null:
			continue
		var att := BoneAttachment3D.new()
		att.name = "NeckRuff"
		att.bone_name = "Head"
		skel.add_child(att)
		var mi := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = ruff_radius - ruff_thick
		tm.outer_radius = ruff_radius + ruff_thick
		tm.rings = 40
		tm.ring_segments = 14
		mi.mesh = tm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.92, 0.62)
		mat.roughness = 1.0
		mat.emission_enabled = true
		mat.emission = Color(0.9, 0.78, 0.45)
		mat.emission_energy_multiplier = 0.4
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
		mi.position = Vector3(0.0, ruff_y, 0.0)
		mi.scale = Vector3(1.02, 1.0, 0.98)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		att.add_child(mi)
		# แกนคอด้านใน: กันรูเล็กๆ บนผิวคอ (จากการลดโพลี) ไม่ให้เห็นทะลุเป็นจุดขาว/ดำ
		var core := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.40
		cm.bottom_radius = 0.40
		cm.height = 0.70
		cm.radial_segments = 32
		cm.rings = 1
		core.mesh = cm
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(1.0, 0.92, 0.62)
		cmat.roughness = 1.0
		cmat.emission_enabled = true
		cmat.emission = Color(0.9, 0.78, 0.45)
		cmat.emission_energy_multiplier = 0.35
		core.material_override = cmat
		core.position = Vector3(0.0, -0.10, -0.02)
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		att.add_child(core)
		return


func apply(root: Node) -> void:
	_add_neck_ruff(root)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(s) as StandardMaterial3D
			if mat == null:
				continue
			var nm := mat.resource_name.to_lower()
			if nm.contains("gold"):
				# มงกุฎ/ทอง: ไฟล์ใหม่ตั้งโลหะ 1.0 + พื้นผิวมืด -> ดำสนิท ใช้สีทองตรงๆ แทน
				var g := mat.duplicate() as StandardMaterial3D
				g.albedo_texture = null
				g.albedo_color = Color(0.95, 0.72, 0.22)
				g.metallic = 0.55
				g.roughness = 0.32
				g.emission_enabled = true
				g.emission = Color(0.9, 0.6, 0.15)
				g.emission_energy_multiplier = 0.2
				m.set_surface_override_material(s, g)
				continue
			if nm.contains("neck"):
				# วงขนที่คอ (รอยต่อหัวกับตัว): ใช้สีทึบไม่รับแสงสะท้อน กลืนกับผิว ไม่ให้เป็นเส้นสว่าง/เส้นโหว่
				var nk := StandardMaterial3D.new()
				nk.resource_name = "Neck_Flat"
				nk.albedo_color = Color(neck_color.r, neck_color.g, neck_color.b, 0.0)
				nk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				nk.roughness = 1.0
				nk.cull_mode = BaseMaterial3D.CULL_DISABLED
				m.set_surface_override_material(s, nk)
				continue
			if nm.contains("fur_cloth"):
				# เสื้อคลุม: ไม่แตะสี/ลาย แค่ทำให้เห็นสองด้าน กันรูโหว่ตรงคอเห็นทะลุไปพื้นหลัง
				var fc := mat.duplicate() as StandardMaterial3D
				fc.cull_mode = BaseMaterial3D.CULL_DISABLED
				m.set_surface_override_material(s, fc)
				continue
			if not nm.contains("skin"):
				continue
			var c := mat.duplicate() as StandardMaterial3D
			c.albedo_color = skin_tint
			c.normal_scale = skin_normal
			c.normal_enabled = skin_normal > 0.0
			c.roughness = skin_roughness
			c.cull_mode = BaseMaterial3D.CULL_DISABLED
			c.rim_enabled = skin_rim > 0.0
			c.rim = skin_rim
			c.rim_tint = 0.6
			m.set_surface_override_material(s, c)
