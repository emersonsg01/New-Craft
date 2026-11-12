shader_type spatial;
// Modelos do Blockbench (.bbmodel): textura pintada com filtro nitido, recorte de transparencia
// e clarao de dano, igual ao material voxel por vertice.

instance uniform float flash = 0.0;
uniform sampler2D tex : source_color, filter_nearest, repeat_disable;
uniform float alpha = 1.0;

void fragment() {
	vec4 t = texture(tex, UV);
	if (t.a < 0.5) {
		discard;
	}
	ALBEDO = mix(t.rgb, vec3(1.0, 0.15, 0.1), flash * 0.7);
	ROUGHNESS = 0.8;
	SPECULAR = 0.3;
	//ALPHA
}
