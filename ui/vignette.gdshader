// Dezente Vignette: dunkelt die Bildränder ab und lenkt den Blick zur Mitte.
// Liegt als bildschirmfüllendes ColorRect unter der restlichen Oberfläche.
shader_type canvas_item;

uniform float staerke : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec2 abstand = UV - vec2(0.5);
	// Leicht elliptisch, dem Bildformat folgend.
	abstand.x *= 1.15;
	float rand = smoothstep(0.42, 0.98, length(abstand) * 1.55);
	COLOR = vec4(0.0, 0.0, 0.015, rand * staerke);
}
