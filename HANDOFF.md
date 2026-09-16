# Finální kontrola a vydání 0.3.6 — 16. 9. 2026

- Uživatel výslovně schválil aplikaci, pad i GitHub release; potvrdil uložení a
  ukončení aplikace. Živý pad UŽ běží na 0.3.6-multihost (novější než staré poznámky),
  wheel v2, 4 ovladače, 2 uložené Macy, baterie 88 %. Proto znovu neflashovat.
- Čtení a reconnect v 20:29 UTC ověřily bajtově stejný config, záloha a log
  artifacts/release-0.3.6/{current-config.bin,preflight.log}. Starší baseline z OTA
  0.3.4 NEOBNOVOVAT — konfigurace se mezitím legitimně změnila.
- Opraveno otevření Nastavení z menu, obnova draftu při znovuotevření okna,
  auto-reconnect po neúspěšném vstupu do bootloaderu a volba obnovy po timeoutu.
- 39 Swift testů, 4 C testy a universal build prošly. Firmware sjednocen/pushnut
  na main 8683a62, C CI 35146617753 úspěšné. Přibalený FW přesně odpovídá
  dřívějšímu úspěšnému build 35135692083; nový main build 35146618374 běží.
- Podrobný audit a omezení: docs/release-0.3.6-verification.md. Závěrečné GitHub CI,
  instalace aplikace a publikace release následují; neoznačovat je předčasně hotové.

---

# Akce pouze na hlavní obrazovce — 16. 9. 2026

- Uživatel nechce úpravy akcí v nastavení zařízení. Sekce přejmenována na Zapojení;
  nabízí pouze přidání/odebrání prvků, piny, pozice a rozmístění. Náhled zde ukazuje
  fyzické prvky bez ikon/zkratek akcí. ControlActionsEditor a WheelEditor pouze
  na hlavní obrazovce, režim explicitní (nezávisí na otevření sheetu).
- Univerzální arm64+x86_64 build a podpis prošly, diff check čistý. Instalováno
  /Applications/MacroPad.app; záloha artifacts/before-hardware-only-settings/MacroPad.app.
  Běžící aplikaci je třeba ukončit a spustit. Firmware ani konfigurace neměněny.

---

# Jedna aktualizace, automatická volba USB/Bluetooth — 16. 9. 2026

- Podle výslovné preference uživatele: lokálně připojené datové USB nebo XIAO
  bootloader disk → hlavní USB; bez nich → Bluetooth. Jedna karta, druhá metoda
  přes vedlejší tlačítko. Manuální volba a zahájený postup se při restartu padu nepřepnou.
- FirmwareConnection přes IOKit ověřuje MacroPad product name + VID/PID 1d50:615e;
  samotné napájení/nabíječka USB cestu nevyvolá. Bootloader detekuje FirmwareInstaller.
- USB příprava a nahrání se zobrazují postupně; verze se neduplikují. Zachované
  kontroly obrazu, potvrzení zápisu, výběr při více discích a kontrola návratu FW.
- 39 testů prošlo, univerzální build prošel. Read-only harness ověřil živou USB
  detekci a načetl FW 0.3.4-ota; render obou voleb zkontrolován:
  artifacts/smart-update/{usb,bluetooth}.png. Žádný firmware nebyl nahrán.
- Instalováno /Applications/MacroPad.app, předchozí bundle v
  artifacts/before-smart-update/MacroPad.app. Běžící appku uživatel znovu spustí.

---

# Oprava připojení — 16. 9. 2026

- Příčina hlášeného výpadku: pad v USB bootloaderu, disk XIAO-SENSE,
  Board-ID nRF52840-SeeedXiaoSense-v1. Původní detekce přijímala pouze starší ID.
- Uživatel provedl jeden RESET: disk zmizel, ioreg hlásí USB MacroPad 1d50:615e,
  system_profiler potvrzuje Bluetooth Connected. FW zůstává 0.3.4-ota.
- FirmwareInstaller detekuje přesná stará i OTAFIX XIAO ID; regresní test odmítá
  cizí desky a podobné názvy. LearningPad při chybě uvolní peripheral a naplánuje
  další pokus (nespoléhá na disconnect callback); pamatuje poslední vybraný cíl.
  Opakované start nezmění stav již připojeného zařízení. Rozlišení BT oprávnění/vypnutí.
- Hlavní obrazovka nabízí stav a připojení inline, detekuje instalační režim i mimo
  Firmware a uvádí konkrétní další krok. Ukládání se při připojování netváří jako zápis.
- 38 testů a univerzální build prošly. Nový LearningPad fyzicky načetl 4 ovladače,
  FW 0.3.4-ota a po odpojení klienta opět načetl tentýž pad bez RESETu či zápisu.
  Log artifacts/connection-fix/read-and-reconnect.log. Test pouze čtení, žádný flash.
- Opravená aplikace instalována /Applications/MacroPad.app; předchozí bundle je
  artifacts/before-connection-fix/MacroPad.app. Běžící starý proces nebyl násilně
  ukončen kvůli možným rozpracovaným změnám. Uživatel musí aplikaci znovu spustit.
- CUA stále hlásí native pipe closed; nelze tvrdit ověření klikáním v nové aplikaci.

---

# Zjednodušené nastavení aplikace — 16. 9. 2026

- HardwareWorkspace: jeden panel Ovládání / Připojení / Firmware, bez krokového
  průvodce a automatického zavírání po uložení. Přidání, akce a rozmístění pohromadě.
- HostManagerView vložen přímo do Připojení; samostatní volající zachovaní.
  Bluetooth OTA hlavní volba, USB instalace/obnova ve sbalitelných podrobnostech.
- 37 Swift testů prošlo; univerzální arm64+x86_64 build a podpis prošly.
  Instalováno /Applications/MacroPad.app. Původní bundle uložen v
  artifacts/before-settings-simplification/MacroPad.app.
