class_name GpuWorldGen
extends RefCounted
## Gera os chunks com um compute shader num RenderingDevice local, dentro de uma thread propria.
## A CPU so le o resultado, planta as arvores e aplica as edicoes do jogador.

var gen: WorldGen
var failed := false
var chunk_ms := 0.0

var _thread: Thread
var _sem := Semaphore.new()
var _mutex := Mutex.new()
var _queue: Array = []
var _results: Array = []
var _quit := false
var _tasks: Array[int] = []
var _tmutex := Mutex.new()


func start(world_gen: WorldGen) -> void:
	gen = world_gen
	_thread = Thread.new()
	_thread.start(_run)


func request(key: Vector2i, mods: Dictionary, dim: int = 0) -> void:
	_mutex.lock()
	_queue.append([key, mods, dim])
	_mutex.unlock()
	_sem.post()


func _finish_task(key: Vector2i, blocks: PackedByteArray, cols: PackedInt32Array, mods: Dictionary, dim: int) -> void:
	var d := gen.finish(blocks, cols, key.x, key.y, mods, dim)
	_mutex.lock()
	_results.append([key, d, dim])
	_mutex.unlock()


func take_results() -> Array:
	_mutex.lock()
	var r := _results
	_results = []
	_mutex.unlock()
	return r


func stop() -> void:
	if _thread == null:
		return
	_mutex.lock()
	_quit = true
	_queue.clear()
	_mutex.unlock()
	_sem.post()
	_thread.wait_to_finish()
	_thread = null
	_tmutex.lock()
	for t in _tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	_tasks.clear()
	_tmutex.unlock()


func _run() -> void:
	var rd := RenderingServer.create_local_rendering_device()
	if rd == null:
		push_error("GpuWorldGen: este renderizador nao oferece RenderingDevice (use Forward+ ou Mobile).")
		failed = true
		return
	var src := RDShaderSource.new()
	src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	src.source_compute = WGShaders.chunk_compute_source()
	var spirv := rd.shader_compile_spirv_from_source(src)
	if spirv.compile_error_compute != "":
		push_error("GpuWorldGen: erro no compute shader:\n" + spirv.compile_error_compute)
		failed = true
		return
	var shader := rd.shader_create_from_spirv(spirv)

	var fmt := RDTextureFormat.new()
	fmt.width = 256
	fmt.height = WorldGen.H
	fmt.format = RenderingDevice.DATA_FORMAT_R8_UINT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	var tex_blocks := rd.texture_create(fmt, RDTextureView.new(), [])
	var fmt2 := RDTextureFormat.new()
	fmt2.width = 20
	fmt2.height = 20
	fmt2.format = RenderingDevice.DATA_FORMAT_R16_UINT
	fmt2.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	var tex_cols := rd.texture_create(fmt2, RDTextureView.new(), [])

	var u0 := RDUniform.new()
	u0.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u0.binding = 0
	u0.add_id(tex_blocks)
	var u1 := RDUniform.new()
	u1.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u1.binding = 1
	u1.add_id(tex_cols)
	var uset := rd.uniform_set_create([u0, u1], shader, 0)
	var pipeline := rd.compute_pipeline_create(shader)
	var pc := PackedByteArray()
	pc.resize(16)
	var cols := PackedInt32Array()
	cols.resize(400)

	while true:
		_sem.wait()
		_mutex.lock()
		var quit := _quit
		var req: Variant = _queue.pop_front() if not _queue.is_empty() else null
		_mutex.unlock()
		if quit:
			break
		if req == null:
			continue
		var t0 := Time.get_ticks_usec()
		var key: Vector2i = req[0]
		pc.encode_s32(0, key.x * 16)
		pc.encode_s32(4, key.y * 16)
		pc.encode_u32(8, gen.seed_v & 0xFFFFFFFF)
		pc.encode_u32(12, int(req[2]))
		var cl := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(cl, pipeline)
		rd.compute_list_bind_uniform_set(cl, uset, 0)
		rd.compute_list_set_push_constant(cl, pc, pc.size())
		rd.compute_list_dispatch(cl, 32, WorldGen.H / 8, 1)
		rd.compute_list_end()
		rd.submit()
		rd.sync()
		var blocks := rd.texture_get_data(tex_blocks, 0)
		var craw := rd.texture_get_data(tex_cols, 0)
		for i in 400:
			cols[i] = craw.decode_u16(i * 2)
		chunk_ms = lerpf(chunk_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.1)
		var tid := WorkerThreadPool.add_task(_finish_task.bind(key, blocks, cols.duplicate(), req[1], int(req[2])))
		_tmutex.lock()
		_tasks.append(tid)
		# Libera ids de tarefas ja concluidas.
		var k := _tasks.size() - 1
		while k >= 0:
			if WorkerThreadPool.is_task_completed(_tasks[k]):
				WorkerThreadPool.wait_for_task_completion(_tasks[k])
				_tasks.remove_at(k)
			k -= 1
		_tmutex.unlock()

	rd.free_rid(pipeline)
	rd.free_rid(uset)
	rd.free_rid(tex_blocks)
	rd.free_rid(tex_cols)
	rd.free_rid(shader)
	rd.free()
