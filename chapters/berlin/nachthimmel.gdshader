// Der Nachthimmel über Berlin: Farbverlauf wie zuvor, aber mit einer
// langsam ziehenden Wolkenschicht. Die Wolken sind von unten schwach warm
// angeleuchtet — die Lichtglocke der Stadt —, ihr Kern ist dunkler als der
// Himmel dahinter. Reines Wertrauschen, keine Texturen.
shader_type sky;

uniform vec3 oben : source_color = vec3(0.012, 0.02, 0.05);
uniform vec3 horizont : source_color = vec3(0.16, 0.115, 0.1);
uniform vec3 boden_farbe : source_color = vec3(0.015, 0.015, 0.025);
uniform vec3 wolken_kern : source_color = vec3(0.045, 0.05, 0.075);
uniform vec3 wolken_saum : source_color = vec3(0.15, 0.11, 0.085);
uniform float deckung : hint_range(0.0, 1.0) = 0.42;
uniform float tempo = 0.008;

float wuerfel(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float wert_rauschen(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(wuerfel(i), wuerfel(i + vec2(1, 0)), f.x),
		mix(wuerfel(i + vec2(0, 1)), wuerfel(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float summe = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		summe += amp * wert_rauschen(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		amp *= 0.5;
	}
	return summe;
}

void sky() {
	float h = clamp(EYEDIR.y, -1.0, 1.0);
	vec3 farbe;
	if (h < 0.0) {
		farbe = mix(horizont, boden_farbe, clamp(-h * 6.0, 0.0, 1.0));
	} else {
		farbe = mix(horizont, oben, pow(clamp(h * 1.5, 0.0, 1.0), 0.5));
	}

	if (h > 0.02) {
		// Wolken auf einer gedachten Ebene: Blickrichtung auf sie projiziert,
		// zwei Schichten ziehen unterschiedlich schnell.
		vec2 flach = EYEDIR.xz / max(h, 0.08);
		vec2 zug = vec2(TIME * tempo, TIME * tempo * 0.35);
		float dichte = fbm(flach * 0.55 + zug) * 0.7
			+ fbm(flach * 1.4 - zug * 1.7) * 0.3;
		float masse = smoothstep(1.0 - deckung - 0.22, 1.0 - deckung + 0.22, dichte);
		float saum = smoothstep(1.0 - deckung - 0.22, 1.0 - deckung, dichte)
			- smoothstep(1.0 - deckung, 1.0 - deckung + 0.22, dichte) * 0.5;
		vec3 wolke = mix(wolken_saum, wolken_kern, smoothstep(0.3, 1.0, masse));
		float sicht = smoothstep(0.02, 0.18, h);
		farbe = mix(farbe, wolke, clamp(masse, 0.0, 1.0) * sicht * 0.9);
		farbe += wolken_saum * saum * sicht * 0.15;
	}
	COLOR = farbe;
}