- Před instalací v živé appce ověřeno, že nejsou neuložené změny. CUA po výměně
  bundle selhalo „native pipe closed“; klikání v nové verzi nebylo dokončeno.
  Může stále běžet původní proces: pro nové UI aplikaci ukončit a znovu spustit.
- Všechny tři části vizuálně ověřeny offscreen SwiftUI renderem se vzorovými daty:
  artifacts/settings-simplification/section-{0,1,2}.png. Nejde o živý stav padu.
- Tento úkol neměnil firmware ani konfiguraci fyzického padu. Předchozí OTA
  ověření níže zůstává platné; souběžné firmware změny ponechány beze změn.

---

# HOTOVO — Bluetooth OTA NA BATERII bez kabelu a bez RESETu

- 16. 9. 2026 fyzicky ÚSPĚŠNĚ ověřeno. Žádný OTA proces už neběží.
- XIAO Sense má bootloader 0.9.2-OTAFIX2.3-BP1.4, S140 7.3.0 zachovaný,
  aplikační FW 0.3.4-ota. Souběžné 0.3.5/0.3.6 nebyly při tomto testu nahrávány.
- Před testem uživatel dokončil instalaci jedním RESETem; během samotného
  OTA přenosu ani návratu nebyl kabel ani RESET. Před/po potvrzen battery mode.
- Přenos 19:18:55–19:29:20 UTC (10 min 25 s), validace přijata. Pad se sám
  vrátil, původní identita a 4 ovladače načteny, VERIFIED BATTERY OTA v 19:29:27.
- FW 0.3.4 ověřen, config 496 B bajtově shodný s předinstalační baseline,
  hash e8cf11da861249dd972ea60ed2ce8b1927bcebd1ccc7438b83e5af8a204f59d9.
  Baterie před 89 % / 4112 mV, po 86 % / 4094 mV.
- Trvalý protokol: artifacts/ota-no-reset/battery-test-2026-09-16.md,
  logy battery-preflight.log a battery-transfer.log ve stejné složce.
- Test reálných app tříd v izolovaném harnessu. macOS ponechal cached jméno
  AdaDFU; cílen pouze známý XIAO a ověřen DIS, Omi DIY ignorován.
- Nyní lze uživateli potvrdit běžné bezdrátové aktualizace bez RESETu na tomto
  padu. Jednorázové zavedení bootloaderu vyžadovalo USB. Nový bootloader nebyl
  zvlášť testován s USB připojeným; úspěšný finální test splňuje cíl bez kabelu.
- Následující sekce jsou HISTORIE předchozích kroků, nikoliv aktivní blokace.

---

# AKTIVNÍ BATERIOVÝ OTA TEST — NEFLASHOVAT z jiného vlákna

- Uživatel dokončil jednorázový start po instalaci bootloaderu jedním RESETem.
- 19:18:11 UTC ověřeno bateriové napájení 89 % / 4112 mV, 0.3.4-ota,
  původní identita a bajtově shodná konfigurace. Potom BLE OTA reboot přijat.
- macOS stále vrací cached CBPeripheral.name AdaDFU, nikoliv XIAO_DFU;
  první scanner odmítl zápis kvůli názvu. Bez resetu navázal nový harness,
  vybral pouze známou DFU identitu CF7CBC3D-F7B1-AC41-3643-F30FECC91EEB
  a ověřil DIS Seeed XIAO. Omi DIY ignorován.
- SKUTEČNÝ PŘENOS běží od 19:18:55 UTC. PID 39864,
  /tmp/MacroPadBatteryOTA.app/Contents/MacOS/MacroPadOTATest,
  log /tmp/macropad-battery-ota3.log. Předchozí preflight /tmp/macropad-battery-ota2.log.
- Kabel je fyzicky odpojený, potvrzeno uživatelem i firmwarem. Další RESET
  se od začátku testu neprováděl. Na konci harness musí ověřit automatický
  návrat do 0.3.4, shodu configu a battery mode; čeká se na VERIFIED BATTERY OTA.
- Limit harnessu 1800 s, žádné debugger zásahy; caffeinate do konce procesu.

---

# Bateriový test — čeká na jeden RESET k opuštění instalačního USB režimu

- Uživatel potvrdil odpojení kabelu. XIAO disk i USB zařízení zmizely.
- Harness /tmp/MacroPadBatteryOTA.app spuštěn 19:14:28 UTC, ale BLE připojení
  timeoutuje. Žádný BATTERY-ONLY START / reboot / OTA přenos nenastal.
- Pravděpodobně zůstal USB bootloader po čtení INFO_UF2; odpojení USB ho
  nevrátilo do aplikace. Uživatel požádán JEDNOU RESET s odpojeným kabelem,
  pouze pro dokončení jednorázové instalace. Závěrečný OTA pak bez RESETu.
- Čekající PID 38225 ukončen před předáním (jen připojovací preflight),
  log /tmp/macropad-battery-ota.log. Žádný zápis ani automatický test neběží.
- Po uživatelově „hotovo“ znovu spustit stejný připravený harness detached,
  monitorovat a ověřit BATTERY-ONLY START a VERIFIED BATTERY OTA.

---

# Bootloader OTAFIX nainstalován — čeká na test NA BATERII

- Uživatel schválil bootloader + požaduje OTA bez kabelu. Instalace úspěšná:
  skutečný INFO_UF2 hlásí 0.9.2-OTAFIX2.3-BP1.4, Board-ID nRF52840-SeeedXiaoSense-v1,
  SoftDevice S140 7.3.0. Kopie artifacts/ota-no-reset/INFO_UF2-after.txt.
- Před zápisem potvrzen Sense USB VID/PID 2886:0045 a 0.6.1, uložen dostupný
  CURRENT.UF2 (rozsah 0x1000–0xea000, tedy není úplnou zálohou bootloaderu/settings).
  artifacts/ota-no-reset/backup-before-install/. Nezaměňovat za kompletní flash dump.
