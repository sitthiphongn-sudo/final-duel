extends SceneTree
## สร้าง asset เวอร์ชันเบา (ใช้ทั้งบนเว็บและเครื่อง) ลงโฟลเดอร์ res://lite/
##   - แมพ: ตัดส่วนใต้เกาะที่กล้องมองไม่เห็นทิ้ง + ลดจำนวน polygon + collision แบบหยาบ + ลดขนาด texture
##   - ตัวละคร: ลดจำนวน polygon + ลดขนาด texture + แยกท่าวิ่งเป็นไฟล์ .res (ไม่ต้องโหลด GLB ท่าวิ่งทั้งไฟล์)
## รัน: godot --headless --path . --script res://tools/bake_lite_assets.gd
## (ไฟล์ต้นฉบับ GLB ไม่ถูกแก้ ถ้าจะปรับค่าแล้ว bake ใหม่ก็รันซ้ำได้)

const MAP_GLB := "res://Meshy_AI_Skyborne_Ruins_0920051107_texture.glb"
const MAP_SCALE := 30.0          ## ต้องตรงกับ transform ของ Map ใน main.tscn
const MAP_OFFSET_Y := -3.95
const MAP_CUT_Y := -2.5          ## (พิกัดโลก) ลบสามเหลี่ยมที่ต่ำกว่าพื้นลานเกิน 2.5 เมตรทั้งอัน
const MAP_DOWN_CUT_Y := -0.6      ## ลบหน้าที่หันลงข้างล่างที่อยู่ต่ำกว่าพื้น (ใต้แผ่นหิน มองไม่เห็นอยู่แล้ว)
const MAP_TARGET_TRIS := 220000
const MAP_COLLISION_TRIS := 30000
const MAP_ALBEDO_SIZE := 2048
const MAP_NORMAL_SIZE := 1024

const CHAR_TARGET_TRIS := 26000
const CHAR_ALBEDO_SIZE := 2048
const CHAR_OTHER_SIZE := 1024

const CHARS := {
	"emberclaw": {
		"walk": "res://characters/emberclaw/Meshy_AI_Emberclaw_Guardian_biped_Animation_Walking_withSkin.glb",
		"run": "res://characters/emberclaw/Meshy_AI_Emberclaw_Guardian_biped_Animation_Running_withSkin.glb",
	},
	"frostfang": {
		"walk": "res://characters/frostfang/Meshy_AI_Frostfang_Guardian_biped_Animation_Walking_withSkin.glb",
		"run": "res://characters/frostfang/Meshy_AI_Frostfang_Guardian_biped_Animation_Running_withSkin.glb",
	},
}

var textures_to_import: Array = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://lite/map"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://lite/characters"))
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or "map" in args:
		_bake_map()
	if args.is_empty() or "chars" in args:
		for id in CHARS:
			_bake_character(id)
	_write_texture_imports()
	print("BAKE DONE")
	quit()


# ------------------------------------------------------------------ helpers

## เก็บเฉพาะสามเหลี่ยมใน indices แล้วบีบ vertex ที่ไม่ใช้ทิ้ง
func _compact(arrays: Array, indices: PackedInt32Array) -> Array:
	var vcount: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var remap := PackedInt32Array()
	remap.resize(vcount)
	remap.fill(-1)
	var order := PackedInt32Array()
	var new_idx := PackedInt32Array()
	new_idx.resize(indices.size())
	for i in indices.size():
		var v := indices[i]
		if remap[v] < 0:
			remap[v] = order.size()
			order.append(v)
		new_idx[i] = remap[v]
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for a in Mesh.ARRAY_MAX:
		var src = arrays[a]
		if src == null or a == Mesh.ARRAY_INDEX:
			continue
		var per := 1
		if a == Mesh.ARRAY_TANGENT:
			per = 4
		elif a == Mesh.ARRAY_BONES or a == Mesh.ARRAY_WEIGHTS:
			per = src.size() / vcount
		var dst = src.duplicate()
		dst.resize(order.size() * per)
		for n in order.size():
			var s := order[n] * per
			var d := n * per
			for k in per:
				dst[d + k] = src[s + k]
		out[a] = dst
	out[Mesh.ARRAY_INDEX] = new_idx
	return out


