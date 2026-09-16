# MacroPad — macOS konfigurátor

Nativní SwiftUI aplikace pro XIAO/ZMK přes Bluetooth a původní CH552 přes USB.

## Připojení a běžné použití

1. Spusťte MacroPad. Uložené zařízení se připojí a načte automaticky. Při prvním
   použití spárujte pad v Bluetooth nastavení macOS; aplikaci povolte Bluetooth.
2. Na hlavní obrazovce vyberte tlačítko nebo kolečko, upravte jeho akce a podržení
   a klikněte na **Uložit změny**. Aplikace ověří zápis zpětným načtením.
3. V **Nastavení zařízení → Zapojení** přidávejte ovladače a upravujte rozmístění.
   **Připojení** spravuje počítače; **Firmware** aktualizuje zařízení.

Běžné klávesy, média a myš fungují bez spuštěné aplikace. Ztišení mikrofonu a
kruhové menu vyžadují běžící aplikaci. Konfigurace se přenáší přes Bluetooth,
i když pad posílá klávesy přes USB. Při výpadku aplikace návrh zachová; neověřený
zápis nepovažuje za úspěšný. Párování při běžné aktualizaci nemažte.

Nová deska potřebuje jednorázově univerzální firmware přes USB; postup je v
[průvodci sestavením](../docs/learning-wizard.md). Starší zdrojový konfigurátor
CH552 je v repozitáři zachovaný, aktuální hlavní aplikace používá univerzální XIAO.

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

## Vlastní sestavení (0.3.0)

Nová záložka **Vlastní MacroPad** nabízí první flash, naučení tlačítek/encoderů,
volný grid a uložení konfigurace přímo do zařízení. Další Mac načte celé rozložení
bez místních souborů. Podrobný postup a podporované zapojení jsou v
[průvodci sestavením](../docs/learning-wizard.md).

Nastavení zařízení zůstává v jednom okně se třemi částmi:

- **Zapojení**: přidání a odebrání tlačítka nebo kolečka, piny a rozmístění.
  Akce, zkratky a podržení se upravují pouze na hlavní obrazovce.
- **Připojení**: počítače, Bluetooth výstup a stav baterie.
- **Firmware**: jedna aktualizace; s datovým USB připojením je hlavní USB, bez něj Bluetooth. Druhá cesta je vedlejší možnost.

**Uložit změny** uloží konfiguraci a ponechá otevřenou stejnou část nastavení.
Zavření ponechá rozpracované změny v aplikaci; **Zahodit změny** obnoví konfiguraci
načtenou ze zařízení. Přepnutí výstupu a správa Bluetooth zařízení se provádějí ihned.

Build přibaluje `Firmware/macropad-learn.uf2` a jeho manifest. Tento ověřený
obraz je verzovaný záměrně, aby první nahrání fungovalo offline bez přístupu do
soukromého firmware repozitáře.

## Když se pad nepřipojí

Hlavní obrazovka ukazuje stav spojení a umožní připojení bez otevírání nastavení.
Uložený pad se připojuje automaticky; po neúspěšném pokusu aplikace spojení opakuje.
Vypnuté Bluetooth a chybějící oprávnění mají vlastní vysvětlení.

Pokud Mac vidí disk **XIAO-SENSE**, pad běží v instalačním režimu. Aplikace tento
stav rozpozná i u bootloaderu OTAFIX. Pokud právě neprobíhá aktualizace, jeden
stisk RESETu spustí běžný firmware. Bluetooth ani klávesy v instalačním režimu
nefungují. Konfigurace se přenáší přes Bluetooth i při zapojeném USB; USB slouží
pro klávesy, napájení a nahrání firmwaru.

## Kliknutí a podržení · kruhové menu

