extends SceneTree
## Partite automatiche con sole IA su tutti gli scenari: il motore deve arrivare sempre in fondo senza errori.
## Uso: godot --headless --path . -s tests/sim.gd -- [partite] [scenario]
## Con LOGSIM=1 stampa tutto il registro della partita.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 12
	var solo := int(args[1]) if args.size() > 1 else 0
	var vinte := 0
	var t_tot := Time.get_ticks_msec()
	for k in n:
		var sc: int = solo if solo > 0 else 1 + (k % 6)
		var ng: int = 1 + (k % 4)
		var m := Motore.new()
		get_root().add_child(m)
		var gg := []
		for i in ng:
			gg.append({"nome": "IA %d" % (i + 1), "ia": true})
		var ia := IA.new()
		for i in ng:
			m.controllori.append(ia)
		m.prepara({"giocatori": gg, "scenario": sc, "seme": 1000 + k})
		var t0 := Time.get_ticks_msec()
		var msg := [0]
		m.messaggio.connect(func(t): msg[0] += 1; if OS.get_environment("LOGSIM") != "": print("  ", t))
		await m.gioca()
		if m.esito == "vittoria":
			vinte += 1
		var pg := []
		for p in m.pg:
			pg.append("%s %d/%d" % [p["nome"], p["ferite"], m.max_ferite(m.pg.find(p))])
		print("partita %d: scenario %d, %d giocatori -> %s al round %d (%s; tetto %d pal %d arma %d; %d msg, %d ms)" % [
			k, sc, ng, m.esito, m.round, ", ".join(pg), m.tetto, m.palizzata, m.arma, msg[0], Time.get_ticks_msec() - t0])
		m.queue_free()
	print("FINE: %d partite, %d vinte (%d ms)" % [n, vinte, Time.get_ticks_msec() - t_tot])
	quit()
