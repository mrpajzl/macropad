# Ověření vydání 0.3.6 — 16. 9. 2026

## Rozsah

Sjednoceny změny OTA, krátkého stisku/podržení a kruhových menu, správy více
počítačů, automatického předání výstupu, jednoduššího nastavení a obnovy spojení.
Akce jsou pouze na hlavní obrazovce. Firmware nabídne datové USB jako hlavní
metodu, je-li pad připojený k tomuto Macu; jinak Bluetooth.

## Opravy z finální kontroly

- Propojena položka Nastavení v menu zařízení s oknem aplikace.
- Po znovuotevření okna se načte existující konfigurace z BLE klienta, který běží dál.
- Po odmítnutém/nepotvrzeném vstupu do bootloaderu se obnoví automatické připojování.
- Po vypršení čekání na návrat firmwaru lze přepnout na druhou metodu obnovy.
- Aktualizován návod odpovídající aktuálnímu rozhraní a verze aplikace na 0.3.6.

## Výsledky

- 39 Swift testů prošlo; univerzální arm64/x86_64 sestavení a podpis ověřeny.
- Čtyři C testy (protocol, learn_protocol, hold, host_policy) prošly s -Wall
  -Wextra -Werror. ASan/UBSan na GitHub CI prošly; lokální ASan proces na tomto
  Macu se zastavil bez výstupu, proto není uváděn jako úspěšný lokální test.
- Přibalený obraz 0.3.6-multihost odpovídá manifestu a úspěšnému firmware CI
  35135692083 (zdroj 9da10b6454c9d75c7b36dbb825d986f358e5a2c7).
  Sjednocený firmware commit 8683a62996ea8fdb11fc3cccd2fb7d84daf48105 má shodné
  sestavované zdroje; liší se doplněnou dokumentací.
- Živý pad již hlásí 0.3.6-multihost, wheel v2 a multi-host capability. Má čtyři
  ovladače, dva uložené počítače, jeden právě připojený, napájení z baterie 88 %.
  Odpojení a nové připojení testovacího klienta prošlo a konfigurace zůstala
  bajtově stejná. Zbytečné opakované nahrání firmwaru nebylo provedeno.
- Dřívější fyzický test ověřil plný OTA přenos 0.3.4 na baterii s bootloaderem
  OTAFIX2.3-BP1.4 a automatický návrat bez RESETu. Není vydáván za nový OTA test 0.3.6.

## Rozsah ručního ověření

Ovládání živého GUI nástrojem CUA není dostupné (native pipe closed). Rozhraní
bylo kontrolováno renderováním SwiftUI a kódem. Nebyl proveden celý ruční scénář
současné práce na dvou fyzických Macích, předání při odpojení druhého Macu a
všech klávesových akcí. Čisté testy policy/protokolu jej nenahrazují.

Lokální log a záloha aktuální konfigurace jsou v ignorované složce
artifacts/release-0.3.6. Bootloader ani párování nebyly při této kontrole měněny.
