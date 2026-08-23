shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

// Die Spree für Kapitel 3.
//
// Kein Spiegel, kein Bildschirmraum-Trick: eine ruhige Flussoberfläche ist
// vor allem **bewegte Normale**. Zwei gegenläufig driftende Wellenfelder
// erzeugen das Kräuseln; darüber liegt eine Fresnel-Mischung zwischen
// Tiefenfarbe (steil von oben) und Himmelsfarbe (flach über das Wasser).
// Beides läuft auf jedem Renderer, auch im Kompatibilitätsmodus des
// Web-Exports — Screen-Space-Reflexionen tun das nicht.
//
// Die Wellen sind bewusst klein und lang: die Vorlage zeigt eine glatte,
// windgekräuselte Spree, keine See.

group_uniforms Farben;
uniform vec3 tiefe : source_color = vec3(0.035, 0.075, 0.095);
uniform vec3 himmel : source_color = vec3(0.30, 0.43, 0.56);
uniform vec3 glanz : source_color = vec3(1.0, 0.98, 0.92);
uniform float fresnel_schaerfe : hint_range(1.0, 8.0) = 4.2;

group_uniforms Wellen;
uniform float wellen_groesse : hint_range(0.02, 4.0) = 0.30;
uniform float wellen_hoehe : hint_range(0.0, 1.5) = 0.14;
uniform float tempo : hint_range(0.0, 2.0) = 0.32;
uniform float hub : hint_range(0.0, 0.3) = 0.035;

// Eine billige, glatte Rauschfunktion. Kein Texturzugriff, damit der
// Shader ohne Beiwerk auskommt.
float rausch(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = sin(dot(i, vec2(12.9898, 78.233))) * 43758.5453;
	float b = sin(dot(i + vec2(1.0, 0.0), vec2(12.9898, 78.233))) * 43758.5453;
	float c = sin(dot(i + vec2(0.0, 1.0), vec2(12.9898, 78.233))) * 43758.5453;
	float d = sin(dot(i + vec2(1.0, 1.0), vec2(12.9898, 78.233))) * 43758.5453;
	a = fract(a); b = fract(b); c = fract(c); d = fract(d);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Jede Oktave wird gegen die vorige **gedreht**. Ohne das liegen alle
// Oktaven auf denselben Achsen, und das Ergebnis liest sich als Streifen —
// genau so sah die erste Fassung aus: ein Zebra statt einer Wasserfläche.
const mat2 DREH = mat2(vec2(0.86, 0.51), vec2(-0.51, 0.86));

float wellenfeld(vec2 p, float zeit) {
	float h = rausch(p + vec2(zeit, zeit * 0.6)) * 0.48;
	vec2 q = DREH * p * 2.1;
	h += rausch(q - vec2(zeit * 1.3, zeit * 0.4)) * 0.28;
	q = DREH * q * 2.3;
	h += rausch(q + vec2(zeit * 0.6, -zeit * 1.7)) * 0.16;
	q = DREH * q * 2.7;
	h += rausch(q + vec2(-zeit * 2.1, zeit * 0.9)) * 0.08;
	return h;
}

void vertex() {
	// Ein sehr flacher Hub: sichtbar an der Silhouette der Uferkante,
	// nicht als Wellenberge.
	vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * wellen_groesse;
	float h = wellenfeld(p, TIME * tempo);
	VERTEX.y += (h - 0.5) * hub;
}

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz * wellen_groesse;
	float zeit = TIME * tempo;
	// Normale aus dem Höhenfeld, per Differenz in beiden Richtungen.
	float e = 0.06;
	float h = wellenfeld(p, zeit);
	float hx = wellenfeld(p + vec2(e, 0.0), zeit);
	float hz = wellenfeld(p + vec2(0.0, e), zeit);
	vec3 n = normalize(vec3((h - hx) * wellen_hoehe, e * 0.35,
		(h - hz) * wellen_hoehe));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	float blick = clamp(dot(normalize(-VERTEX), NORMAL), 0.0, 1.0);
	float f = pow(1.0 - blick, fresnel_schaerfe);
	ALBEDO = mix(tiefe, himmel, clamp(f * 1.25, 0.0, 1.0));
	// Ein paar helle Kämme, wo das Höhenfeld oben steht — das sind die
	// Glanzpunkte, die eine Wasserfläche lebendig machen.
	float kamm = smoothstep(0.80, 0.99, h);
	ALBEDO += glanz * kamm * 0.035;
	ROUGHNESS = mix(0.04, 0.22, 1.0 - kamm);
	METALLIC = 0.15;
	SPECULAR = 0.9;
}
