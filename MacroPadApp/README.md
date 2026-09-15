# MacroPad – konfigurátor pro CH552G macro pad (1189:8890)

Nativní macOS appka (SwiftUI). Zapisuje makra do padu přes USB (IOKit) a navíc
umí **ztišení mikrofonu**: pad pošle klávesu F18, appka ji zachytí (globální hotkey,
bez oprávnění Přístupnost) a přepne mute na výchozím vstupu (CoreAudio). Stav je vidět
v menu baru, při přepnutí se zobrazí HUD.

## Build
    ./build.sh          # → dist/MacroPad.app  (vyžaduje Xcode Command Line Tools)
    open dist/MacroPad.app

## Použití
1. Připoj pad **datovým** USB kabelem (některé USB‑C↔C kabely jsou jen nabíjecí).
2. U každé klávesy / směru knobu vyber typ: Zkratka (nahraj stiskem), Media, Myš, 🎙 Mikrofon.
3. **Zapsat do padu** (⌘S). Konfigurace se ukládá do
   `~/Library/Application Support/MacroPad/config.json` (Export/Import v toolbaru).
4. Pro mute mikrofonu musí appka běžet – zaškrtni „Spouštět po přihlášení“.

## Protokol
Stejný jako [ch57x-keyboard-tool](https://github.com/kriomant/ch57x-keyboard-tool) (model 0x8890):
64‑bajtové interrupt pakety na interface 1 / EP 0x02:
`03 fe <layer> 01 01` → `03 <key> <layer<<4|typ> …` → `03 aa aa`.
Klávesy 1–3 = ID 1–3, knob ← / stisk / → = ID 13 / 14 / 15.

## Alternativy v repu
- `../macropad/` – webové UI + Python backend (libusb) a CLI `macropad.py`.
