shader_type sky;
// ท้องฟ้าแบบ procedural: ไล่สีบรรยากาศ + ดวงอาทิตย์ + แสงฟุ้งรอบดวงอาทิตย์
// + ชั้นเมฆด้านบนที่ลอยไปช้าๆ + ทะเลเมฆด้านล่าง (แมพเป็นเกาะลอยฟ้า)

group_uniforms Atmosphere;
uniform vec3 zenith_color : source_color = vec3(0.16, 0.34, 0.66);
uniform vec3 horizon_color : source_color = vec3(0.74, 0.72, 0.66);
uniform vec3 sun_glow_color : source_color = vec3(1.0, 0.72, 0.42);
uniform float horizon_softness = 0.35;
uniform float sun_size = 0.9994;
uniform float sun_glow = 6.0;
uniform float exposure = 1.0;

group_uniforms Clouds;
uniform vec3 cloud_color : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 cloud_shadow_color : source_color = vec3(0.42, 0.46, 0.56);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.48;
uniform float cloud_softness : hint_range(0.01, 0.5) = 0.18;
uniform float cloud_scale = 0.9;
uniform float cloud_speed = 0.012;
uniform vec2 wind_dir = vec2(1.0, 0.35);

group_uniforms CloudSea;
uniform bool cloud_sea = true;
uniform float sea_coverage : hint_range(0.0, 1.0) = 0.55;
uniform float sea_scale = 0.6;
uniform vec3 sea_depth_color : source_color = vec3(0.26, 0.32, 0.46);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 6; i++) {
		v += a * noise(p);
		p = rot * p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// ความหนาแน่นเมฆ 0..1 ที่ตำแหน่ง uv
float cloud_density(vec2 uv, float coverage, float t) {
	vec2 w = normalize(wind_dir);
	float base = fbm(uv + w * t);
	float detail = fbm(uv * 3.1 - w * t * 1.7);
	float d = base * 0.75 + detail * 0.25;
	return smoothstep(1.0 - coverage, 1.0 - coverage + cloud_softness, d);
}

void sky() {
	vec3 dir = EYEDIR;
	vec3 sun_dir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(0.4, 0.5, -0.7));
	vec3 sun_col = LIGHT0_ENABLED ? LIGHT0_COLOR : vec3(1.0);
	float sun_dot = clamp(dot(dir, sun_dir), 0.0, 1.0);

	// ---- บรรยากาศ ----
	float h = clamp(dir.y, -1.0, 1.0);
	float t_sky = pow(clamp(h, 0.0, 1.0), horizon_softness);
	vec3 col = mix(horizon_color, zenith_color, t_sky);
	// ขอบฟ้าด้านล่างหม่นลงเล็กน้อย
	col = mix(col, horizon_color * 0.85, clamp(-h * 3.0, 0.0, 1.0));
	// แสงฟุ้งรอบดวงอาทิตย์ (mie scattering แบบง่าย)
	col += sun_glow_color * (pow(sun_dot, sun_glow) * 0.35 + pow(sun_dot, 64.0) * 0.6);

	// ---- เมฆด้านบน ----
	if (!AT_CUBEMAP_PASS && h > 0.0) {
		vec2 uv = dir.xz / (h + 0.12) * cloud_scale;
		float t = TIME * cloud_speed;
		float d = cloud_density(uv, cloud_coverage, t);
		// แสงผ่านเมฆ: ตัวอย่างความหนาแน่นเลื่อนไปทางดวงอาทิตย์ เมฆหนา = มืดกว่า
		vec2 to_sun = normalize(sun_dir.xz + 1e-4) * 0.08;
		float d_sun = cloud_density(uv + to_sun, cloud_coverage, t);
		float light = clamp(1.0 - d_sun * 0.75, 0.0, 1.0);
		vec3 ccol = mix(cloud_shadow_color, cloud_color * sun_col, light);
		// ขอบเมฆสว่างเมื่ออยู่ใกล้ดวงอาทิตย์ (silver lining)
		ccol += sun_glow_color * pow(sun_dot, 8.0) * (1.0 - d) * 1.2;
		// เมฆไกลๆ จางเข้าขอบฟ้า
		float fade = smoothstep(0.0, 0.25, h);
		col = mix(col, ccol, d * fade * 0.95);
	}

	// ---- ทะเลเมฆด้านล่าง ----
	if (!AT_CUBEMAP_PASS && cloud_sea && h < 0.0) {
		float hh = -h;
		vec2 uv = dir.xz / (hh + 0.05) * sea_scale;
		float t = TIME * cloud_speed * 0.6;
		// ก้อนเมฆใหญ่ + รายละเอียด -> ยอดเมฆพองสว่าง ร่องระหว่างก้อนมืดอมฟ้า
		float big = fbm(uv * 0.35 + normalize(wind_dir) * t * 0.5);
		float d = cloud_density(uv + vec2(31.0, 17.0), sea_coverage, t);
		float top = clamp(smoothstep(0.35, 0.75, big) * 0.6 + d * 0.55, 0.0, 1.0);
		// ด้านที่หันหาดวงอาทิตย์สว่างกว่า (เงาในร่องเมฆ)
		float d_sun = cloud_density(uv + vec2(31.0, 17.0) + normalize(sun_dir.xz + 1e-4) * 0.06, sea_coverage, t);
		float shade = clamp(0.55 + (d - d_sun) * 1.5 + top * 0.4, 0.0, 1.0);
		vec3 sea = mix(sea_depth_color, cloud_color * sun_col, shade * top + (1.0 - top) * 0.15);
		sea += sun_glow_color * pow(sun_dot, 6.0) * 0.35 * top;
		// ไกลๆ กลืนเป็นหมอกขอบฟ้า
		float fade = smoothstep(0.0, 0.3, hh);
		col = mix(horizon_color * 0.92 + sun_glow_color * pow(sun_dot, 4.0) * 0.2, sea, fade);
	}

	// ---- ดวงอาทิตย์ ----
	if (h > -0.02) {
		float disk = smoothstep(sun_size, sun_size + 0.0003, dot(dir, sun_dir));
		col += sun_col * disk * 12.0;
	}

	COLOR = col * exposure;
}
