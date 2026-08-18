// Dezente Vignette plus feines Filmkorn: dunkelt die Bildränder ab und gibt
// dem Bild eine leise, lebendige Struktur — glatte Flächen wirken sonst
// nach Computergrafik. Liegt als bildschirmfüllendes ColorRect unter der
// restlichen Oberfläche.
shader_type canvas_item;

uniform float staerke : hint_range(0.0, 1.0) = 0.3;
uniform float korn_staerke : hint_range(0.0, 0.2) = 0.035;

void fragment() {
	vec2 abstand = UV - vec2(0.5);
	// Leicht elliptisch, dem Bildformat folgend.
	abstand.x *= 1.15;
	float rand = smoothstep(0.42, 0.98, length(abstand) * 1.55);
	// Animiertes Korn — je Bild neu gewürfelt.
	float korn = fract(sin(dot(UV * 941.7 + fract(TIME) * 17.3,
		vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(0.0, 0.0, 0.015, clamp(rand * staerke + korn * korn_staerke, 0.0, 1.0));
}