U tlačítka jsou dvě nezávislá nastavení: **Stisk** a **Podržení tlačítka**.
Krátké kliknutí zachová původní makro. Při zapnutém podržení se krátké makro
provede po puštění; podržení alespoň 350 ms otevře menu a krátké makro se
už neprovede. Vyberte **Kruhové menu** nebo **Přepínání aplikací** a potvrďte
**Uložit změny**. Vyžaduje firmware s podporou menu; starší firmware appka
rozpozná a nabídne aktualizaci v nastavení zařízení.

- Kolečko vybírá položku, puštění drženého tlačítka ji spustí.
- Esc nebo Zavřít nabídku zruší. Po 20 sekundách se zavře bez spuštění akce.
- Vlastní menu obsahuje až 8 akcí: otevření aplikace, sekvenci klávesových
  zkratek nebo spuštění zkratky z aplikace Zkratky podle jejího názvu.
- Přepínání aplikací nabízí běžící aplikace, přednostně nedávno aktivní.
  Více než 8 aplikací se při otáčení zobrazí na dalších stranách.
- **Náhled** umožní prohlédnout menu bez spouštění akcí.
- Odesílání klávesových zkratek vyžaduje oprávnění macOS Zpřístupnění.
- Menu lze přiřadit samostatným tlačítkům i encoderu (firmware 0.3.5+).
  Během menu kolečko neposílá běžné akce hlasitosti. Bez zapnutého menu
  zůstává původní podržení encoderu pro správu Bluetooth.

MacroPad.app musí běžet. Režim podržení a původní krátké makro se ukládají
do zařízení. Položky menu se automaticky ukládají na daném Macu do
`~/Library/Application Support/MacroPad/action-wheels.json`, zvlášť pro
každý pad a stabilní ID tlačítka. Na dalším Macu si vlastní menu nastavte
znovu. HID příkazy přijímá pouze počítač zvolený jako výstup padu.

Ovládání rezervuje ⌃⌥⌘F1–F11 pro otevření, ⇧⌃⌥⌘F1–F11 pro potvrzení,
⌃⌥⌘F12/F13 pro otáčení a ⌃⌥⌘F14 pro zrušení. Nepřiřazujte tyto kombinace
běžným makrům nebo položkám menu. Bez běžící appky zůstává krátké kliknutí
funkční; dlouhé podržení vyžaduje appku.

### Aktualizace firmwaru bez tlačítka RESET (0.3.3)

V **Nastavení zařízení → Firmware** je verze v zařízení a verze
přibalená k aplikaci. Při datovém USB připojení aplikace nabídne USB jako hlavní cestu, jinak Bluetooth. Druhou cestu lze vybrat tlačítkem pod hlavní volbou. Nejdříve uložte rozpracované změny a ukončete učení.
Připojte pad datovým USB kabelem k tomuto Macu a přes Bluetooth v aplikaci.
Klikněte **Aktualizovat přes USB**, počkejte na disk XIAO a pak
**Nahrát firmware přes USB**. Při více discích XIAO vyberte cílovou desku ručně.
Po přenosu aplikace znovu načte konfiguraci a ověří hlášenou verzi firmwaru.
Neobnoví-li se spojení do 45 sekund, oznámí neověřený výsledek; zkontrolujte
připojení a verzi, než nahrávání zopakujete.

Starší firmware včetně 0.3.2 nemá příkaz pro vstup do bootloaderu: pro instalaci
0.3.3 je nutný ještě jeden dvojstisk RESETu. Následující aktualizace ho nepotřebují.
U této volby probíhá příprava bezdrátově a přenos UF2 přes USB. Pro plný Bluetooth
přenos od verze 0.3.4 použijte samostatnou volbu popsanou níže.
Aplikace používá přibalený obraz, nestahuje automaticky nejnovější release.
Univerzální rozložení, makra a párování zůstanou zachované; settings-reset se nepoužívá.

### Plně bezdrátový přenos (0.3.4)

