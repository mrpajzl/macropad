# MacroPad

Tři klávesy a otočný encoder EC11, přestavěné na **Seeed XIAO nRF52840**.
Firmware ZMK funguje přes USB i Bluetooth; macOS aplikace zapisuje makra bezdrátově a zajišťuje ztišení mikrofonu.

## Výchozí ovládání

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
| Všechny tři klávesy současně | Odemknout bezdrátový zápis na 60 sekund |

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
fungují samostatně.

### Bezdrátová změna maker

Po jednorázovém nahrání firmwaru v0.2 přes USB spáruj MacroPad s Macem.
V appce vyber **XIAO · Bluetooth → Najít MacroPad → Připojit a načíst**.
Uprav klávesy a kolečko, stiskni všechny tři klávesy současně a do 60 sekund
klikni **Zapsat do padu**. Appka ověří uložené hodnoty zpětným čtením.
Nastavení zůstává v padu po restartu. Podržení kolečka pro správu Bluetooth je pevné.
Původní CH552 konfigurátor zůstává dostupný pod **CH552 · USB**.
Podrobnosti: [návod appky](MacroPadApp/README.md).

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

## Úsporný režim

Od firmwaru v0.2.0-rc3 pad po 30 sekundách přechází do režimu idle se zachovaným
Bluetooth spojením. Automatický hluboký spánek po 15 minutách je vypnutý,
aby první stisk nemusel čekat na opětovné připojení. Klidová spotřeba je proto
vyšší než dříve; přesná výdrž na baterii zatím není změřená.
Pro aktualizaci stačí hlavní UF2, bez resetu párování nebo maker.

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

- `MacroPadApp/`: SwiftUI aplikace, bezdrátový konfigurátor XIAO, mikrofon a USB konfigurátor CH552.
- `zmk-config-macropad/`: ZMK v0.3.0, zapojení a keymap.
- `macropad/`: původní Python CLI a webový konfigurátor CH552.
- `xiao-test/`: CircuitPython test zapojení a obnovovací firmware.
- [HANDOFF.md](HANDOFF.md): poslední ověřený stav.
- [Historie projektu](docs/PROJECT-HISTORY.md): původní technické poznámky před dokončením.

Dokumentace: [ZMK encodery](https://zmk.dev/docs/hardware-integration/encoders),
[ZMK moduly](https://zmk.dev/docs/development/module-creation).

### Průvodce vlastním sestavením (0.3.0)

Appka umí naučit přímo zapojená tlačítka a encodery XIAO, rozmístit je v gridu
a uložit rozložení i akce do zařízení. Na jiném Macu se konfigurace načte sama.
Viz [postup prvního nahrání a učení](docs/learning-wizard.md).

### Stav baterie a nabíjení

Kliknutím na baterii v horní liště otevřete panel energie: odhad procent,
stav nabíjení z /CHG nabíječky XIAO, napětí, graf aktuálního režimu (nejvýše
hodina), aktivní Bluetooth profil, dobu od zapnutí a RSSI. Aplikace čte stav
po 30 sekundách; firmware měří napětí po 60 sekundách. Starší firmware může
poskytovat pouze procenta přes standardní Bluetooth Battery Service.

Rychlost je odhad v **procentních bodech za hodinu**, nikoli proud v mA.
Zobrazuje se po alespoň 15 minutách souvislého měření a změně o 2 body.
Historie je dočasná, v paměti aplikace; při změně režimu, restartu zařízení
nebo přerušení měření se trend resetuje. Zastaralé údaje se neprezentují jako
aktuální. XIAO nemá v tomto zapojení měření proudu ani přesný fuel gauge;
napěťový odhad procent může při nabíjení kolísat. Zhasnutá kontrolka CHG
znamená, že nabíjení neprobíhá, nikoli nutně plnou baterii.

### Uložené počítače a Bluetooth

Tlačítko **Zařízení** otevírá správu uložených hostů. Seznam se načítá z MacroPadu
včetně názvů a označení **Tento Mac** podle identity aktuálního BLE spojení.
**Ovládat** přepne cílový Bluetooth profil; **Použít USB** změní preferovaný výstup.
Panel vždy ukazuje skutečný výstup, který se může při nedostupném preferovaném
zařízení dočasně přepnout na jiný transport. Připojení konfigurační aplikace není
totéž jako příjem kláves; více Maců může zůstat současně připojených.

**Přidat nové zařízení** vybere volný slot a spustí 120sekundové párování. Na novém
počítači pak vyberte MacroPad v nastavení Bluetooth. Zrušení nebo vypršení okna
vrátí předchozí profil; návrat funguje i po restartu uprostřed párování. Uložený Mac znovu nepárujte, pouze jej zvolte v seznamu.
Názvy jsou uložené v zařízení a svázané s identitou hosta. Více slotů se stejnou
Bluetooth identitou se zobrazuje jako jedna položka s vysvětlením duplicity;
žádné párovací klíče se tím nemažou. Odlišné identity se automaticky neslučují.
