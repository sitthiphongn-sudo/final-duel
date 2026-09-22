shader_type canvas_item;
// พื้นหลังฉากเลือกตัวละคร: ฟ้าอมเขียวไล่เฉด + หมอกเรืองแสงหลังตัวละคร + ลำแสงจากด้านบน + ฝุ่นลอย + ขอบมืด

uniform vec4 c_top : source_color = vec4(0.02, 0.10, 0.14, 1.0);
uniform vec4 c_mid : source_color = vec4(0.07, 0.30, 0.36, 1.0);
uniform vec4 c_bot : source_color = vec4(0.015, 0.06, 0.08, 1.0);
uniform vec4 accent : source_color = vec4(0.4, 0.9, 1.0, 1.0);
uniform float time_s = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(c_top.rgb, c_mid.rgb, smoothstep(0.0, 0.62, uv.y));
	col = mix(col, c_bot.rgb, smoothstep(0.66, 1.0, uv.y));

	// หมอกเรืองแสงด้านหลังตัวละคร (ผสมสีธาตุนิดหน่อย)
	vec2 q = (uv - vec2(0.5, 0.5)) * vec2(1.7, 1.0);
	float haze = exp(-dot(q, q) * 5.0);
	col += mix(vec3(0.25, 0.65, 0.7), accent.rgb, 0.35) * haze * 0.38;

	// แถบแสงเส้นขอบฟ้า / พื้นสะท้อน
	col += vec3(0.3, 0.62, 0.66) * 0.22 * exp(-pow((uv.y - 0.74) * 10.0, 2.0));

	// ลำแสงเฉียงจากด้านบน ขยับช้าๆ
	float ang = atan(uv.x - 0.5, uv.y + 0.35);
	float rays = pow(0.5 + 0.5 * sin(ang * 16.0 + time_s * 0.12), 3.0) * (0.5 + 0.5 * sin(ang * 5.0 - time_s * 0.08));
	col += vec3(0.35, 0.7, 0.75) * rays * 0.07 * (1.0 - uv.y);

	// เส้นแนวนอนจางๆ (โทนเทคโนโลยี)
	col += vec3(0.4, 0.8, 0.85) * 0.015 * step(0.5, fract(uv.y * 180.0));

	// ฝุ่นแสงลอยขึ้น
	vec2 g = uv * vec2(48.0, 27.0) + vec2(0.0, time_s * 0.35);
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float rnd = hash(id);
	vec2 off = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
	float d = length(f - off * 0.6);
	float star = smoothstep(0.08, 0.0, d) * step(0.86, rnd);
	star *= 0.5 + 0.5 * sin(time_s * 2.0 + rnd * 40.0);
	col += vec3(0.6, 0.95, 1.0) * star * 0.5;

	// ขอบจอมืดลง
	float v = smoothstep(1.15, 0.3, length((uv - 0.5) * vec2(1.35, 1.1)));
	col *= mix(0.4, 1.0, v);
	COLOR = vec4(col, 1.0);
}