- 74240 B ověřeného updateru zapsáno + fsync. Poté pad sám naběhl na 0.3.4,
  stejná BLE identita, 4 ovladače, config bajtově shodný, baterie 88 %.
  Log /tmp/macropad-after-bootloader.log. Pak přes BLE přešel do USB režimu
  pro přečtení nové verze; žádný další RESET při této kontrole.
- Uživatel právě požádán ODPOJIT USB a nechat baterii, bez RESETu.
  Po potvrzení spustit /tmp/MacroPadBatteryOTA.app/Contents/MacOS/MacroPadOTATest
  detached, stdout do /tmp/macropad-battery-ota.log. Harness sám čeká na
  battery mode >=30 %, shodu baseline, pak přenese 0.3.4 do XIAO_DFU.
- Neinstalovat další FW souběžně. Závěrečný cíl ještě není splněn: čeká se
  na plný OTA přenos a návrat NA BATERII bez kabelu a bez fyzického RESETu.

---

# OTA bez RESETu — instalace SCHVÁLENA, čeká na datové USB

- Uživatel požádal najít cestu k odstranění závěrečného RESETu.
- Nalezená konkrétní oprava: `usb_teardown()` po OTA, commit 02fc9bdeb9b28d35226fa20a8262bec315206ae3
  ve fork oltaco/Adafruit_nRF52_Bootloader_OTAFIX. Oprava odpovídá pozorovanému USB problému.
- Připraven release 0.9.2-OTAFIX2.3-BP1.4 pro XIAO **Sense**, nosd UF2,
  v artifacts/ota-no-reset/. Hash shodný s GitHub digest, struktura UF2,
  boot family, CF2 VID/PID, adresy a absence SD/settings ověřeny.
- README v této složce obsahuje přesný postup i kontrolu stagingu starého updateru.
- Uživatel nově výslovně schválil instalaci: „jdi na to ale cíl je bez kabelu“.
  Další souhlas s bootloaderem NEVYŽADOVAT. Závěrečný OTA test musí proběhnout
  na baterii, s fyzicky odpojeným USB a bez RESETu. Čeká se na připojení USB
  pouze pro jednorázovou instalaci; zatím žádný nový zápis na hardware.
- Aktuálně načten 0.3.4-ota, 4 ovladače, baterie 88 %, config hash stále
  e8cf11da861249dd972ea60ed2ce8b1927bcebd1ccc7438b83e5af8a204f59d9.
  Nová baseline /tmp/macropad-before-bootloader-config.bin. USB reboot [1,0x57]
  potvrzen padem, ale na Macu NENÍ žádné fyzické USB zařízení ani XIAO disk.
  Uživatel potvrdil kabel, následně požádán ověřit datové spojení/povolení
  příslušenství a dvojstisk RESETu pouze pro instalaci. Čeká se na tento krok.
- Připraven /tmp/MacroPadBootCheck.app, zdroj /tmp/macropad-bootcheck.swift:
  bez argumentu načte a uloží baseline; --verify ji porovná; --verify --usb
  po ověření pošle USB reboot. Neobsahuje žádný automatický firmware zápis.
- Připraven /tmp/MacroPadBatteryOTA.app (zatím NESPUŠTĚN), zdroj
  /tmp/macropad-battery-ota.swift a linker /tmp/macropad-link-battery.py.
  Před OTA vyžaduje FW 0.3.4, shodu baseline, battery mode a >=30 %.
  Vybírá pouze nový XIAO_DFU a ověřuje DIS. Po návratu kontroluje verzi,
  shodu configu i battery mode. Limit 1800 s. Spustit až PO instalaci
  bootloaderu a potvrzeném odpojení USB. Žádný testovací proces nezůstal běžet.
- Před budoucím nahráváním znovu ověřit aktuální FW/konfiguraci/disk; jiné relace
  pracují na 0.3.5/0.3.6. Nesahat na jejich změny ani nevyměňovat firmware automaticky.

---

# Aktuální změna — více připojených hostů a automatické předání (0.3.6)

- Universal shield: až 5 BLE spojení/5 bondů; CMake vytváří kontrolovanou kopii
  ZMK v0.3.0 ble.c, aby advertising pokračoval i při připojeném aktivním hostu.
  Původní autorizace párování zůstává. Legacy shield používá původní ble.c.
- Host capability bit 2 v byte 11: multi-host + failover. Worker po zjištění
  nedostupného BLE cíle čeká 3 s (kontrola po 1 s) a vybere další připojený
  uložený slot cyklicky. Návrat původního BLE hosta nepřebírá cíl zpět.
  Funkční USB výstup zůstává; USB fallback/preference nadále řeší ZMK.
  Bez náhrady nic nepřepíná. Pauza při learning lease, párování/open profilu,
  host příkazu a rebootu. Žádné mazání bondů. Auto výběr persistuje ZMK debounce.
- CCC odpojení jednoho odběratele již nevypne vzorky ostatním. Makra mají
  snapshot cíle; zbytek rozběhnutého makra se nepřenáší na nový endpoint.
  Změna cíle resetuje hold/encoder stav a vyžaduje puštění držených tlačítek.
- Appka průběžně čte konfiguraci po 3 s bez přepsání dirty návrhu. Save nejprve
  získá exclusive lease, přečte celé config a porovná s původní draft baseline.
  Konflikt se odmítne, lokální návrh zůstane. Odpojení fyzického BLE ownera
  uvolní lease ihned; samotné ukončení appky při živém OS HID až timeoutem 15 s.
- 37 Swift testů OK; universal arm64+x86_64 build a codesign OK. C policy test
  i ostatní C testy prošly v CI se sanitizéry. Finální všechny firmware varianty
  build 35135692083 úspěšné. Zdroj 9da10b6454c9d75c7b36dbb825d986f358e5a2c7,
  větev codex/multihost-failover. Pracovní index a HEAD obou repo zachovány.
