class_name Dati
extends RefCounted
## Dati del gioco (carte, tessere isola, scenari, personaggi, segnalini scoperta) letti dai file JSON in data/.

static var _cache := {}


static func _leggi(nome: String):
	if _cache.has(nome):
		return _cache[nome]
	var f := FileAccess.open("res://data/%s.json" % nome, FileAccess.READ)
	var v = JSON.parse_string(f.get_as_text())
	_cache[nome] = v
	return v


## Carte per id (chiave intera).
static func carte() -> Dictionary:
	if _cache.has("_carte"):
		return _cache["_carte"]
	var d := {}
	for c in _leggi("carte"):
		d[int(c["id"])] = c
	_cache["_carte"] = d
	return d


static func tessere() -> Dictionary:
	if _cache.has("_tessere"):
		return _cache["_tessere"]
	var d := {}
	for t in _leggi("tessere"):
		d[int(t["n"])] = t
	_cache["_tessere"] = d
	return d


static func scenari() -> Array:
	return _leggi("scenari")


static func scenario(n: int) -> Dictionary:
	for s in scenari():
		if int(s["n"]) == n:
			return s
	return {}


static func personaggi() -> Array:
	return _leggi("personaggi")


static func personaggio(id: String) -> Dictionary:
	for p in personaggi():
		if p["id"] == id:
			return p
	return {}


static func scoperte() -> Dictionary:
	return _leggi("scoperte")
