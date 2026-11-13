extends SceneTree
## Servidor dedicado (sem tela). Guarda o mundo (semente, edicoes de blocos e micro-blocos, hora)
## e repassa jogadores, blocos e criaturas entre os clientes.
##   godot --headless --path . --script res://scripts/dedicated_server.gd -- --port=7777 [--seed=123] [--save=user://servidor.save]
## O primeiro jogador conectado simula criaturas, liquidos e plantacoes; se ele sair, outro assume.

var net: Net


func _initialize() -> void:
	var port := Net.DEFAULT_PORT
	var seed_v := -1
	var path := "user://servidor.save"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--port="):
			port = int(a.trim_prefix("--port="))
		elif a.begins_with("--seed="):
			seed_v = int(a.trim_prefix("--seed="))
		elif a.begins_with("--save="):
			path = a.trim_prefix("--save=")
	# Mesmo caminho de no que o jogo usa (/root/Main/Net), para os RPCs se encontrarem.
	var main := Node3D.new()
	main.name = "Main"
	root.add_child(main)
	net = Net.new()
	net.name = "Net"
	main.add_child(net)
	# Espera um quadro: a API de rede do no so existe depois que ele entra na arvore.
	await process_frame
	var err := net.start_dedicated(port, path, seed_v)
	if err != "":
		print("[servidor] ", err)
		quit(1)
		return
	print("[servidor] New Craft dedicado na porta %d - semente %d - mundo em %s" % [port, int(net.store["seed"]), ProjectSettings.globalize_path(path)])
	print("[servidor] Ctrl+C para encerrar (o mundo e salvo a cada minuto).")


func _finalize() -> void:
	if net != null:
		net.save_store()