## ลด polygon ด้วย meshoptimizer ของ Godot (ImporterMesh.generate_lods) แล้วเลือก LOD ที่ใกล้เป้าที่สุด
func _decimate(arrays: Array, target_tris: int, bones := false) -> PackedInt32Array:
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if idx.size() / 3 <= target_tris:
		return idx
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	var best := idx
	var best_diff := absi(idx.size() / 3 - target_tris)
	for l in im.get_surface_lod_count(0):
		var li := im.get_surface_lod_indices(0, l)
		var diff := absi(li.size() / 3 - target_tris)
		if diff < best_diff:
			best_diff = diff
			best = li
	# generate_lods อาจเชื่อม vertex ใหม่ -> ใช้ arrays ของ ImporterMesh แทน
	var new_arrays := im.get_surface_arrays(0)
	arrays.assign(new_arrays)
	return best


func _save_tex(tex: Texture2D, path: String, size: int, jpg: bool, normal := false) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	if img.has_mipmaps():
		img.clear_mipmaps()
	if img.get_width() > size:
		img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	if jpg:
		img.convert(Image.FORMAT_RGB8)
		img.save_jpg(ProjectSettings.globalize_path(path), 0.9)
	else:
		img.save_png(ProjectSettings.globalize_path(path))
	textures_to_import.append([path, normal])
	# ใช้รูปที่ resize แล้วโดยตรง (ตอนเปิดใน editor/รันจริง จะโหลดไฟล์ที่ import แล้วแทน)
	return null


## .import ของ texture: บีบอัด VRAM + mipmaps (ใช้กับโมเดล 3D)
func _write_texture_imports() -> void:
	for t in textures_to_import:
		var path: String = t[0]
		var normal: bool = t[1]
		var ext := path.get_extension()
		var f := FileAccess.open(ProjectSettings.globalize_path(path + ".import"), FileAccess.WRITE)
		f.store_string("""[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="%s"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=%d
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
""" % [path, 1 if normal else 2])
		f.close()


# ------------------------------------------------------------------ map

func _bake_map() -> void:
	var t0 := Time.get_ticks_msec()
	var inst := (load(MAP_GLB) as PackedScene).instantiate()
	var mi := inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := mi.mesh
	var arrays := mesh.surface_get_arrays(0)
	var src_mat := mesh.surface_get_material(0) as BaseMaterial3D
	var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	print("map: tris=", idx.size() / 3, " verts=", pos.size())

	# 1) ตัดส่วนใต้เกาะ
	var cut := (MAP_CUT_Y - MAP_OFFSET_Y) / MAP_SCALE
	var down_cut := (MAP_DOWN_CUT_Y - MAP_OFFSET_Y) / MAP_SCALE
	var kept := PackedInt32Array()
	kept.resize(idx.size())
	var n := 0
	for i in range(0, idx.size(), 3):
		var a := pos[idx[i]]
		var b := pos[idx[i + 1]]
		var c := pos[idx[i + 2]]
		var top := maxf(a.y, maxf(b.y, c.y))
		if top < cut:
			continue
		if top < down_cut:
			var nrm := (c - a).cross(b - a)     # Godot ใช้ลำดับจุดตามเข็มนาฬิกาเป็นด้านหน้า
			if nrm.y < -0.2 * nrm.length():     # หันลงล่าง
				continue
		kept[n] = idx[i]
		kept[n + 1] = idx[i + 1]
		kept[n + 2] = idx[i + 2]
		n += 3
	kept.resize(n)
	arrays = _compact(arrays, kept)
	print("map: after cut tris=", n / 3, " (", Time.get_ticks_msec() - t0, " ms)")

	# 2) ลด polygon
	var full := arrays.duplicate()
	var lod_idx := _decimate(arrays, MAP_TARGET_TRIS)
	var render_arrays := _compact(arrays, lod_idx)
	print("map: render tris=", lod_idx.size() / 3, " verts=", (render_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())

	# 3) collision หยาบ
	var col_arrays := []   # ใช้แค่ตำแหน่ง (ไม่มี normal/UV) ลดได้มากกว่า
	col_arrays.resize(Mesh.ARRAY_MAX)
	# เชื่อม vertex ที่ตำแหน่งซ้ำกัน (รอยต่อ UV) ไม่งั้นลดไม่ลง
	var fpos: PackedVector3Array = full[Mesh.ARRAY_VERTEX]
	var fidx: PackedInt32Array = full[Mesh.ARRAY_INDEX]
	var weld := {}
	var wpos := PackedVector3Array()
	var vmap := PackedInt32Array()
	vmap.resize(fpos.size())
	for i in fpos.size():
		var key := Vector3i((fpos[i] * 20000.0).round())
		var w = weld.get(key, -1)
		if w < 0:
			w = wpos.size()
			weld[key] = w
			wpos.append(fpos[i])
		vmap[i] = w
	var widx := PackedInt32Array()
	widx.resize(fidx.size())
	for i in fidx.size():
		widx[i] = vmap[fidx[i]]
	col_arrays[Mesh.ARRAY_VERTEX] = wpos
	col_arrays[Mesh.ARRAY_INDEX] = widx
	print("map: welded verts ", fpos.size(), " -> ", wpos.size())
	var col_idx := _decimate(col_arrays, MAP_COLLISION_TRIS)
	for _i in 4:   # meshoptimizer หยุดที่ความละเอียดระดับหนึ่ง -> ลดซ้ำจนใกล้เป้า
		if col_idx.size() / 3 < MAP_COLLISION_TRIS * 1.3:
			break
		col_arrays = _compact(col_arrays, col_idx)
		col_idx = _decimate(col_arrays, MAP_COLLISION_TRIS)
	var col_pos: PackedVector3Array = col_arrays[Mesh.ARRAY_VERTEX]
	var faces := PackedVector3Array()
	faces.resize(col_idx.size())
	for i in col_idx.size():
		faces[i] = col_pos[col_idx[i]]
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	print("map: collision tris=", col_idx.size() / 3)

	# 4) texture + วัสดุ (สีแมพเหมือนในเกม: ไม่ใช้ metallic/roughness texture อยู่แล้ว -> ทิ้ง)
	_save_tex(src_mat.albedo_texture, "res://lite/map/skyborne_albedo.jpg", MAP_ALBEDO_SIZE, true)
	_save_tex(src_mat.normal_texture, "res://lite/map/skyborne_normal.png", MAP_NORMAL_SIZE, false, true)

	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, render_arrays)
	ResourceSaver.save(am, "res://lite/map/skyborne_mesh.res", ResourceSaver.FLAG_COMPRESS)
	ResourceSaver.save(shape, "res://lite/map/skyborne_collision.res", ResourceSaver.FLAG_COMPRESS)
	inst.free()
	print("map: done in ", Time.get_ticks_msec() - t0, " ms")