- Přibalen normální macropadstudio 0.3.6-multihost, 386560 B, SHA256
  37efe7bb9dd0fd857821ebb210606896e28ced887c9ba1b9b10ad1f7476d8e80.
  Manifest/hash/UF2 znovu otestovány. Artifacts v artifacts/multihost-firmware.
- Nová appka nainstalovaná v /Applications/MacroPad.app a spuštěná. Předchozí
  bundle zálohován v artifacts/before-multihost/MacroPad.app. CUA před ukončením
  ověřila obě staré kopie bez dirty změn. První obrazovka nové appky ověřena;
  při následném otevření nastavení se CUA pipe opět uzavřela.
- Fyzický pad je odpojený, žádný XIAO boot disk. FW na hardware NENAHRÁN a
  fyzické předání se dvěma hosty NEOVĚŘENO. Postup acceptance testů je ve
  firmware docs/learning-protocol.md. /tmp/MacroPadOTATest.app z jiné práce
  běžel a nebyl měněn ani ukončen.

---

# Hotové sestavení v menu vlákně — encoder / Zařízení a baterie

- Firmware 0.3.5-wheel: codex/encoder-device-menu, commit
  5224d05f475a1405a9578d84bcbf60f3c7abb995. Firmware CI 35135457717
  i protocol CI 35135456976 úspěšné. UF2 struktura/rozsah code partition ověřeny.
- 37 Swift testů prošlo včetně aktualizovaných multi-host fixtures.
  Univerzální aplikace arm64+x86_64 sestavena, menu vizuálně ověřeno.
- Oddělená aplikace, firmware, manifest a náhled: artifacts/encoder-device-menu/.
  Firmware SHA256: 0549b6a49dea842f8d91e5a3a30fbbd64b5d583f46318d41aceb21ad5ca3acf1.
- Nic nebylo instalováno ani flashováno, běžící aplikace nerestartována
  kvůli souběžnému OTA/připojovacímu testu. Fyzický test encoderu zbývá.
- Menu změny jsou sdílené ve zdrojích; v2 wheel capability 1008=2,
  holdMode=3 (zařízení), hold povolen encoderům. Zachován krátký stisk,
  výchozí položka Zavřít. Nabídka obsahuje hosty, USB, baterii, mic a nastavení.
- Snapshot FW vychází z committed OTA base 468185c a neobsahuje právě
  rozpracované multi-host opravy; před finálním nasazením spojit obě sady změn.

---

# Fyzický test OTA — 16. 9. 2026, PŘENOS OVĚŘEN, RESET NUTNÝ

- Test ukončen, žádný OTA přenos ani testovací proces už neběží. Pad má funkční
  0.3.4-ota. Uživatel výslovně potvrdil, že po dokončení stiskl jeden RESET.
- Bezdrátový vstup do bootloaderu [1,0xa8] fungoval bez RESETu. Přenos celého
  obrazu přes NordicDFU běžel 18:49:42–18:59:53 UTC (10 min 11 s), dosáhl 100 %,
  bootloader ověřil obraz. Automatický návrat do FW při připojeném USB selhal.
- Po uživatelově jednom RESETu v 19:01:17 UTC načtena původní BLE identita,
  verze 0.3.4-ota a všechny 4 ovladače. V 19:01:18 harness zaznamenal VERIFIED:
  konfigurace 496 B je BAJTOVĚ SHODNÁ s kopií před prvním přenosem.
- NEPREZENTOVAT jako plně bez RESETu. Závěrečný RESET při USB odpovídá popsanému
  omezení starého bootloaderu; test na baterii bez USB nebyl proveden.
  https://github.com/oltaco/Adafruit_nRF52_Bootloader_OTAFIX#recommended-ota-dfu-settings
- Bootloader 0.6.1, S140 7.3.0/FWID 0x0123 a settings zůstaly zachované.
  Uživatel schválil USB instalaci app FW + OTA test, nikoliv změnu bootloaderu.
- Testovaný UF2 385024 B, pouze code partition, source 468185c8:
  SHA256 cfc21adf2ace62f5a036ee539faa47ae94a48d959d0038a4ace37e9e41ec92d7.
  Baseline /tmp/macropad-before-ota-config.bin,
  SHA256 e8cf11da861249dd972ea60ed2ce8b1927bcebd1ccc7438b83e5af8a204f59d9.
- Log dokončeného testu /tmp/macropad-ota-final3.log. Souhrn uložen v
  artifacts/bluetooth-ota/physical-test-2026-09-16.md. Test použil reálné
  LearningPad/OTAPad/OTAFirmware app třídy v izolovaném harnessu.
- První pokus skončil při 40 %. Testovací harness měl původně chybný limit
  480 s; opraven na 1800 s. LLDB na macOS 27 padal, pozdější test bez debuggeru.
  Uživatel také oznámil pád notebooku a opětovné připojení padu. Po USB obnově
  dvakrát ověřena shoda konfigurace. Příčinu prvního přerušení nelze určit jistě.
- Další DFU kandidát Omi DIY nikdy nebyl připojován ani přehráván. Pro finální
  přenos vybrán pouze AdaDFU nově objevený po rebootu padu a ověřen DIS Seeed XIAO.
- UI doplněna procenta, orientační 11min délka a omezení se starým bootloaderem.
  OTAPad brání idle uspání při přenosu a uvolní aktivitu po dokončení/chybě.
  Ověření návratu má 120 s a po timeoutu pokračuje i při pozdějším připojení.
- 37 Swift testů prošlo. Universal build + podpis ověřeny. Samostatný bundle
  MacroPadApp/dist/MacroPad-OTA.app obsahuje testovaný 0.3.4. Běžící GUI a
  /Applications se neměnily; paralelní 0.3.5/0.3.6 nejsou tímto testem ověřeny.

---

# Rozpracováno — Bluetooth OTA 0.3.4

- Z fyzického `/Volumes/XIAO-SENSE/INFO_UF2.TXT` přečteno 16. 9. 2026:
  UF2 Bootloader 0.6.1, Seeed_XIAO_nRF52840_Sense, S140 7.3.0, 12. 11. 2021.