Nový firmware nabízí **Bezdrátová aktualizace · Bluetooth** v nastavení zařízení.
Ze staršího firmwaru je nutné 0.3.4 poprvé nahrát přes USB. Potom lze použít
**Aktualizovat přes Bluetooth**, vybrat svůj XIAO v seznamu DFU zařízení
a potvrdit nahrání. USB ani stisk RESETu pro běžný OTA přenos nejsou potřeba.
Aplikace používá NordicDFU 4.17.0, kontroluje výrobce/model, přenáší pouze obraz
aplikace a po restartu ověřuje verzi i shodu uložené konfigurace.
Při chybě přenosu může být potřeba USB obnova s dvojstiskem RESETu.
Podmínkou je kompatibilní Adafruit/Nordic bootloader a zachovaný S140 SoftDevice;
firmware nabídne OTA pouze při odpovídajících metadatech S140. Metadata sama
nezaručují spolehlivost konkrétní verze bootloaderu; fyzický test je rozhodující.
Starší bootloadery mohou po dokončeném OTA při připojení k USB počítače
vyžadovat jeden RESET pro spuštění aplikace
([popsané omezení](https://github.com/oltaco/Adafruit_nRF52_Bootloader_OTAFIX#recommended-ota-dfu-settings)).
Aplikace bootloader sama nepřepisuje. Po delším čekání na návrat zobrazí
neověřený výsledek a po pozdějším připojení automaticky dokončí kontrolu.

Na zdejším XIAO Sense byl 16. 9. 2026 nainstalován bootloader
**0.9.2-OTAFIX2.3-BP1.4** a následná aktualizace 0.3.4 proběhla na baterii
**bez kabelu a bez RESETu**, včetně automatického návratu a bajtové kontroly
konfigurace. Přenos trval 10 min 25 s. Bootloader se na Macu může stále zobrazovat
pod uloženým názvem `AdaDFU` místo `XIAO_DFU`.
[Protokol fyzického testu](../artifacts/ota-no-reset/battery-test-2026-09-16.md).

### Nabídka zařízení na encoderu (firmware 0.3.5+)

Vyberte encoder → **Podržení encoderu → Zařízení a baterie** → **Uložit změny**.
Krátký stisk zachová původní makro. Podržení 350 ms otevře kruhovou nabídku,
otáčení vybírá a puštění potvrzuje. První položka **Zavřít** nic nemění.

Nabídka obsahuje uložené počítače s jejich názvy a aktuálním výstupem,
přepnutí na USB, procenta a nabíjení baterie MacroPadu, detail baterie,
ztišení/zapnutí mikrofonu tohoto Macu a nastavení MacroPadu. Baterie počítačů
se neměří. Zastaralý stav a odpojení se označí; přepnutí se před odesláním znovu
ověří. Zavření okna konfigurátoru nepřeruší spojení pro nabídku zařízení.

Při zapnutém menu na encoderu se jeho podržení + otáčení ani kombinace
s tlačítky nepoužívá pro původní Bluetooth zkratky. Obnovíte je volbou
**Bluetooth zkratky**. Encoder podporuje i vlastní kruhové menu a přepínání
aplikací. Starší firmware nabídne aktualizaci a nové režimy nepovolí uložit.

### Více připojených Maců

S firmwarem 0.3.6 lze mít připojeno až pět uložených hostů a konfigurovat pad
z kteréhokoli z nich. Výběr **Ovládat** určuje jen příjemce kláves. Panel **Zařízení**
ukazuje podporu automatického předání: nedostupný Bluetooth cíl se při chybějícím
funkčním USB nahradí dalším připojeným profilem po 3 s od zjištění výpadku
(kontrola po 1 s). Návrat starého Bluetooth hosta výběr nepřepne zpět.

Změny se na ostatních appkách načítají po 3 s. Vlastní neuložený návrh zůstane
zachovaný. Při pokusu přepsat mezitím změněnou konfiguraci appka zápis zastaví;
po opětovném načtení zvolte **Zahodit změny** a upravte aktuální verzi. Současné
zápisy se neslučují. Učení/zápis jiného Macu blokuje dalšího zapisovatele do
ukončení relace, odpojení nebo vypršení 15sekundového zámku.
