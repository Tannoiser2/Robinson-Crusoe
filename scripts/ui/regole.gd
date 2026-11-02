extends Control
## Regolamento in italiano, in breve (dal regolamento originale di Portal Games).

var main
var finestra := false

const REGOLE := """[font_size=30][color=#e8b86a]Lo scopo[/color][/font_size]
Robinson Crusoe è cooperativo: i naufraghi vincono o perdono insieme. Ogni scenario ha il suo [b]obiettivo[/b] (pulsante «Scenario» in alto) e un numero massimo di round. Si perde subito se un naufrago muore (Venerdì escluso) oppure se finisce l'ultimo round senza aver raggiunto l'obiettivo.

[font_size=30][color=#e8b86a]Il round: sei fasi[/color][/font_size]
[b]1. Evento[/b] (non nel primo round). Si pesca dal mazzo Eventi. Le carte Avventura e Mistero rimescolate nel mazzo fanno il loro effetto della metà inferiore e se ne pesca un'altra. Una carta Evento: se ha un simbolo Avventura (marrone, grigio o verde) si mette il segnalino Avventura sul mazzo di quel colore; se ha il [b]libro[/b] si applica l'effetto del libro dello scenario. Poi l'effetto dell'evento, e la carta va nello spazio Minaccia di destra; quella di destra scivola a sinistra e quella che esce dal tabellone applica il suo [b]Effetto minaccia[/b].
[b]2. Morale[/b]. Il primo giocatore guadagna o scarta Determinazione secondo il morale (da -3 a +2; con +3 può invece guarire una ferita). Nel solitario il morale sale di 1 prima.
[b]3. Produzione[/b]. La tessera del campo produce 1 legno e 1 cibo per ogni fonte non esaurita.
[b]4. Azione[/b]. Si pianificano le pedine (2 per naufrago, 1 per Venerdì) e poi si risolvono le azioni nell'ordine: minacce, caccia, costruire, raccogliere, esplorare, sistemare il campo, riposo.
[b]5. Meteo[/b]. Si tirano i dadi indicati dallo scenario e si aggiungono i gettoni nello spazio Meteo. Ogni nuvola di neve chiede 1 legno per scaldarsi; poi tutte le nuvole oltre il livello del tetto chiedono 1 cibo e 1 legno ciascuna. Il dado delle belve può portare un combattimento con una belva di forza 3, la perdita di cibo o di palizzata. La tempesta toglie 1 palizzata.
[b]6. Notte[/b]. Ognuno mangia 1 cibo (chi non mangia subisce 2 ferite). Si può spostare il campo su una tessera vicina (il rifugio resta, tetto e palizzata si dimezzano). Senza rifugio ognuno subisce 1 ferita. Il cibo deperibile avanzato va a male. Il primo giocatore passa al successivo.

[font_size=30][color=#e8b86a]Le azioni[/color][/font_size]
[b]Minaccia[/b]: con le pedine (e le risorse o gli oggetti) richiesti si risolve la metà inferiore di una carta nello spazio Minaccia: si prende la ricompensa e la carta non farà più danni. Il relitto iniziale dà cibo o legno (1 pedina) o di più (2 pedine).
[b]Caccia[/b]: 2 pedine; si pesca una belva dal mazzo Caccia (si forma esplorando tessere con la belva). Se la forza della belva supera il livello dell'arma si subiscono ferite pari alla differenza; poi l'arma perde quanto indicato e si prendono cibo e pellicce.
[b]Costruire[/b]: il rifugio, i livelli di tetto e palizzata (solo con un rifugio), l'arma (1 legno) e le invenzioni (servono il terreno esplorato e gli oggetti richiesti). I costi di rifugio, tetto e palizzata dipendono dal numero di giocatori.
[b]Raccogliere[/b]: si prende 1 risorsa da una fonte di una tessera diversa da quella del campo.
[b]Esplorare[/b]: si scopre una nuova tessera su una casella vicina a una tessera esplorata: terreno, fonti, belve, segnalini Scoperta, totem.
Per costruire, raccogliere ed esplorare: [b]con una pedina in più si riesce sicuri[/b], altrimenti si tirano i tre dadi del colore dell'azione: [b]successo[/b] (altrimenti si ottengono 2 Determinazione), [b]ferita[/b] e [b]avventura[/b] (si pesca e si risolve una carta Avventura). Ogni casella lontana dal campo chiede una pedina in più.
[b]Sistemare il campo[/b]: +2 Determinazione e +1 morale (con 4 giocatori uno dei due).
[b]Riposo[/b]: si guarisce 1 ferita.

[font_size=30][color=#e8b86a]Determinazione e abilità[/color][/font_size]
Ogni naufrago ha 4 abilità speciali che costano Determinazione e si usano una volta per round (passa il mouse sul naufrago per leggerle). Nel gioco si usano nei momenti in cui servono: prima di pianificare, dopo i dadi, nei combattimenti, nel meteo e nella notte.

[font_size=30][color=#e8b86a]Ferite e morale[/color][/font_size]
Ogni ferita sposta il segnalino sulla traccia del naufrago; quando supera una [b]freccia[/b] il morale del gruppo scende di 1. Se non si può pagare qualcosa che una carta chiede (risorse, livelli), chi risolve l'azione (o, fuori dalla fase Azione, ogni naufrago) subisce 1 ferita per ogni unità mancante. Si guarisce solo di notte, riposando o con gli effetti «subito».

[font_size=30][color=#e8b86a]Venerdì e il cane[/color][/font_size]
Con 1 o 2 giocatori gioca Venerdì: una pedina, non subisce gli eventi, il meteo e la fame, al posto delle avventure subisce una ferita; se muore la partita continua. Nel solitario c'è anche il cane: una pedina neutrale per cacciare o esplorare.

[font_size=30][color=#e8b86a]In questa versione[/color][/font_size]
Le scelte compaiono nel pannello in basso a destra; passando su un'opzione si illumina la casella dell'isola, e cliccando una casella illuminata la si sceglie. Passa il mouse su una carta per vederla grande con il testo in italiano. Le carte rivelate compaiono per qualche secondo al centro e restano nel diario. Il pulsante «Tavolo 3D» mostra il tabellone e i pezzi in tre dimensioni (si ruota trascinando, si avvicina con la rotellina). La partita si salva da sola: dal menu puoi continuarla.
"""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if finestra:
		var fondo := ColorRect.new()
		fondo.color = Color(0, 0, 0, 0.6)
		fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(fondo)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 160)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 30)
	add_child(m)
	var p := UI.pannello(Color(0.16, 0.11, 0.08, 0.98), UI.OCRA)
	m.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	h.add_child(UI.titolo("Regole di Robinson Crusoe", 52))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	var b := UI.bottone("Chiudi" if finestra else "Torna al menu", 22)
	b.pressed.connect(_chiudi)
	h.add_child(b)
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.add_theme_font_size_override("normal_font_size", 21)
	t.add_theme_font_size_override("bold_font_size", 21)
	t.add_theme_font_override("bold_font", UI.font_grassetto)
	t.text = REGOLE
	v.add_child(t)


func _chiudi() -> void:
	if finestra:
		queue_free()
	else:
		main.show_menu()