- Původní tvrzení, že OTA znemožňuje nepřítomnost SoftDevice v ZMK obrazu,
  bylo nesprávné: S140 je na tomto padu zachovaný pod aplikační oblastí.
- Připraven 0.3.4-ota, source 468185c818b3bf3010d73c2b0899431b78c57d73,
  větev codex/bluetooth-ota, celý firmware CI run 35134365464 úspěšný.
  SHA256 cfc21adf2ace62f5a036ee539faa47ae94a48d959d0038a4ace37e9e41ec92d7.
- Firmware: 100a čte schopnost OTA/SoftDevice ID, 1009 přijímá [1,0xa8].
  Před vstupem kontrola S140 magic/ID/velikosti, bonded host, žádné souběžné
  learning/host/pairing operace. Bez mazání settings, SD nebo bootloaderu.
- App: OTAFirmware převod/CRC/init packet; OTAPad používá přesně NordicDFU 4.17.0,
  uživatelský výběr DFU zařízení + kontrolu Seeed XIAO modelu, watchdog, průběh,
  a ověření verze/config po návratu původní BLE identity. USB fallback zachovaný.
- 31 Swift testů a universal build prošly, včetně nového UF2. SwiftPM resource
  bundles baleny build.sh. Fyzické OTA dosud NEOVĚŘENO, bootloader se neměnil.
- Uživatel zatím souhlasil se čtením; odeslána asynchronní otázka pro první USB
  instalaci 0.3.4 a následný OTA test. Do odpovědi na zařízení NIC NEZAPISOVAT.
- Nový build zatím pouze MacroPadApp/dist/MacroPad.app; běžící appka ani
  /Applications při tomto kroku neměněny. CUA pipe při kontrole nefungovala.

---

# Aktuální změna — aktualizace FW z aplikace bez RESETu

- Nastavení → Připojení a firmware: běžící/přibalená verze, příprava přes BLE,
  výběr UF2 disku, nahrání přes USB, ověření verze + načtení konfigurace po návratu.
- Nová šifrovaná charakteristika 1009: read `[1]+ASCII version`, write `[1,0x57]`.
  Jen uložený host; USB musí být configured/HID, bez learning lease/host operace/
  párování. Odložený reboot 750 ms pomocí existujícího `sys_reboot(RST_UF2)`.
- UF2 validace kontroluje SHA256, rodinu, bloky, adresy pouze v code partition
  0x27000..<0xec000. Zápis do settings/bootloader/SoftDevice se odmítne.
- Starý 0.3.2 vyžaduje jednorázový dvojstisk RESETu pro první instalaci 0.3.3.
  Plné BLE OTA není implementováno, přenos FW vyžaduje datové USB k tomuto Macu.
- Přibalen 0.3.3-usb-update, source 9c0615f6cf304f6ee19d1335115556321517ff6a,
  větev codex/firmware-update, CI run 35133338743. Normální macropadstudio build
  úspěšný; SHA256 26c2e7d425af052c2543fe9604cfd83f93dd268b4271d919f633eddf1683dd37.
- Firmware snapshot sestaven z pracovního stromu včetně předchozího action wheel;
  původní lokální index, HEAD a rozpracované změny submodulu zachovány.
- Celý firmware CI run úspěšný, C protokol/hold testy úspěšné. 27 Swift testů
  prošlo včetně manifestu nového UF2; universal build a codesign ověření OK.
- Nová aplikace nainstalována v /Applications/MacroPad.app. Původní bundle
  přesunut do artifacts/before-firmware-update/MacroPad.app jako záloha.
  Běžící proces NERESTARTOVÁN: CUA prokázala nově rozpracované/neuložené změny.
  Nové UI tedy zatím nebylo ověřeno v běžícím okně. Uživatel má nejprve uložit
  změny a aplikaci ukončit/spustit z /Applications/MacroPad.app.
- Přenos na fyzický pad ani nový BLE bootloader příkaz zatím NEOVĚŘENY:
  na zařízení stále původní FW. Neprováděn settings reset.

---

# Aktuální změna — samostatný klik a long press / kruhové menu

- Tlačítka mají nezávislý Stisk a Podržení (350 ms). Krátký stisk při zapnutém
  podržení běží až po puštění; long press původní makro nikdy nevyvolá.
- Podržení: vlastní menu (aplikace, klávesová sekvence, Zkratky macOS) nebo
  běžící aplikace. Kolečko vybírá, puštění potvrzuje, Esc ruší. Limit 20 s.
- Vlastní položky jsou v Application Support/MacroPad/action-wheels.json,
  oddělené podle BLE identity padu a stabilního ID tlačítka. Režim v control
  byte 6 (0/1/2), původní makra i formát 496 B zachovány. Encoder hold je BT.
- Ovládání jde přes vyhrazené HID chordy na skutečný cílový host; pasivní
  BLE odběr na dalším Macu akce nespouští. Carbon mic handler filtruje ID.
- Nový firmware inzeruje charakteristiku 1008; appka starý FW rozpozná.
- 25 Swift testů OK, C hold/protokol testy OK (také CI se sanitizéry).
  Universal arm64+x86_64 build a podpis ověřeny. Menu i editor vizuálně
  zkontrolovány v /tmp/macropad-wheel-preview.png a /tmp/macropad-wheel-editor.png.
- FW větev codex/hold-action-wheel, zdroj a526f1678fe7e1b86507cd250c08927a93ac2134,
  úspěšný build 35106315073. Navazující ed28859 přidává hold test do CI;
  jeho firmware build 35106483300 i test 35106482634 prošly také.
- Přibalen 0.3.2-action-wheel, SHA256
  c63b882a95c2f42e3ba1513e6390144f46c299e7f7882514ae3cccda8a3a85a4.
- Nová appka nainstalována v /Applications/MacroPad.app a spuštěna po
  ověření, že v konfigurátoru nebyly neuložené změny. Předchozí appka
  zálohována v ignorovaném artifacts/before-action-wheel/MacroPad.app.
