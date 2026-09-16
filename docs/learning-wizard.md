# MacroPad Studio: první sestavení a přenos mezi Macy

Appka má jedinou hlavní obrazovku pro MacroPad s univerzálním firmwarem.

Hlavní obrazovka obsahuje kompaktní náhled zařízení a vedle něj editor zkratek
vybraného prvku. Náhled zachovává polohy prvků, zobrazuje klávesy s jejich akcemi
a kulaté encodery. Prázdné okraje mřížky se nezobrazují.
Změny akcí uložíte tlačítkem **Uložit změny**.
**Nastavení zařízení** otevře jediné okno s částmi **Zapojení**, **Připojení**
a **Firmware**. V Zapojení přidáte prvky a upravíte jejich rozmístění. Akce upravíte na hlavní obrazovce.
Uložení ponechá stejnou část otevřenou a ověří zápis načtením ze zařízení.
Zavření bez uložení ponechá návrh v appce a ukončí poznávání, takže běžná
makra zase fungují. **Zahodit změny** obnoví konfiguraci načtenou z MacroPadu.

## První zapojení

Podporovaná deska je Seeed XIAO nRF52840 / Sense. Tlačítka připojujte mezi
jeden z D0–D10 a GND. Encoder se spínačem potřebuje tři různé piny: A, B a
stisk; společné kontakty patří na GND. Piny se nesmí sdílet. V tomto vydání
nejsou podporované matice, expandéry, signály z jiných napájených modulů ani
encodery bez tlačítka. Dekódování encoderu počítá se čtyřmi změnami na krok,
stejně jako u původního prototypu.

1. Připojte desku datovým USB a dvakrát stiskněte RESET.
2. V **Firmware** vyberte disk XIAO
   a **Nahrát firmware**. Appka obsahuje
   ověřený univerzální obraz; není potřeba GitHub, kompilátor ani internet.
3. Deska se restartuje. Spárujte MacroPad v Bluetooth macOS. Část **Připojení** nabízí
   vyhledání/připojení a automatické načtení. Při více padech zvolte správný.
4. V **Zapojení** klikněte na **Přidat ovladač** a vyberte tlačítko nebo encoder. Po stisku a uvolnění
   klikněte na **Potvrdit stisk**. U encoderu následně otočte alespoň dva kroky
   doprava a potvrďte, poté doleva a potvrďte. Appka odvodí piny i směr.
   Pokud chybí vzorek nebo se hýbe více ovladači, pokus odmítne a lze ho opakovat.
5. Přidejte další ovladače. V **Upravit rozmístění ovladačů** přetahujte prvky;
   obsazené pozice se vymění. Volby řádku/sloupce jsou v **Zapojení a pozice**. Každý encoder má stisk/doleva/doprava.
   Tlačítka jsou zpočátku bez akce; zkratky, média, myš či mikrofon jim přiřaďte
   po zavření nastavení na hlavní obrazovce.
6. **Uložit změny** nahraje celou konfiguraci, atomicky ji
   uloží do paměti desky a znovu načte pro ověření. Univerzální firmware už
   běží; podle rozložení se nekompiluje ani znovu neflashuje. Uložení si samo
   vyžádá režim pro zápis; není nutné předem zapínat poznávání.

Během učení se nové běžné akce neposílají. Zrušení, odpojení nebo vypršení
15sekundového pronájmu vrátí původní provoz. Změny se aktivují až úspěšným
závěrečným uložením. Předchozí konfigurace přežije nedokončený přenos.

## Další počítač

Zapojení, stabilní ID prvků, pozice v gridu a všechny akce jsou **v zařízení**.
Lokální JSON ani původní Mac nejsou potřeba. Na druhém Macu nainstalujte tuto
appku a spárujte MacroPad. Jediný již připojený MacroPad se načte automaticky;
při více zařízeních ho vyberte. Další připojení si appka pamatuje. Čtení konfigurace
samo nezapíná režim učení a neblokuje běžné použití.

Mikrofon používá F18 a vyžaduje běžící MacroPad.app na cílovém počítači.
Samotné klávesy, média a myš fungují jako HID bez appky.

První naučený encoder držený společně s prvním/druhým tlačítkem podle ID vybírá
Bluetooth profil 0/1. Podržení tohoto encoderu a otočení přepíná všechny profily.
Od 0.3.0-rc3 si první nastavení bez naučených ovladačů vybere volný profil
i tehdy, když se k obsazenému profilu automaticky připojí původní Mac. Volbu si uloží i pro restart před dokončením
průvodce; stávající párování nemaže. Jsou-li všechny profily obsazené, automaticky
se nic nemaže. Původní nechtěně spustitelná kombinace pro mazání párování
v univerzální variantě není. Základní firmware nemaže existující párování.

## Technické ověření a omezení

- Testy Swift ověřují formát, kontrolní součet, mapování, stabilní ID při výměně
  buněk, zákmity, opačné směry a nejednoznačné/chybějící vzorky.
- C testy validují konfiguraci, konflikty pinů/buněk a poškození dat.
- CI sestavuje obě varianty firmwaru i univerzální macOS aplikaci.
- Fyzické učení, přenos BLE a načtení na druhém Macu vyžadují ruční zkoušku.
- Skenování v1 běží po 1 ms a hluboký spánek je vypnutý; výdrž baterie této
  varianty nebyla změřena. Je to prototyp pro ověření průvodce a zapojení.

Protokol: `zmk-config-macropad/docs/learning-protocol.md`.
Provenience přibaleného firmware: `MacroPadApp/Firmware/firmware.json`.

## Živé zvýraznění v gridu

Při připojené appce stisk fyzického tlačítka nebo encoderu rozsvítí odpovídající
buňku zeleně. Držený stisk zůstane zvýrazněný; krátký stisk je vidět alespoň
0,3 sekundy. Otočení encoderu krátce zobrazí šipku směru. Zpětná vazba sleduje
ID prvku, takže funguje i po přesunutí v gridu a s rozpracovaným rozložením.

Od firmware 0.3.0-rc5 appka dostává stav pinů i mimo režim učení. Samotné
zobrazení gridu tedy nevypíná makra ani nezapisuje konfiguraci. Při odpojení
nebo výpadku vzorků zvýraznění zhasne. Vyžaduje aktuální appku i firmware.
