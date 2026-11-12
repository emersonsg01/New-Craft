class_name Hardware
extends RefCounted
## Deteccao de hardware para o ajuste automatico: CPU, RAM, GPU e VRAM.
## A Godot nao informa a VRAM total; no Windows ela vem do registro do driver, senao e estimada
## pelo nome/tipo da placa. O orcamento de memoria do mundo ainda mede o uso real em tempo de jogo.

const GB := 1073741824.0

static var detected := false
static var cores := 1
static var cpu_name := ""
static var ram_total := 0
static var gpu_name := ""
static var gpu_type := 0
static var vram_total := 0
static var vram_from_driver := false


static func detect() -> void:
	if detected:
		return
	detected = true
	cores = maxi(1, OS.get_processor_count())
	cpu_name = OS.get_processor_name()
	var mi := OS.get_memory_info()
	ram_total = int(mi.get("physical", 8.0 * GB))
	if ram_total <= 0:
		ram_total = int(8.0 * GB)
	gpu_name = RenderingServer.get_video_adapter_name()
	gpu_type = RenderingServer.get_video_adapter_type()
	vram_total = _vram_from_registry()
	vram_from_driver = vram_total > 0
	if vram_total <= 0:
		vram_total = _vram_guess()


static func _vram_from_registry() -> int:
	if OS.get_name() != "Windows":
		return 0
	var out := []
	var key := "HKLM\\SYSTEM\\ControlSet001\\Control\\Class\\{4d36e968-e325-11ce-bfc1-08002be10318}"
	var code := OS.execute("reg", ["query", key, "/s", "/v", "HardwareInformation.qwMemorySize"], out, true)
	if code != 0 or out.is_empty():
		return 0
	var best := 0
	for line: String in str(out[0]).split("\n"):
		var i := line.find("0x")
		if line.find("REG_QWORD") >= 0 and i >= 0:
			var v := line.substr(i + 2).strip_edges().hex_to_int()
			best = maxi(best, v)
	return best


static func _vram_guess() -> int:
	var n := gpu_name.to_upper()
	if gpu_type == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		return int(clampf(ram_total / 4.0, 1.0 * GB, 4.0 * GB))
	var table := {"4090": 24, "4080": 16, "4070": 12, "4060": 8, "3090": 24, "3080": 10, "3070": 8, "3060": 12, "3050": 8,
		"2080": 8, "2070": 8, "2060": 6, "1660": 6, "1650": 4, "1080": 8, "1070": 8, "1060": 6, "7900": 20, "7800": 16, "7700": 12,
		"7600": 8, "6900": 16, "6800": 16, "6700": 12, "6600": 8, "6500": 4, "A770": 16, "A750": 8, "A580": 8, "B580": 12}
	for k: String in table:
		if n.find(k) >= 0:
			return int(table[k] * GB)
	return int(6.0 * GB)


## 0 = baixo, 1 = medio, 2 = alto, 3 = ultra.
static func tier() -> int:
	detect()
	var v := vram_total / GB
	var r := ram_total / GB
	var score := 0.0
	score += clampf(v / 4.0, 0.0, 3.0)
	score += clampf(r / 16.0, 0.0, 1.5)
	score += clampf(cores / 8.0, 0.0, 1.5)
	if gpu_type == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		score -= 1.5
	if score < 2.0:
		return 0
	if score < 3.4:
		return 1
	if score < 4.8:
		return 2
	return 3


const TIER_NAMES: Array[String] = ["Baixo", "Médio", "Alto", "Ultra"]


## Configuracao sugerida para o hardware detectado.
static func recommended() -> Dictionary:
	match tier():
		0: return {"preset": "low", "render_distance": 6, "lod_distance": 2000}
		1: return {"preset": "medium", "render_distance": 10, "lod_distance": 4000}
		2: return {"preset": "high", "render_distance": 16, "lod_distance": 8000}
	return {"preset": "ultra", "render_distance": 32, "lod_distance": 16000}


static func summary() -> String:
	detect()
	return "CPU: %s (%d núcleos)\nRAM: %.1f GB\nGPU: %s\nVRAM: %.1f GB %s\nNível detectado: %s" % [
		cpu_name, cores, ram_total / GB, gpu_name, vram_total / GB, "(driver)" if vram_from_driver else "(estimada)", TIER_NAMES[tier()]]