- Nový normální UF2 fyzicky nahrán přes debug bootloader příkaz. Ověřen
  Board-ID XIAO-SENSE, 384000 B + fsync, zmizení disku a nová USB HID registrace.
  Settings reset nepoužit. Normální firmware nemá diagnostickou USB konzoli.
- Po flashi appka znovu připojena: 4 původní prvky načteny, u Tlačítka 4
  ověřen aktivní výběr Vypnuto / Kruhové menu / Přepínání aplikací.
- Long press není automaticky přiřazen žádnému tlačítku. Vybere ho uživatel
  v editoru a uloží. Fyzický test kliku/podržení/rotace stále vyžaduje uživatele.
- Lokální Docker build zaplnil disk. Po explicitním souhlasu uživatele byl
  Docker restartován a náš kontejner/obraz smazán; Docker opět běží, volno ~45 GiB.
  Finální firmware pochází výhradně z úspěšného GitHub Actions sestavení.

---

# Aktuální stav — generovaná ikona

- Vestavěný imagegen vytvořil graphite/cyan macOS ikonu (3 klávesy + encoder).
- Master, ICNS a přesný prompt v MacroPadApp/Artwork. ICNS obsahuje 16–1024 px.
- build.sh a Info.plist používají MacroPadIcon; universal build prošel.
  ICNS dekódován a vizuálně ověřen i při 128 px, alpha zachována.
- Ikona + odkaz v plist aktualizovány i v /Applications/MacroPad.app, codesign OK.
  Běžící appka NERESTARTOVÁNA kvůli rozpracovaným změnám z předchozího UI stavu.
  Dock může novou ikonu ukázat až při příštím spuštění.

---

# Aktuální změna — přehled akcí encoderu

- Opakované přepínače typu akce u encoderu nahrazeny třemi souhrnnými řádky:
  Stisk / Doleva / Doprava + skutečně přiřazená akce.
- Kliknutí na řádek otevře jeden editor; další kliknutí ho zavře. Přepnutí
  editoru používá nové ID a ukončí nahrávání původní zkratky.
- Tlačítko s jednou akcí má editor rovnou. Výběr jiného prvku resetuje otevřený řádek.
- 12 testů a universal build prošly, appka aktualizována bez změny konfigurace/FW.

---

# Aktuální stav — sjednocený vizuální styl aplikace

- StudioStyle poskytuje tmavé povrchy, cyan akcent, vlastní tlačítka, karty,
  stavové štítky, typografii a volby prvků. Hlavní okno má skrytou titlebar.
- Editor akcí: ikonové volby typu, vlastní popup médií/myši, klávesové štítky
  pro makra, vlastní nahrávací ovládání. Menu zachovává všechny původní akce.
- Sjednoceno nastavení zařízení, kroky učení, přidávání ovladačů, empty state,
  footer se stavem/zápisem a mikrofonní HUD. Funkce a FW beze změn.
- 12 Swift testů prošlo; universal build prošel. Komponenty vyrenderovány a
  vizuálně zkontrolovány (/tmp/macropad-studio-style.png, ukázková data).
- Nová aplikace nainstalována do /Applications/MacroPad.app a spuštěna.
- CUA po resetu již funguje! Přímo ověřena hlavní obrazovka s načtenými čtyřmi
  prvky, otevření výběru mediálních akcí, nastavení/zapojení a návrat zpět.
  Screenshoty hlavního okna i nastavení vizuálně zkontrolovány. Konfigurace nezměněna.

---

# Aktuální stav — vizualizace nakonfigurovaného zařízení

- Nový DevicePreview nahrazuje hlavní 8×8 grid. Zobrazuje oříznuté fyzické
  rozložení v tmavém těle, klávesy s popisky akcí, kruhový encoder a výběr cyan.
- Aktivita zůstává zelená, otočení ukazuje směr. Kliknutí vybírá editor zkratek.
  8×8 editor zůstává pouze v nastavení. Vnitřní mezery a relativní polohy zachovány.
- Velikost prvků se přizpůsobuje šířce; velká rozložení mají horizontální posun.
- Samotné tělo zařízení vyrenderováno přes SwiftUI ImageRenderer a vizuálně
  zkontrolováno (/tmp/macropad-device-preview.png, ukázková data). Celý TimelineView
  ImageRenderer nerenderuje; běžné okno přes CUA stále nedostupné.
- Universal build a codesign ověření prošly; app aktualizována a spuštěna.
  Firmware ani konfigurace se neměnily.

---

# Aktuální stav — odstraněny dva konfigurátory

- Po screenshotu uživatele odstraněn TabView i přístup k Původnímu konfigurátoru.
  Hlavní okno obsahuje jen HardwareWorkspace; průvodce zůstává v nastavení.
- Legacy AppState se neinicializuje; standardní F18 mic hotkey zachován explicitně.
- Universal build a codesign ověření prošly. Nová appka nainstalována a spuštěna.

---

# Aktuální změna — nastavení zařízení v popupu

- Hlavní obrazovka: živý grid vlevo, editor akcí vybraného prvku vpravo.
  Úpravy akcí nevyžadují learning lease; Uložit zkratky si jej získá samo.
- Nastavení MacroPadu otevírá sheet s připojením/FW, učením a rozložením.
  Po ověřeném save/readback se sheet zavře a zachová výběr prvku pro zkratky.
- Zavření sheetu ponechá lokální návrh a příkazem 2 ukončí lease bez odpojení,
  takže pasivní zvýraznění i normální HID pokračují. Chyby zápisu sheet nezavírají.
- 12 Swift testů a universal build prošly. Firmware se nemění (rc5).
- CUA není funkční (native pipe closed); vzhled potřebuje kontrolu uživatelem.

---

# Aktuální oprava — neaktivní tlačítko uložení

- Footer chybně vyžadoval pad.learning; nově je uložení dostupné pro připojený
  pad s neprázdným návrhem. Save zařadí příkaz 1 před 3/chunky/5 a sám získá lease.
