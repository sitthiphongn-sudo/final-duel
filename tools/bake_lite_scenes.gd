extends SceneTree
## ขั้นที่ 2 (หลัง bake_lite_assets.gd + import texture แล้ว): ประกอบฉาก .tscn ของแมพและตัวละครเวอร์ชันเบา
## รัน: godot --headless --path . --import  แล้ว  godot --headless --path . --script res://tools/bake_lite_scenes.gd

const CHAR_GLB := {
	"emberclaw": "res://characters/emberclaw/Meshy_AI_Emberclaw_Guardian_biped_Animation_Walking_withSkin.glb",
	"frostfang": "res://characters/frostfang/Meshy_AI_Frostfang_Guardian_biped_Animation_Walking_withSkin.glb",
}


func _initialize() -> void:
	_build_map()
	for id in CHAR_GLB:
		_build_character(id)
	print("SCENES DONE")
	quit()


func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		c.scene_file_path = ""
		_own(c, root)


func _build_map() -> void:
	var root := Node3D.new()
	root.name = "SkyborneRuins"
	var mesh := load("res://lite/map/skyborne_mesh.res") as ArrayMesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://lite/map/skyborne_albedo.jpg")
	mat.normal_enabled = true
	mat.normal_texture = load("res://lite/map/skyborne_normal.png")
	mat.normal_scale = 0.6
	mat.metallic = 0.0
	mat.metallic_specular = 0.25
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	ResourceSaver.save(mesh, "res://lite/map/skyborne_mesh.res", ResourceSaver.FLAG_COMPRESS)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	root.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Collision"
	root.add_child(body)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	cs.shape = load("res://lite/map/skyborne_collision.res")
	body.add_child(cs)
	_own(root, root)
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, "res://lite/map/skyborne_ruins.tscn")
	root.free()
	print("map scene saved")


func _build_character(id: String) -> void:
	var dir := "res://lite/characters/%s_" % id
	var root := (load(CHAR_GLB[id]) as PackedScene).instantiate() as Node3D
	root.scene_file_path = ""
	root.name = id.capitalize()
	var mi := root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var src_mat := mi.get_active_material(0) as BaseMaterial3D
	var mat := src_mat.duplicate() as BaseMaterial3D
	mat.albedo_texture = load(dir + "albedo.jpg")
	mat.normal_texture = load(dir + "normal.png")
	if src_mat.metallic_texture:
		mat.metallic_texture = load(dir + "orm.png")
	if src_mat.roughness_texture:
		mat.roughness_texture = load(dir + "orm.png")
	for p in ["ao_texture", "emission_texture", "detail_albedo", "heightmap_texture"]:
		if mat.get(p) != null:
			mat.set(p, null)
	var mesh := load(dir + "mesh.res") as ArrayMesh
	mesh.surface_set_material(0, mat)
	ResourceSaver.save(mesh, dir + "mesh.res", ResourceSaver.FLAG_COMPRESS)
	mi.mesh = mesh
	mi.set_surface_override_material(0, null)
	mi.skin = load(dir + "skin.res")
	var ap := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for lib_name in ap.get_animation_library_list():
		ap.remove_animation_library(lib_name)
	var lib := AnimationLibrary.new()
	var walk := load(dir + "walk_anim.res") as Animation
	lib.add_animation("Walking", walk)
	ap.add_animation_library("", lib)
	_own(root, root)
	var ps := PackedScene.new()
	ps.pack(root)
	var out := "res://lite/characters/%s.tscn" % id
	ResourceSaver.save(ps, out)
	root.free()
	# ตรวจว่าไม่อ้างอิงไฟล์ GLB ต้นฉบับแล้ว
	var deps := ResourceLoader.get_dependencies(out)
	for d in deps:
		if d.contains(".glb"):
			push_error("ยังอ้างอิง GLB: " + d)
	print(id, " scene saved, deps=", deps, " mesh deps=", ResourceLoader.get_dependencies(dir + "mesh.res"))
