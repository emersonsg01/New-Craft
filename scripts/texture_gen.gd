class_name TextureGen
extends RefCounted
## Gera na GPU (compute shader) todas as texturas PBR do jogo: albedo, normal+altura e
## AO/rugosidade/metal/emissao. Nenhum arquivo de imagem e usado.

const S := 256

var albedo: Texture2DArray
var normal: Texture2DArray
var orm: Texture2DArray
var icons: Array[ImageTexture] = []
var avg_colors: Array[Color] = []
var failed := false
var gpu_ms := 0.0

var _imgs_a: Array[Image] = []
var _imgs_n: Array[Image] = []
var _imgs_o: Array[Image] = []
var _mutex := Mutex.new()
var _done := 0
var _thread: Thread


func start() -> void:
	var n := Blocks.LAYERS.size()
	_imgs_a.resize(n)
	_imgs_n.resize(n)
	_imgs_o.resize(n)
	avg_colors.resize(n)
	_thread = Thread.new()
	_thread.start(_gpu_run)


func progress() -> float:
	_mutex.lock()
	var d := _done
	_mutex.unlock()
	return float(d) / Blocks.LAYERS.size()


func is_done() -> bool:
	return _thread == null or not _thread.is_alive()


func _gpu_run() -> void:
	var t0 := Time.get_ticks_usec()
	var layers := Blocks.LAYERS.size()
	var rd := RenderingServer.create_local_rendering_device()
	if rd == null:
		push_error("TextureGen: este renderizador nao oferece RenderingDevice (use Forward+).")
		failed = true
		return
	var src := RDShaderSource.new()
	src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	src.source_compute = TexShader.source()
	var spirv := rd.shader_compile_spirv_from_source(src)
	if spirv.compile_error_compute != "":
		push_error("TextureGen: erro no compute shader:\n" + spirv.compile_error_compute)
		failed = true
		rd.free()
		return
	var shader := rd.shader_create_from_spirv(spirv)
	var texs: Array[RID] = []
	var fmts := [RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM, RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM,
		RenderingDevice.DATA_FORMAT_R32_SFLOAT, RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM]
	var uniforms := []
	for i in 4:
		var f := RDTextureFormat.new()
		f.width = S
		f.height = S
		f.array_layers = layers
		f.texture_type = RenderingDevice.TEXTURE_TYPE_2D_ARRAY
		f.format = fmts[i]
		f.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
		var t := rd.texture_create(f, RDTextureView.new(), [])
		texs.append(t)
		var u := RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		u.binding = i
		u.add_id(t)
		uniforms.append(u)
	var defs := Blocks.layer_bytes()
	var buf := rd.storage_buffer_create(defs.size(), defs)
	var ub := RDUniform.new()
	ub.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	ub.binding = 4
	ub.add_id(buf)
	uniforms.append(ub)
	var uset := rd.uniform_set_create(uniforms, shader, 0)
	var pipeline := rd.compute_pipeline_create(shader)
	var pc := PackedByteArray()
	pc.resize(16)
	for pass_id in 2:
		pc.encode_s32(0, pass_id)
		var cl := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(cl, pipeline)
		rd.compute_list_bind_uniform_set(cl, uset, 0)
		rd.compute_list_set_push_constant(cl, pc, pc.size())
		rd.compute_list_dispatch(cl, S / 8, S / 8, layers)
		rd.compute_list_end()
		rd.submit()
		rd.sync()
	for layer in layers:
		var ia := Image.create_from_data(S, S, false, Image.FORMAT_RGBA8, rd.texture_get_data(texs[0], layer))
		var io := Image.create_from_data(S, S, false, Image.FORMAT_RGBA8, rd.texture_get_data(texs[1], layer))
		var inn := Image.create_from_data(S, S, false, Image.FORMAT_RGBA8, rd.texture_get_data(texs[3], layer))
		avg_colors[layer] = _average(ia)
		ia.generate_mipmaps()
		io.generate_mipmaps()
		inn.generate_mipmaps()
		_imgs_a[layer] = ia
		_imgs_o[layer] = io
		_imgs_n[layer] = inn
		_mutex.lock()
		_done += 1
		_mutex.unlock()
	rd.free_rid(pipeline)
	rd.free_rid(uset)
	rd.free_rid(buf)
	for t in texs:
		rd.free_rid(t)
	rd.free_rid(shader)
	rd.free()
	gpu_ms = (Time.get_ticks_usec() - t0) / 1000.0


## Cor media dos pixels opacos (usada no terreno distante e nas particulas).
static func _average(img: Image) -> Color:
	var small := img.duplicate() as Image
	small.resize(16, 16, Image.INTERPOLATE_BILINEAR)
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var w := 0.0
	for y in 16:
		for x in 16:
			var c := small.get_pixel(x, y)
			if c.a > 0.5:
				r += c.r
				g += c.g
				b += c.b
				w += 1.0
	if w < 1.0:
		return Color(0.5, 0.5, 0.5)
	return Color(r / w, g / w, b / w)


func finish() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	if failed:
		return
	albedo = Texture2DArray.new()
	albedo.create_from_images(_imgs_a)
	normal = Texture2DArray.new()
	normal.create_from_images(_imgs_n)
	orm = Texture2DArray.new()
	orm.create_from_images(_imgs_o)
	for i in Blocks.LAYERS.size():
		var im: Image = _imgs_a[i].duplicate()
		im.clear_mipmaps()
		im.resize(64, 64, Image.INTERPOLATE_BILINEAR)
		icons.append(ImageTexture.create_from_image(im))
