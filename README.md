# MacroPad

Tři klávesy a otočný encoder EC11, přestavěné na **Seeed XIAO nRF52840**.
Firmware ZMK funguje přes USB i Bluetooth; macOS aplikace zajišťuje ztišení mikrofonu.

## Ovládání

Při pohledu s encoderem vpravo:

| Ovladač | Funkce |
|---|---|
| Levá klávesa U1 | Play / Pause |
| Prostřední U2 | ⌘C |
| Pravá U3 | F18 → ztišení mikrofonu přes MacroPad.app |
| Otočení | Hlasitost |
| Krátký stisk encoderu | Ztišení zvuku |
| Držení encoderu + U1 / U2 | Bluetooth profil 0 / 1 |
| Držení encoderu + U3 | Vymazat párování aktivního profilu |
| Držení encoderu + otočení | Jas |

Hotové soubory: [releases projektu](https://github.com/mrpajzl/macropad/releases).

## Spuštění na Macu

```sh
git clone --recurse-submodules https://github.com/mrpajzl/macropad.git
cd macropad/MacroPadApp
./build.sh
open dist/MacroPad.app
```

Vyžaduje macOS 13+ a Xcode Command Line Tools. Aplikace musí běžet pro F18 mute;
automatické spouštění lze zapnout v jejím nastavení. USB/Bluetooth klávesy a hlasitost
fungují samostatně. Konfigurátor maker v aplikaci patří původnímu CH552 padu;
mapování XIAO se mění v ZMK keymap a přehráním firmwaru.

## Firmware

[Samostatný repozitář ZMK](https://github.com/mrpajzl/zmk-config-macropad) je zde jako
submodul `zmk-config-macropad`. GitHub Actions sestavuje firmware i reset nastavení.

```sh
gh run list -R mrpajzl/zmk-config-macropad --workflow build.yml
# Zvol úspěšný běh odpovídající požadovanému commitu:
gh run download RUN_ID -R mrpajzl/zmk-config-macropad -n firmware -D artifacts/firmware
```

2× rychle stiskni RESET na XIAO. Na disk `XIAO-SENSE` zkopíruj
`macropad-seeeduino_xiao_ble-zmk.uf2`. Disk po flashnutí zmizí a zařízení se přihlásí
jako USB klávesnice. Případnou chybu kopírování nelze samotnou považovat za úspěch:
ověř přihlášení zařízení a funkci kláves. `settings_reset` používej pouze při potřebě
smazat uložená nastavení; následně znovu nahraj hlavní firmware.

Pro Bluetooth otevři nastavení Bluetooth na Macu a připoj „MacroPad“.
Při připojeném datovém USB má ZMK standardně přednostně USB výstup.

## Zapojení

| Součást | XIAO |
|---|---|
| U1 / U2 / U3 | D0 / D1 / D2 |
| Stisk encoderu | D3 |
| Encoder A / B | D4 / D5 |
| Společné kontakty | GND |

Směr A/B byl ověřen při stavbě; nepřehazovat. Původní CH552 a RGB LED se nepoužívají.
Baterie zatím není připojena, zařízení je napájeno přes USB-C.

## Obsah

- `MacroPadApp/`: SwiftUI aplikace, mikrofon a původní USB konfigurátor.
- `zmk-config-macropad/`: ZMK v0.3.0, zapojení a keymap.
- `macropad/`: původní Python CLI a webový konfigurátor CH552.
- `xiao-test/`: CircuitPython test zapojení a obnovovací firmware.
- [HANDOFF.md](HANDOFF.md): poslední ověřený stav.
- [Historie projektu](docs/PROJECT-HISTORY.md): původní technické poznámky před dokončením.

Dokumentace: [ZMK encodery](https://zmk.dev/docs/hardware-integration/encoders),
[ZMK moduly](https://zmk.dev/docs/development/module-creation).
