# MacroPad projekt – kompletní dokumentace (handoff)

Stav k 15. 9. 2026. Vše v této složce vzniklo v jedné session s Claude Code; tento soubor
je určený k předání jinému agentovi / na jiný Mac. **Čti nejdřív tento soubor, pak
`HANDOFF.md`** (přesný stav, co je hotové a co zbývá).

## Cíl projektu
1. Přeprogramovat čínský 3‑klávesový macro pad s encoderem (čip **WCH CH552G**, USB `1189:8890`)
   z Macu – vlastní GUI, protože originální software je jen pro Windows.
2. Přidat funkci **ztišení mikrofonu** (macOS nemá nativní globální mute mikrofonu).
3. Následně pad přestavět na **bezdrátový** – mozek vyměnit za **Seeed XIAO nRF52840** + ZMK.

## Struktura složky
| Složka | Co to je | Stav |
|---|---|---|
| `MacroPadApp/` | **Nativní macOS appka** (SwiftUI, IOKit USB, CoreAudio mute, Carbon hotkey, menubar). Hlavní výstup fáze 1. | hotovo, otestováno |
| `macropad/` | První verze: web UI (`index.html`) + Python backend (`server.py`, libusb) + CLI `macropad.py`. Funkční fallback. | hotovo |
| `zmk-config-macropad/` | ZMK konfigurace pro XIAO nRF52840 (shield `macropad`), git repo s commitem, **ještě nepushnuté na GitHub**. | čeká na push + build |
| `xiao-test/` | Testovací firmware (CircuitPython 9.2.9 + `code.py`), kterým jsme ověřili zapojení tlačítek a encoderu. | použito, hotovo |

## Hardware – původní pad
- PCB: 3× hot‑swap socket (potisk U1, U2, U3; **U3 je hned u encoderu**), encoder EC11, 3× adresovatelná RGB LED
  (D5–D7, WS2812‑2020 typ – **nepoužíváme**, žerou baterii), USB‑C, MCU CH552G (U7).
- Pasivní součástky u U7 a USB (R10, R12 = 10 kΩ; C1, C2, C3 + 1 MLCC) patří jen CH552/USB → po přestavbě mrtvé, nechány na desce.
- Fyzické rozložení v používané orientaci: **encoder vpravo**, klávesy zleva U1, U2, U3.
- ⚠️ Pad **nefungoval přes USB‑C↔C kabel** (jen nabíjecí / bez dat). USB‑A→C funguje.

