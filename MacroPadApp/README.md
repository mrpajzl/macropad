# MacroPad — macOS konfigurátor

Nativní SwiftUI aplikace pro XIAO/ZMK přes Bluetooth a původní CH552 přes USB.

## XIAO přes Bluetooth

1. Jednou nahraj firmware s podporou konfigurátoru přes USB. Dvakrát rychle
   stiskni RESET na XIAO a zkopíruj nový `macropad-…-zmk.uf2` na bootloader disk.
2. Spáruj **MacroPad** s Macem v Nastavení systému → Bluetooth.
3. Spusť appku, zvol **XIAO · Bluetooth**, klikni **Najít MacroPad** a potom
   **Připojit a načíst**. Povol macOS přístup aplikace k Bluetooth.
4. Změň klávesy, stisk nebo směry kolečka. Podporované jsou sekvence až pěti
   zkratek, mediální klávesy, kliknutí/scroll myši a mute mikrofonu.
5. Současně stiskni všechny tři klávesy na padu. Do 60 sekund klikni
   **Zapsat do padu** (⌘S), případně šipku u jedné klávesy.
6. Appka čeká na uložení a zpětným čtením ověří hodnoty. Makra fungují i po restartu
   a bez appky; mute mikrofonu potřebuje appku spuštěnou v liště.

Konfigurátor upravuje základní vrstvu. Podržení kolečka a BT vrstva zůstávají
pevné, aby bylo vždy možné přepnout profil nebo vymazat párování.
Pokud zápis vypadne, některé položky již mohou být uložené: načti pad znovu.
Pokud se po aktualizaci neobjeví služba, zapomeň MacroPad v macOS a znovu jej spáruj.
USB může dál napájet pad; konfigurační spojení je Bluetooth i při USB HID výstupu.

## Původní CH552

Zvol **CH552 · USB**, připoj datový kabel a použij původní zápis maker a LED.
Konfigurace jsou oddělené: `~/Library/Application Support/MacroPad/config.json`
a `config-xiao.json`. Export/import pracuje s právě zvoleným zařízením.

## Build a test

```sh
swift test
./build.sh
open dist/MacroPad.app
```

macOS 13+, Xcode Command Line Tools. Protokol BLE je popsán v
[`../zmk-config-macropad/docs/ble-protocol.md`](../zmk-config-macropad/docs/ble-protocol.md).

## Automatické sestavení na GitHubu

Workflow **Build macOS app** se spouští při každém pushi, pull requestu a ručně
přes **Actions → Build macOS app → Run workflow**. Spustí testy, sestaví jednu
univerzální appku pro Apple Silicon a Intel, ověří obě architektury i podpis
balíčku a uloží ZIP a SHA-256 součet do artefaktu **MacroPad-macOS-universal**.
Odkaz na stažení je v souhrnu běhu; artefakt se uchovává 30 dní.

Při pushi tagu `vMAJOR.MINOR.PATCH` (volitelně s příponou) se úspěšně sestavený ZIP automaticky přiloží ke GitHub Release.
Pokud release neexistuje, pipeline jej vytvoří. Tag s pomlčkou (např. `v0.2.0-rc2`)
vytvoří předběžnou verzi. Verze v appce se nastaví podle tagu. Existující přílohy firmwaru zůstávají zachované.
Appka je podepsaná ad-hoc, bez Apple Developer certifikátu a notarizace.

Stejný univerzální build lokálně:

```sh
./build.sh --arch arm64 --arch x86_64
```
