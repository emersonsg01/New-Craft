extends Node3D
## Cena principal do executavel do servidor dedicado (NewCraftServer.exe).
## Faz o mesmo que dedicated_server.gd, mas como cena, para o .exe abrir direto no servidor.
##   NewCraftServer.exe --port=7777 --seed=123 --save=user://servidor.save
## Este no se chama "Main" e o Net fica em /root/Main/Net, igual ao jogo, para os RPCs se encontrarem.

var net: Net


func _ready() -> void:
	var port := Net.DEFAULT_PORT
	var seed_v := -1
	var path := "user://servidor.save"
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--port="):
			port = int(a.trim_prefix("--port="))
		elif a.begins_with("--seed="):
			seed_v = int(a.trim_prefix("--seed="))
		elif a.begins_with("--save="):
			path = a.trim_prefix("--save=")
	net = Net.new()
	net.name = "Net"
	add_child(net)
	await get_tree().process_frame
	var err := net.start_dedicated(port, path, seed_v)
	if err != "":
		print("[servidor] ", err)
		get_tree().quit(1)
		return
	print("[servidor] New Craft dedicado na porta %d - semente %d - mundo em %s" % [port, int(net.store["seed"]), ProjectSettings.globalize_path(path)])
	print("[servidor] Feche esta janela ou aperte Ctrl+C para encerrar (o mundo e salvo a cada minuto).")


func _exit_tree() -> void:
	if net != null:
		net.save_store()
