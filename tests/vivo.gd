extends SceneTree
## Partita "dal vivo" con l'interfaccia: una persona simulata preme le scelte (come farebbe l'IA)
## e si salvano alcune schermate. Uso: godot --path . -s tests/vivo.gd -- cartella [3d] [scenario] [giocatori]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() > 0 else "/tmp/vivo"
	var tre := args.size() > 1 and args[1] == "3d"
	var sc := int(args[2]) if args.size() > 2 else 1
	var ng := int(args[3]) if args.size() > 3 else 2
	DirAccess.make_dir_recursive_absolute(dir)
	root.size = Vector2i(1920, 1080)
	var main = load("res://scripts/ui/main.gd").new()
	root.add_child(main)
	await process_frame
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("%s/menu.png" % dir)
	var gg := [{"nome": "Stefano", "ia": false, "personaggio": "cuoco"}]
	for i in ng - 1:
		gg.append({"nome": ["Anna", "Marco", "Luca"][i], "ia": true, "personaggio": ["carpentiere", "esploratore", "soldato"][i]})
	main.start_game({"scenario": sc, "giocatori": gg, "vista3d": tre, "ritardo_ia": 0.0, "seme": 7 + sc})
	await process_frame
	var vista = main.current
	var ia := IA.new()
	var scatti := 0
	var passi := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 90000:
		await create_timer(0.05).timeout
		if vista.motore == null:
			continue
		if vista.motore.esito != "":
			break
		if vista._in_attesa:
			passi += 1
			if (passi % 9 == 2 and scatti < 8) or (vista._richiesta.get("tipo", "") == "piazza" and scatti < 3):
				await create_timer(0.4).timeout
				root.get_texture().get_image().save_png("%s/passo%02d.png" % [dir, scatti])
				scatti += 1
			var k: int = ia.scegli(vista.motore, vista._richiesta["posto"], vista._richiesta)
			vista._premi(k)
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png("%s/fine.png" % dir)
	print("FINE esito=%s round=%d passi=%d" % [vista.motore.esito, vista.motore.round, passi])
	quit()