- Odpojení a prázdný návrh mají vysvětlení vedle tlačítka.
- Nový test ověřuje získání lease před stagingem, offsety, celý payload i commit.
  Test a universal build prošly; firmware se nemění (rc5).
- Uživatel potvrdil úspěšné uložení přes Upravit konfiguraci → Dokončit
  a nahrát. Nová appka pak nainstalována a spuštěna v /Applications/MacroPad.app.

---

# Aktuální stav — živý grid rc5

- HardwareWorkspace zobrazuje zelený stisk/pulz 300 ms a šipku směru encoderu.
  HardwareActivity mapuje stabilní ID na piny návrhu; výpadek zhasne do 1,5 s.
- Firmware 8389557 posílá vzorky šifrovaným odběratelům i mimo learning lease.
  Odběr neblokuje HID ani nezapisuje nastavení; aplikace ho zapíná po načtení.
- Firmware CI 35092130156 prošlo; zdrojové docs doplněny v f60782a.
- Debug UF2 fyzicky nahrán, SHA256
  9842fb4de31a5b62186df0a27d31574346800fd064c68b7a3bb5290f42af29aa.
- Nová aplikace nainstalována a spuštěna v /Applications/MacroPad.app.
  Uživatel před restartem potvrdil uloženou konfiguraci.
- 11 Swift testů prošlo včetně stisku, puštění, obou směrů, mezery ve vzorcích
  a výpadku spojení. Universal build prošel; nový rc5 bundle zvlášť ověřen.
- CUA stále vrací native pipe closed. Uživatel fyzicky potvrdil zvýraznění
  správných prvků i zobrazení směru encoderu.
- Pozor: USB boot log hlásí configured=0, přestože uživatel uvedl uložený layout.
  Pokud chybí rozložení, ověřit skutečné načtení z konkrétního padu; nic nemazat.
- Následují historické záznamy.

---

# Aktuální stav — učení vstupů rc4

- Uživatel hlásil 0 zachycených změn. Běžely dvě kopie appky současně.
- USB log rc3 prokázal vyčerpané ATT buffery při odesílání vzorků.
- Firmware 2200450 odděluje skenování GPIO od Bluetooth: fronta 256 vzorků
  a samostatné vlákno pro odesílání, bez blokování systémové workqueue/mutexu.
  Případné přetečení se stále projeví mezerou v sekvenci a odmítnutím pokusu.
- Appka čeká na první vzorek před nabídkou přidání ovladače; po 8 s bez dat
  oznámí chybu. Nové učení resetuje čas předchozího vzorku.
- Obě kopie appky ukončeny po potvrzení, že nejsou neuložené prvky.
  Nainstalována/spuštěna nová /Applications/MacroPad.app; běží jediná kopie.
- CI firmware 35091667332 a C testy prošly. 10 Swift testů a universal build
  prošly, nový přibalený UF2 dodatečně ověřen testem manifestu a struktury.
- Debug firmware fyzicky nahrán přes USB bootloader příkaz, bez mazání bondů.
  SHA256 6cadf0a16722310856448c1e501b37e97ade5103ee963e92fc0f39a718cb1541.
  Pro USB příkaz musí být aktivní DTR (otevřít sériový monitor před příkazem).
- Uživatel potvrdil rozpoznání tlačítka i celého encoderu (stisk, doprava, doleva).
- V appce je přibalen normální rc4 UF2. Na zařízení zůstává debug rc4.
- Následují historické záznamy.

---

# Aktuální stav — oprava volného profilu rc3

- USB diagnostika prokázala automatické spojení s druhým Macem a následné
  odmítnutí tohoto Macu: `Rejecting pairing request to taken profile 0`.
- Firmware 1565bd8 rezervuje skutečně volný profil i při připojeném starém hostu.
  Klíč setup_profile_v2 opravuje chybnou rezervaci z rc2. Bondy se nemažou.
- CI 35091017485 prošlo. Nový debug UF2 byl nahrán na XIAO-SENSE.
  SHA256 dd702be7d40af7a27c0934b9a7b091cb0e306cdda0e846f1a9e56bb2168bef6b.
- Fyzický výpis potvrdil `open=0x1e target=1` a výběr profilu 1 s výsledkem 0.
- Uživatel potvrdil úspěšné připojení a načtení v appce. USB log potvrzuje
  šifrování level 2, nový bond v profilu 1; původní profil 0 zachován.
- Appka otevřena a její přibalený firmware aktualizován na rc3.
  10 Swift testů a lokální universal build prošly.
- Debug USB konzole podporuje status, profile N a bootloader (řádek s LF).
  Bootloader lze nyní vyvolat bez fyzického resetu. Port /dev/cu.usbmodem101.
- Normální rc3 UF2 je přibalené v MacroPadApp/Firmware, debug jen na zařízení.
- Diagnostické logy lokálně /tmp/macropad-occupied-profile-proof.log a
  /tmp/macropad-device-serial.log. Nezveřejňovat osobní diagnostiku.
- Starší hypotéza nedostatečného stacku se nepotvrdila; 4096 B ponecháno.
- Níže je historický průběh, ne aktuální stav.

---

# Oprava párování před prvním učením — 16. 9. 2026

- Uživatel hlásil viditelné zařízení, které odmítá připojení po flashi rc1.
  Na Macu nepoužil Zapomenout zařízení.
- Univerzální FW zachovával obsazený BLE profil a před učením nešlo přepnout.
  Nově před první konfigurací rezervuje volný profil, pokud aktivní není
  připojený; volbu ihned persistuje. Staré bondy ani layout nemaže.
- Průvodce zahájený již spárovaným Macem při prázdném layoutu vybere odpovídající
  původní profil. Držení prvního encoderu + rotace přepíná všechny profily.
