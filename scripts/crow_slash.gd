extends RefCounted
## เส้นฟันแบบการ์ตูน (crescent) ของกาจอมยุทธ์ — เมชเสี้ยวพระจันทร์ + shader เส้นกวาดออกจากหางไปหัว แล้วจางหาย
## ใช้: Slash.arc(node, xform, from_deg, to_deg, radius, width, plane)  xform = ทรานส์ฟอร์มของโมเดล (หน้า = +Z)

const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float reveal = 0.0;
uniform float fade = 1.0;
uniform vec3 edge_col = vec3(1.0, 0.16, 0.12);
varying float tt;
varying float ss;
void vertex() { tt = UV.x; ss = UV.y; }
void fragment() {
	if (tt > reveal) discard;
	float head = smoothstep(reveal - 0.55, reveal, tt);
	float d = abs(ss - 0.5) * 2.0;
	vec3 col = mix(vec3(1.0, 1.0, 1.0), edge_col, smoothstep(0.35, 0.95, d));
	ALBEDO = col;
	ALPHA = clamp(fade * mix(0.7, 1.0, head) * (1.0 - smoothstep(0.85, 1.0, d) * 0.6) * 1.8, 0.0, 1.0);
}
"""
static var _shader: Shader


static func _sh() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	return _shader


## plane: 0 = แนวนอน (ฟันซ้าย-ขวา), 1 = แนวตั้งหน้า-หลัง (เสยขึ้น/ฟันลง), tilt = เอียงเส้น (องศา)
static func arc(node: Node, xf: Transform3D, from_deg: float, to_deg: float, radius := 1.25,
		width := 0.34, plane := 0, center := Vector3(0, 1.1, 0.0), tilt := 0.0, scale := 1.0, hold := 0.0) -> void:
	var tree := node.get_tree()
	if tree == null:
		return
	var N := 26
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var tl := Basis(Vector3.FORWARD, deg_to_rad(tilt))
	for i in N + 1:
		var t := float(i) / N
		var a := deg_to_rad(lerpf(from_deg, to_deg, t))
		var taper := pow(sin(PI * t), 0.65)
		var dirv: Vector3
		if plane == 0:
			dirv = Vector3(sin(a), 0.0, cos(a))
		else:
			dirv = Vector3(0.0, sin(a), cos(a))
		var outer := tl * (dirv * radius * scale)
		var inner := tl * (dirv * (radius * scale - width * scale * taper))
		verts.append(center + outer)
		verts.append(center + inner)
		uvs.append(Vector2(t, 0.0))
		uvs.append(Vector2(t, 1.0))
		if i < N:
			var k := i * 2
			idx.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := ShaderMaterial.new()
	mat.shader = _sh()
	mat.set_shader_parameter("reveal", 0.0)
	mat.set_shader_parameter("fade", 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4.0
	var root: Node = tree.current_scene if tree.current_scene != null else node
	root.add_child(mi)
	mi.global_transform = xf
	var tw := mi.create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("reveal", v), 0.0, 1.15, 0.09)
	tw.tween_interval(0.07 + hold)
	tw.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.22)
	tw.tween_callback(mi.queue_free)
