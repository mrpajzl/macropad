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

## Právě probíhá
- První ověření ZMK přes GitHub Actions a flash připojené desky.

## Fyzicky neověřeno
- Reálné stisky s novým ZMK firmwarem a Bluetooth párování.
- Baterie není připojená; mechanické dokončení zůstává na uživateli.
- Historické zápisy do CH552 nebyly potvrzené fyzickým stiskem.

Původní stav před dokončením: [archiv předání](docs/HANDOFF-ORIGINAL.md).