## Protokol původního padu (CH552G, 1189:8890)
Převzato a ověřeno ze zdrojáků [kriomant/ch57x-keyboard-tool](https://github.com/kriomant/ch57x-keyboard-tool) (`src/keyboard/k8890.rs`).
- Transport: USB interface **1**, interrupt OUT endpoint **0x02**, pakety **64 B**, první byte `0x03`.
  Rozhraní 1 macOS **nevystavuje jako HID** (nemá IN endpoint) → WebHID nejde, nutné libusb/IOKit.
- Před zápisem se posílá jeden nulový 64 B paket (init).
- Sekvence pro jednu klávesu (`layer` 0‑based, `key` ID):
  ```
  03 fe <layer+1> 01 01                                  start
  03 <key> <(layer+1)<<4 | 01> <len> 00 00 00 00 00       prázdný stisk (firmware ho vyžaduje)
  03 <key> <(layer+1)<<4 | 01> <len> <i> <mod> <hid> 00 00   i = 1..len  (max 5 stisků)
  03 aa aa                                               finish
  ```
  Media: `03 <key> <(layer+1)<<4 | 02> <lo> <hi>`; myš: `… | 03 <buttons> <dx> <dy> <wheel>`.
  LED: `03 a1 01`, `03 b0 18 <mode>`, `03 aa a1`.
- Key ID: klávesy 1–3 = `1..3`; knob ccw / press / cw = `13 / 14 / 15`.
- Modifikátory bitově: Ctrl 1, Shift 2, Alt 4, Cmd/Win 8 (pravé ×16).
- **Ověřeno:** zápis z IOKit (Swift), z pyusb i z referenčního toolu prošel bez chyby. Uživatel hlásil, že
  zkratky „nefungují“, ale test byl Ctrl+C v textovém poli (neviditelné). Poslední zapsaný stav před demontáží:
  klávesa 1 = `a`, klávesa 2 = `c`, klávesa 3 = `d`, knob = hlasitost. **Fyzicky nepotvrzeno** – pad byl mezitím rozebrán.

## MacroPadApp (macOS, SwiftUI)
Build: `cd MacroPadApp && ./build.sh` → `dist/MacroPad.app` (ad‑hoc podpis, Xcode CLT stačí; Swift 6.3 toolchain, jazyk Swift 5).
Soubory `Sources/MacroPad/`:
- `Model.swift` – datový model, **protokol** (`PadProtocol.packets`), HID tabulky (macOS keyCode → HID usage), config JSON
  (`~/Library/Application Support/MacroPad/config.json`), rozložení (encoder vlevo/vpravo, pořadí kláves).
- `USBPad.swift` – IOKit: matching `IOUSBHostInterface` přes `IOPropertyMatch {idVendor, idProduct, bInterfaceNumber:1}`,
  `IOUSBInterfaceInterface` → `WritePipe` na OUT pipe. (Pozor: přímé klíče v matching dictu **nefungují**, musí být `IOPropertyMatch`.)
- `KeyRecorder.swift` – nahrávání zkratek přes `NSEvent.addLocalMonitorForEvents`.
- `MicController.swift` – CoreAudio mute default input (property `kAudioDevicePropertyMute`, fallback volume 0/restore),
  globální hotkey `RegisterEventHotKey` (default **F18**, volitelně F19 / ⌃⌥⌘M), HUD overlay (NSPanel), NSLog debug.
- `AppState.swift`, `ContentView.swift`, `MacroPadApp.swift` – UI, menubar (`MenuBarExtra`), launch‑at‑login (`SMAppService`).
Funkce: 3 klávesy + knob (ccw/press/cw), typy Zkratka / Media / Myš / 🎙 Mikrofon, zápis jedné klávesy nebo všeho (⌘S),
LED režim, export/import JSON, náhled fyzického rozložení. Screenshot: `MacroPadApp/screenshot.png`.
Ověřeno: hotkey F18 → toggle mute funguje (osascript `key code 79`); syntetické CGEventy z terminálu chodí nespolehlivě (TCC), to není chyba appky.

## macropad/ (web + Python)
- `server.py` – HTTP na `127.0.0.1:8765`, `GET /api/status`, `POST /api/write {packets:[[..]]}`; pyusb, interface 1, EP 0x02.
- `index.html` – UI (původně WebHID, přepnuto na backend). `macropad.py` – CLI (`key 1 cmd+c`, `media knob-press mute`, `led 1`).
- Závislosti: `brew install libusb && pip3 install --user pyusb` (nainstalováno na pracovním Macu; hidapi nainstalované, ale nepoužitelné).

## Bezdrátová přestavba – XIAO nRF52840 + ZMK
### Zapojení (hotové a **ověřené testovacím FW**)
| Zdroj | XIAO pin | Test |
|---|---|---|
| socket U1 (nejdál od encoderu) | D0 | ✅ |
| socket U2 | D1 | ✅ |
| socket U3 (u encoderu) | D2 | ✅ |
| encoder stisk | D3 | ✅ |
| encoder A / B | D4 / D5 | ✅ směr CW/CCW správně, 2 kroky/cvaknutí, bez ztrát |
| encoder C, druhé nohy spínačů | GND | ✅ |
| LiPo 1S s PCM (500–1000 mAh) | BAT+ / BAT− (zespodu XIAO) | **ještě nezapojeno** |
CH552G odstraněn / odpojen, původní USB‑C a LED nepoužity (LED VDD tím pádem bez napájení – dobře pro baterii).

### ZMK (`zmk-config-macropad/`)
- Board `seeeduino_xiao_ble`, shield `macropad` (kscan direct D0–D3, EC11 D4/D5, `steps=80`, `triggers-per-rotation=20`).
- Keymap: U1 Play/Pause · U2 ⌘C · U3 **F18** (mute mic přes MacroPadApp) · encoder stisk = C_MUTE, držení = vrstva BT
  (U1/U2 = BT profil 0/1, U3 = BT_CLR, otáčení = jas). Otáčení = hlasitost. Sleep 15 min, battery reporting.
- CI: `.github/workflows/build.yml` (ZMK `build-user-config.yml`), `build.yaml` staví i `settings_reset`.
- **Zbývá:** vytvořit GitHub repo, `git remote add origin … && git push -u origin main`, stáhnout artefakt
  `macropad-seeeduino_xiao_ble-zmk.uf2`, flash (2× RESET → disk `XIAO-SENSE` → nahrát UF2), spárovat s Macem.
- Směr encoderu sedí → **neprohazovat** a/b.

### Testovací FW (`xiao-test/`)
Na XIAO je **aktuálně nahraný CircuitPython 9.2.9** s `code.py` (vypisuje stisky a otáčení na sériový port 115200,
`/dev/tty.usbmodem*`). `flash.sh` = hlídač, který po 2× RESET nahraje UF2 a `code.py`.
Poznámka: kopírování UF2 na macOS hlásí `Input/output error`, ale flash proběhne. Softwarový vstup do bootloaderu (1200 baud) nefunguje.

## Nápady do budoucna (diskutováno)
- LED D5–D7 jde řídit z XIAO jedním datovým drátem (`ws2812-spi` v ZMK), ale ~1 mA/LED klidový odběr → vypuštěno.
- Stejný HW s ESP32 + ESPHome = ovladač pro Home Assistant (USB napájení); na baterii radši Zigbee/BLE; e‑ink panel = OpenEPaperLink.
- Bezpečnost baterie v pouzdře: LiPo s PCM, žádné ostré hroty, vůle 1–2 mm, nabíjení 50 mA.
