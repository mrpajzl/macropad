# HANDOFF – přesný stav a další kroky

## Kde co je (po přenosu na jiný Mac)
- Celou složku zkopíruj beze změn. `MacroPadApp/.build` a `MacroPadApp/dist` se dají smazat (regeneruje `./build.sh`).
- `zmk-config-macropad/` je git repo (branch `main`, 1 commit) – zachovej `.git`.

## Stav hardware
- Pad je rozebraný, CH552G odstraněn. XIAO nRF52840 je zapojený na 3 sockety + encoder + GND (viz tabulka v README).
- Na XIAO běží **CircuitPython + testovací code.py** (ne ZMK!). Baterie **ještě není** připojená.

## Další kroky (v pořadí)
1. **Push ZMK repa**: na GitHubu založit prázdné repo, `git remote add origin …`, `git push -u origin main`.
   Actions → artefakt `firmware` → `macropad-seeeduino_xiao_ble-zmk.uf2`.
2. **Flash**: XIAO na USB, 2× RESET → disk `XIAO-SENSE` → `cp *.uf2 /Volumes/XIAO-SENSE/` (I/O error ignorovat).
   Při problémech s párováním nejdřív `settings_reset-…uf2`, pak firmware.
3. **Párování**: Mac → Bluetooth → „MacroPad“. Test: TextEdit / hlasitost / držení encoderu = BT vrstva.
4. **Baterie**: LiPo 1S s ochranou na pady BAT+/BAT− zespodu XIAO, polaritu změřit; nabíjí se USB‑C na XIAO.
5. **Mute mikrofonu**: `MacroPadApp/dist/MacroPad.app` musí běžet (zaškrtnout „Spouštět po přihlášení“);
   U3 posílá F18 → appka přepne mute. Appka jinak s BLE padem nic nedělá (USB část je pro původní CH552 pad).
6. Volitelně: přepsat keymap (`zmk-config-macropad/config/macropad.keymap`), commit, push → nový UF2.

## Otevřené otázky / neověřené věci
- Zápis maker do **původního CH552G padu** byl na USB úrovni úspěšný, ale fyzicky nepotvrzený (pad byl rozebrán dřív).
  Pokud by se to někdy testovalo: očekávaný stav klávesa 1 = `a`, 2 = `c`, 3 = `d`.
- ZMK build ještě nikdy neběžel – při chybě v CI zkontrolovat overlay (kscan direct + matrix-transform) a `west.yml` (`revision: main`).
- Mechanika: umístění XIAO tak, aby USB‑C vykukoval původním otvorem v krabičce (nápad, neprovedeno).

## Prostředí, které bylo potřeba
- Xcode Command Line Tools (Swift 6.3), `brew install libusb hidapi`, `pip3 install --user pyusb hid`.
- Referenční tool: `ch57x-keyboard-tool` v1.7.0 (universal‑apple‑darwin binárka byla v `/tmp`, není součástí projektu).
