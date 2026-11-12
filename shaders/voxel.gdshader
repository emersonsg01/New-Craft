shader_type spatial;
// Material dos modelos voxel (itens, personagem e mobs): cor por vertice, com clarao de dano.

instance uniform float flash = 0.0;
uniform float alpha = 1.0;

void fragment() {
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = mix(col, vec3(1.0, 0.15, 0.1), flash * 0.7);
	ROUGHNESS = 0.78;
	SPECULAR = 0.3;
	//ALPHA
}
