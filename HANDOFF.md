# Stav dokončení – 15. 9. 2026

## Repozitáře
- Projekt: https://github.com/mrpajzl/macropad (soukromý).
- Firmware: https://github.com/mrpajzl/zmk-config-macropad (soukromý, submodul).
- Klonovat přes `git clone --recurse-submodules`.

## Ověřeno
- Mac vidí XIAO nRF52840 Sense s CircuitPython 9.2.9 na USB.
- Konzole `/dev/cu.usbmodem1101` odpovídá; testovací program zálohován lokálně
  do ignorované složky `backups/circuitpython`.
- Swift aplikace se sestavuje lokálně; build skript nyní správně propaguje chyby.
- ZMK je připnuté na v0.3.0 a vlastní shield je registrován jako Zephyr modul.
- GitHub Actions staví firmware, settings_reset a samostatně macOS aplikaci.

## Dokončeno
- Oba ZMK buildy včetně `settings_reset` a macOS CI prošly.
- Do XIAO nahrán `macropad-seeeduino_xiao_ble-zmk.uf2` z běhu
  https://github.com/mrpajzl/zmk-config-macropad/actions/runs/35011875367
  (commit `6f17b6a`; následující commit mění pouze README).
- SHA-256 UF2: `2493dc6814416c4a18583cf09d63f48cbe06475ab897ddcc9c574aac2fa6a10f`.
- `hidutil list` potvrzuje USB HID klávesnici MacroPad, VID:PID `1d50:615e`.
- Přechod z CircuitPython do bootloaderu funguje přes konzoli:
  `microcontroller.on_next_reset(microcontroller.RunMode.UF2); microcontroller.reset()`.
  Před resetem odpoj souborový systém CIRCUITPY. Režim BOOTLOADER zde nestačil.
- Kopírování skončilo chybou rozšířených atributů po restartu desky;
  úspěšné nahrání bylo následně potvrzeno novou identitou USB a HID registrací.
- MacroPad.app spuštěna, tlačítkem ověřeno vypnutí a zapnutí mikrofonu.
- Uživatel potvrdil fyzický test: otáčení mění hlasitost, krátký stisk encoderu
  přepíná mute zvuku a U3 přes F18 přepíná mute mikrofonu.
- Hotové UF2 lokálně v `artifacts/complete-firmware/`, build aplikace v
  `MacroPadApp/dist/MacroPad.app` (generované soubory nejsou v Gitu).

## Fyzicky neověřeno
- Bluetooth párování a samostatný test U1 (Play/Pause) / U2 (⌘C).
- Baterie není připojená; mechanické dokončení zůstává na uživateli.
- Historické zápisy do CH552 nebyly potvrzené fyzickým stiskem.

Původní stav před dokončením: [archiv předání](docs/HANDOFF-ORIGINAL.md).
