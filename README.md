# Robinson Crusoe — versione digitale

Versione digitale amatoriale di **Robinson Crusoe: Avventure sull'isola maledetta** (Ignacy Trzewiczek,
Portal Games) per la ludoteca: un cooperativo di sopravvivenza in cui i naufraghi esplorano l'isola,
cacciano, costruiscono rifugio e invenzioni e resistono a eventi, belve e maltempo fino a raggiungere
l'obiettivo dello scenario.

Si gioca nel browser: https://tannoiser2.github.io/Robinson-Crusoe/

## Che cosa c'è

- **Regole complete del gioco base** (edizione Portal 2016): le sei fasi del round, minacce e relitti,
  caccia e combattimenti, costruzioni (rifugio, tetto, palizzata, arma, invenzioni e invenzioni
  personali), raccolta, esplorazione con distanze, nebbia e gettoni, i tre dadi d'azione con le facce del
  modulo, avventure e misteri che tornano dal mazzo Eventi, meteo (pioggia, inverno, belve, tempesta),
  notte (fame, rifugio, cibo che va a male, spostamento del campo), ferite con le frecce del morale,
  ferite speciali, richieste non soddisfatte, notte fuori dal campo.
- **I sei scenari**: Naufraghi (pira e fuoco), L'isola maledetta (croci e nebbia), Jenny ha bisogno
  d'aiuto, L'isola del vulcano (lava, cenere, luoghi dei totem), L'isola dei cannibali (villaggi e città),
  La famiglia Robinson (le 9 invenzioni e i figli), con libro, totem, segnalini Scoperta speciali e
  invenzioni di ogni scenario.
- **Tutte le carte programmate**: 71 eventi, 90 avventure, 52 misteri, 16 belve, 42 invenzioni,
  8 oggetti iniziali, 3 relitti; le abilità dei quattro naufraghi, Venerdì e il cane.
- **Compagni IA** per i naufraghi liberi, **hotseat** e **partite online** con gli amici
  (Firebase, radice `robinson/rooms`, coperta dalla regola comune dei giochi).
- **Tabellone originale** con la mappa dell'isola e le tessere, e **tavolo 3D** con il tabellone, le
  tessere in rilievo, le pedine originali (i gettoni con i ritratti), le carte, i modelli delle risorse e
  le plance dei naufraghi.
- Testi delle carte **in italiano** (passa il mouse su una carta): le immagini sono per ora quelle inglesi
  del modulo TTS e verranno sostituite dalle scansioni dell'edizione italiana.

## Struttura

- `tools/trascrizioni/*.json` — trascrizione di tutte le carte (inglese e italiano) dalle immagini.
- `tools/effetti.py` — gli effetti programmati di ogni carta; `tools/compila_dati.py` crea `data/*.json`
  (carte, tessere, scenari, personaggi, segnalini Scoperta).
- `tools/catalogo.py`, `tools/estrai_materiale.py` — estraggono dal modulo TTS immagini e modelli in `assets/`.
- `scripts/core/` — il motore delle regole (`motore.gd`, `effetti.gd`, `azioni.gd`, `scenari.gd`),
  deterministico: stesso seme e stesse scelte, stessa partita (anche online); `ia.gd` per i compagni IA.
- `scripts/ui/` — menu, partita, mappa dell'isola, tavolo 3D, regole.
- `scripts/net/` — gioco online in lockstep su Firebase.

## Prove

```
godot --headless --path . -s tests/sim.gd -- 60              # 60 partite solo IA su tutti gli scenari
xvfb-run godot --path . -s tests/vivo.gd -- /tmp/vivo 3d 2 3  # partita con l'interfaccia + schermate
python3 tools/controlla_glifi.py                               # nessun carattere mancante nei font
python3 tests/firebase_mock.py 8765                            # finto Firebase per tests/online_play.gd
```

## Pubblicazione

Il workflow `Pubblica` parte solo a mano (Actions → Pubblica → Run workflow) oppure con un commit su
`main` il cui messaggio contiene `[pubblica]`. Pubblica su GitHub Pages e, se ci sono i segreti
`CLOUDFLARE_API_TOKEN` e `CLOUDFLARE_ACCOUNT_ID`, sulla ludoteca privata
(`robinson-crusoe.ludoteca-digitale.com`).

## Materiale

Immagini e modelli dal modulo Tabletop Simulator «Robinson Crusoe - Scripted Setup». Font: IM Fell English
SC, Alegreya e Caveat (SIL Open Font License). Uso personale e non commerciale.