- Firmware `ef7ec5f`, úspěšné CI **35086604901**, 0.3.0-rc2.
- UF2 SHA256 `60f1f77993f784475e63fc21aa80edc90bc2fb1a66f4153bd2243cb9898671e3`.
- Nahráno na místní XIAO-SENSE: 375296 bytů, fsync OK, boot disk zmizel a
  MacroPad USB HID se znovu zaregistroval. Settings reset nebyl použit.
- C testy pokrývají bootstrap profilů; 10 Swift testů s novým UF2 prošlo.
- Dotaz na ověření Bluetooth připojení je odeslaný uživateli; výsledek zatím
  nepotvrzen. Pokud selže, dál diagnostikovat místo automatického mazání bondů.

---

# Průvodce učením MacroPadu — 16. 9. 2026

- Nová záložka Vlastní MacroPad: první flash přibaleného UF2, učení tlačítek a
  encoderů, grid 8×8, editor akcí, ověřený atomický zápis konfigurace do zařízení.
- Univerzální firmware shield `macropadstudio`, firmware commit `88d4e00`.
  Firmware CI **35083822512** úspěšné; správný samostatný keymap a kscan queue 64.
- Konfigurace obsahuje stabilní ID, piny, grid i makra; jiný Mac ji čte z padu.
  Lokální soubor není nutný. První BLE párování je v nastavení macOS.
- První flash je univerzální firmware, finální tlačítko nahrává konfiguraci do NVS.
  Žádná kompilace na míru nebo druhý flash není potřeba.
- Přibalené UF2 + SHA256 + zdrojový commit jsou v `MacroPadApp/Firmware`.
- Swift: 10 testů (včetně přibaleného firmware), původní i nový C protokol prošly.
- Univerzální app build prošel lokálně. UI automation nelze ověřit: nástroj CUA
  vrací `cgWindowNotFound` / `Sky Computer Use native pipe closed before response`.
- Fyzické učení a načtení na druhém Macu nejsou vyzkoušené. Nový firmware nebyl
  flashnut na připojený pad; stále na něm běží poslední rc3, viz níže.
- Podporováno přímé zapojení D0–D10 proti GND, encoder se spínačem 4 hrany/krok.
  Matice/expandéry zatím ne. Deep sleep stále vypnutý, spotřeba scanneru nezměřená.
- První encoder hold + první/druhé tlačítko podle stabilního ID volí BLE 0/1.
  Univerzální FW neobsahuje nechtěné mazání párování původní kombinací.
- Návod: `docs/learning-wizard.md`; protokol ve firmware repo `docs/learning-protocol.md`.

---

# Oprava prvního stisku po nečinnosti — 16. 9. 2026

- Firmware commit `2309bc6`: `CONFIG_ZMK_SLEEP=n`, idle zůstává 30 sekund.
- Dřívější deep sleep po 15 minutách odpojoval BLE a první stisk mohl propadnout.
- Oprava zachovává spojení za cenu vyšší klidové spotřeby; výdrž není změřená.
- Aktualizace pouze hlavním UF2, bez `settings_reset`, zachová párování i makra.
- Vydání v0.2.0-rc3: firmware úspěšně nahrán na XIAO-SENSE po přepojení z druhého Macu.
- SHA-256 UF2: `4f9768e7232d9ec320516df381f983435a4a3cdb06ce013c7538782ceff88e78`.
- Ověřen Board-ID, úplný zápis i fsync; bootloader disk zmizel a Mac znovu
  registroval MacroPad USB HID (`1d50:615e`). Settings reset nebyl použit.
- Firmware CI 35081346764 prošlo; efektivní Kconfig má idle 30 s, BLE a settings
  zapnuté, deep sleep vypnutý. Fyzický test prvního stisku po >15 minutách
  na baterii stále čeká na potvrzení uživatelem.

---

# Bezdrátový konfigurátor — 15. 9. 2026

- Appka i firmware jsou sloučené do `main` na GitHubu.
- Předběžný balíček: release `v0.2.0-rc1` (firmware nahrán, BLE zápis ještě neověřen).
- XIAO má vlastní šifrovanou GATT službu pro šest konfigurovatelných maker.
- Zápis odemkne současný stisk všech tří kláves na 60 sekund.
- Data se ukládají do Zephyr settings a aplikace je ověřuje zpětným čtením.
- Appka načítá skutečnou konfiguraci při připojení, podporuje jeden slot i všechny,
  hlásí výpadky/timeouty a uchovává CH552 a XIAO soubory odděleně.
- Lokální release build aplikace a čtyři XCTest testy prošly.
- Firmware build 35017834407 a macOS build 35017836287 prošly v GitHub Actions.
- Host C test a Linux ASan/UBSan test prošly.
- UF2: `artifacts/wireless-config/final-firmware/macropad-seeeduino_xiao_ble-zmk.uf2`.
- Nová appka: `MacroPadApp/dist/MacroPad.app`.
- Nové UF2 bylo nahráno na ověřený disk XIAO-SENSE (Board-ID Seeed_XIAO_nRF52840_Sense).
- SHA-256: `74e8810f29993287a3bdc8adedcc98627d2f4bce5e19f4693dc253c751764964`.
- Zápis a fsync proběhly bez chyby, bootloader disk zmizel a `hidutil list`
  znovu ukazuje MacroPad USB HID, VID:PID `1d50:615e`.
- Dokončit fyzicky: spárovat Bluetooth, ověřit zamčený zápis,
  odemknutý zápis, načtení, přetrvání po restartu a skutečné chování kláves.
- Uživatel potvrdil bootloader disk a instalace firmwaru je dokončená.
- CUA po resetu relace stále hlásí „native pipe closed“; připojení v appce musí
  zatím provést uživatel přes XIAO · Bluetooth → Najít MacroPad → Připojit a načíst.
- CUA nebylo dostupné a snímek displeje se nepodařilo získat; vzhled UI není vizuálně ověřen.
- Lokální ASan runtime se zablokoval při inicializaci na macOS 27 beta;
  běžný lokální C test a Linux CI se sanitizéry prošly.

---

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