# ------------------------------------------------------------------ characters

func _bake_character(id: String) -> void:
	var t0 := Time.get_ticks_msec()
	var info: Dictionary = CHARS[id]
	var root := (load(info["walk"]) as PackedScene).instantiate() as Node3D
	var mi := root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := mi.mesh
	var arrays := mesh.surface_get_arrays(0)
	var src_mat := mesh.surface_get_material(0) as BaseMaterial3D
	if src_mat == null:
		src_mat = mi.get_active_material(0) as BaseMaterial3D
	print(id, ": tris=", (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3)
	var lod_idx := _decimate(arrays, CHAR_TARGET_TRIS, true)
	var new_arrays := _compact(arrays, lod_idx)
	print(id, ": -> tris=", lod_idx.size() / 3, " verts=", (new_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())

	var dir := "res://lite/characters/%s_" % id
	_save_tex(src_mat.albedo_texture, dir + "albedo.jpg", CHAR_ALBEDO_SIZE, true)
	_save_tex(src_mat.normal_texture, dir + "normal.png", CHAR_OTHER_SIZE, false, true)
	_save_tex(src_mat.metallic_texture, dir + "orm.png", CHAR_OTHER_SIZE, false)

	var am := ArrayMesh.new()
	var flags: int = mesh.surface_get_format(0) & (Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays, [], {}, flags)
	ResourceSaver.save(am, dir + "mesh.res", ResourceSaver.FLAG_COMPRESS)

	# ท่าวิ่ง -> Animation .res
	var run_inst := (load(info["run"]) as PackedScene).instantiate()
	var ap := run_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for n in ap.get_animation_list():
		if not n.contains("001") and n != "RESET":
			var anim := ap.get_animation(n).duplicate(true) as Animation
			ResourceSaver.save(anim, dir + "run_anim.res", ResourceSaver.FLAG_COMPRESS)
			break
	run_inst.free()

	# ข้อมูล skin / โครงกระดูก เก็บไว้สร้างฉากตัวละคร (ขั้นถัดไป หลัง import texture)
	var skin := mi.skin.duplicate(true) if mi.skin else null
	if skin:
		ResourceSaver.save(skin, dir + "skin.res")
	var wap := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for n in wap.get_animation_list():
		if not n.contains("001") and n != "RESET":
			ResourceSaver.save(wap.get_animation(n).duplicate(true), dir + "walk_anim.res", ResourceSaver.FLAG_COMPRESS)
			break
	root.free()
	print(id, ": done in ", Time.get_ticks_msec() - t0, " ms")
