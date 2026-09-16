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
- Uživatel potvrdil rozpoznání tlačítka. Odeslán doplňující dotaz na encoder.
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
