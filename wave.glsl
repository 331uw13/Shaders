#version 410 core

uniform float fGlobalTime; // in seconds
uniform vec2 v2Resolution; // viewport resolution (in pixels)
uniform float fFrameTime; // duration of the last frame, in seconds

uniform sampler1D texFFT; // towards 0.0 is bass / lower freq, towards 1.0 is higher / treble freq
uniform sampler1D texFFTSmoothed; // this one has longer falloff and less harsh transients
uniform sampler1D texFFTIntegrated; // this is continually increasing
uniform sampler2D texPreviousFrame; // screenshot of the previous frame
uniform float fMidiKnob;

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

#define MAX_RAY_LEN  500.0
#define MAX_STEPS    200
#define MIN_DIST     0.01

#define FOV 60.0
#define PI 3.14159
#define PI_R (PI/180.0)


float sphereSD(vec3 p, vec3 c, float r) {
	return length(p-c)-r;
}

float octahedronSD(vec3 p, vec3 c, float r) {
	p = abs(p-c);
	return (p.x+p.y+p.z-r)*0.57735027;
}

float boxSD(vec3 p, vec3 c, vec3 r) {
	vec3 q = abs(p-c)-r;
	return length(max(q, 0.0))+min(max(q.x, max(q.y, q.z)), 0.0);
}


vec3 rep_xyz(vec3 p, vec3 f) {
	return mod(p, f)-0.5*f;
}

vec3 rep_xz(vec3 p, vec2 f) {
	vec2 r = mod(p.xz, f)-0.5*f;
	return vec3(r.x, p.y, r.y);
}

vec4 min_w(vec4 a, vec4 b) {
	return (a.w <= b.w) ? a : b;
}

mat2 rot_mat2(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat2(c, -s, s, c);
}

mat3 rot_mat3(vec2 a) {
	vec2 c = cos(a*PI_R);
	vec2 s = sin(a*PI_R);
	return mat3(c.y, 0.0, -s.y, s.y*s.x, c.x, c.y*s.x, s.y*c.x, -s.x, c.y*c.x);
}



vec4 map(vec3 p) {
	
	vec3 q = p;
	float time = fGlobalTime*8.0;
	q.x += cos((p.z*1.5+p.y*15.0)*PI_R-time)*2.0;
	q.y += sin((p.z+p.x*5.0)*PI_R*2.0+time)*2.5;
	
	vec3 r  = rep_xz(q, vec2(25.0, 5.0));
	vec3 r2 = rep_xz(q, vec2(25.0, 5.0));
	float d1 = octahedronSD(r,  vec3(0.0, -15.0, 3.0), 3.0);
	float d2 = octahedronSD(r2, vec3(0.0,  15.0, 3.0), 3.0);
	
	
	vec4 vd1 = vec4(vec3(1.0, 0.0, 0.5), d1);
	vec4 vd2 = vec4(vec3(0.0, 1.0, 1.0), d2);
	vec4 waves = mix(vd1, vd2, 0.5+0.5*sin(fGlobalTime)*1.15);
	
	
	q = p;
	q.y += sin(p.z*PI_R)*4.5;
	q.xy *= rot_mat2(p.z*PI_R*10.0+time*0.5);
	
	
	
	float num = 6.0;
	float a = 2.0*PI/num;
	float s = round(atan(q.x, q.y));
	
	q.xy *= rot_mat2(s*a);
	
	
	float ls = p.z/100.0;
	
	float d3 = boxSD(q, vec3(0.0, 0.8, 10.0), vec3(ls, ls, 10.0));
	vec4 lines = vec4(waves.xyz, d3);
	
	
	return min_w(lines, waves);
}



vec3 compute_normal(vec3 p) {
	vec2 e = vec2(0.01, 0.0);
	vec3 v = vec3(map(p-e.xyy).w, map(p-e.yxy).w, map(p-e.yyx).w);
	return normalize(map(p).w-v);
}

vec3 compute_light(vec3 p) {
	vec3 pos     = vec3(0.0, 0.0, 0.0);
	vec3 ambient = vec3(0.1, 0.1, 0.1);
	vec3 diffuse = vec3(0.8, 0.5, 0.3);
	
	vec3 n = compute_normal(p);
	return ambient+diffuse*dot(normalize(pos-p), n);
}

vec3 raydir() {
	vec2 rs = v2Resolution*0.5;
	float hf = tan((90.0-FOV*0.5)*(PI/180.0));
	return normalize(vec3(gl_FragCoord.xy-rs, (rs.y*hf)));
}

void ray_march(vec3 rd, vec3 ro) {
	vec3 p = vec3(0.0);
	vec4 closest = vec4(0.0);
	vec3 ray_color = vec3(0.0, 0.0, 0.0);
	float ray_len = 0.0;
	
	
	int i = 0;
	for(; i < MAX_STEPS; i++) {
		p = ro+rd*ray_len;
		
		vec4 dist = map(p);
		ray_len += abs(dist.w);
		
		if(closest.w > dist.w || closest.w <= 0.0) {
			closest = dist;
		}
		
		if(dist.w <= MIN_DIST) {
			ray_color = (dist.xyz*compute_light(p))*0.1;
			break;
		}
		if(ray_len >= MAX_RAY_LEN) {
			break;
		}
	}
	
	float fade = float(i)/float(MAX_STEPS);
	float fog = ray_len/MAX_RAY_LEN;
	
	vec3 fog_color = vec3(0.5, 0.0, 0.0);
	
	ray_color *= 1.0-fade;
	ray_color += closest.xyz*fade*1.25;
	
	out_color = vec4(ray_color,1.0);
}


void main(void) {
	vec3 ro = vec3(3.0, 3.0, -5.0);
	vec3 rd = raydir();
	
	rd *= rot_mat3(vec2(0.0, 0.0));
	
	ray_march(rd, ro);
}


