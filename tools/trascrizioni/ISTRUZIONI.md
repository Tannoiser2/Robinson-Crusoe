# Trascrizione carte di Robinson Crusoe (Adventures on the Cursed Island, Portal Games)

Le immagini da leggere stanno in `/home/claude/src/out/leggi/`: ogni file `<mazzo>_<id1>-<id2>-<id3>.jpg`
mostra fino a 3 carte affiancate, da sinistra a destra nell'ordine degli id nel nome del file.
Leggi le immagini con lo strumento Read (una per volta). Il regolamento inglese in testo è in
`/home/claude/src/regole_en.txt` (utile per capire icone e termini).

Scrivi un file JSON (array di oggetti, UTF-8, `ensure_ascii` falso) nel percorso indicato nel compito.
Un oggetto per carta, con questi campi (ometti quelli che non si applicano):

```
{
 "id": 300,
 "titolo_en": "Awful Weather",
 "titolo_it": "Tempo orribile",
 "angolo": "?" | "libro" | "martello" | "ciotola" | ... ,   // icona in alto a destra (vedi sotto)
 "flavor_en": "...", "flavor_it": "...",                     // frase in corsivo
 "testo_en": "Put {pioggia} in the Weather space.",          // testo esatto, icone tra graffe
 "testo_it": "Metti {pioggia} nello spazio Meteo.",
 "segnalino_avventura": "costruire|raccogliere|esplorare|libro", // cerchio al centro delle carte Evento
 "parte2": {                         // metà inferiore (carte Evento: azione di minaccia;
   "titolo_en": "...", "titolo_it": "...",      //  carte Avventura/Mistero: evento che va nel mazzo Eventi)
   "angolo": "...",
   "flavor_en": "...", "flavor_it": "...",
   "richiede_en": "{pedina} {legno}",           // solo Evento: icone sopra il triangolo nero (pedine/risorse/oggetti richiesti)
   "testo_en": "...", "testo_it": "..."
 },
 "minaccia_en": "Put {neve} in the Weather space.",   // solo Evento: fascia in basso (effetto minaccia)
 "minaccia_it": "...",
 "dati": { ... }        // valori numerici o tabelle (belve: forza, arma, cibo, pelliccia; invenzioni: requisiti e costo)
 "note": "dubbi di lettura"
}
```

Traduci in italiano in modo naturale e coerente (stessi termini sempre):
Azione di minaccia, Effetto minaccia, Costruire, Raccogliere risorse, Esplorare, Caccia, Sistemare il campo,
Riposo, Rifugio, Tetto, Palizzata, livello dell'Arma, Morale, Determinazione, ferita, pedina, Personaggio,
Venerdì (Friday), cane, mazzo Eventi, mazzo Misteri, carta Mistero, Belva, segnalino Scoperta, tessera Isola,
Invenzione, Oggetto, «Mescola nel mazzo Eventi», «Pesca un'altra carta», «DECIDI:», «Ogni giocatore…».

## Icone (scrivile così, tra graffe, sia in _en che in _it)

Risorse: `{legno}` tronchetti; `{cibo}` banane/cocco (cibo deperibile); `{cibo_np}` cibo non deperibile
(carne secca/biscotti, cassetta); `{pelliccia}` pelle; `{legno_extra}` / `{cibo_extra}` segnalini «risorsa
aggiuntiva».
Morale e salute: `{det}` segnalino Determinazione (disco con rosa dei venti); `{morale+}` freccia del morale
verso l'alto/destra (punta a destra, guadagnare morale); `{morale-}` freccia verso sinistra (perdere morale) —
guarda bene la direzione della punta; se la freccia è doppia scrivi `{morale-}{morale-}`;
`{ferita}` cuore spezzato (ferita/perdere 1 vita); `{cuore}` cuore intero (vita/guarire).
Ferite speciali sul corpo: `{ferita_testa}`, `{ferita_braccio}`, `{ferita_pancia}`, `{ferita_gamba}`;
segnalini ferita speciale «Costruire/Raccogliere/Esplorare» (gettone con ferita sull'icona d'azione):
`{ferita_costruire}`, `{ferita_raccogliere}`, `{ferita_esplorare}`.
Meteo: `{pioggia}` nuvola di pioggia; `{neve}` nuvola d'inverno/fiocco; `{tempesta}` segnalino tempesta;
`{dado_belve}` dado rosso delle belve/assalto notturno; `{dado_pioggia}`, `{dado_neve}`.
Campo: `{rifugio}`, `{tetto}`, `{palizzata}`, `{arma}` (livello arma), `{campo}` accampamento.
Azioni (icone colorate): `{costruire}` martello marrone, `{raccogliere}` ciotola grigia,
`{esplorare}` icona verde, `{caccia}` rossa, `{sistemare}` tenda blu, `{riposo}` palma gialla.
Segnalini avventura «?»: `{avv_costruire}` (marrone), `{avv_raccogliere}` (grigio), `{avv_esplorare}` (verde).
Altri segnalini: `{rilancio}` (reroll), `{scorciatoia}` (shortcut), `{lento}` (azione che richiede tempo /
time-consuming, clessidra), `{pericolo}` (pericolo maggiore / greater danger), `{segno_bianco}`, `{segno_nero}`
(cubetti/dischi bianco e nero), `{successo_negato}` gettone giallo con il simbolo «Y/V» del successo (da
rilanciare un risultato di successo), `{scoperta}` segnalino Scoperta, `{totem}`.
Dadi d'azione: `{succ}` risultato successo, `{fer}` ferita, `{avv}` «?» avventura.
Pedine: `{pedina}` omino (pedina azione di un personaggio), `{pedina_neutra}`; se è uno specifico personaggio
scrivi `{pedina_cuoco}` ecc.
Carte: `{carta_mistero}`, `{carta_belva}`, `{carta_evento}`, `{carta_avventura}`, `{libro}` (icona libro).
Terreni sulle invenzioni: `{fiume}`, `{spiaggia}`, `{collina}`, `{montagna}`, `{pianura}`, `{foresta}` —
descrivi il disegno se non sei sicuro. Invenzioni o oggetti come requisito: scrivi il nome, es. `{inv:Corda}`
o `{inv:Rope}` in _en.
Personaggi: `{carpentiere}`, `{cuoco}`, `{esploratore}`, `{soldato}`, `{venerdi}`, `{cane}`.
Simbolo «tutti i giocatori»: scrivi «Ogni giocatore».
Icona sconosciuta: `{?:breve descrizione}`.

Angolo in alto a destra (`angolo`): `"?"` bandierina con punto di domanda, `"libro"`, `"mappa"` (mappa con
croce, tipica delle azioni di minaccia), `"martello"`, `"ciotola"`, `"esplora"`, oppure descrivi.

Per le carte Mistero indica in `"dati": {"tipo": "trappola|tesoro|creatura"}` (icona in alto: ciotola con
punte = trappola, scrigno = tesoro, belva = creatura); per le creature aggiungi i valori della belva se ci sono.
Per le Belve: `"dati": {"forza": 6, "arma": -2, "cibo": 3, "pelliccia": 0}` («-» = 0) più eventuale testo.
Per le Invenzioni: `"dati": {"requisiti": ["{inv:Rope}", "{fiume}"], "costo": "1 {pelliccia}", "personale":
"cuoco" se ha il nome di un personaggio}` e in `testo_en` l'effetto. Per gli Oggetti iniziali indica gli usi
(cerchietti) in `dati.usi`.

Sii preciso sui numeri e sulle icone: queste carte verranno programmate in un motore di gioco.
Se qualcosa non si legge, scrivilo in `note`. Non inventare.
