# MacroPad projekt – instrukce pro agenta
- Začni čtením `README.md` a `HANDOFF.md` – obsahují celý kontext, protokol, zapojení a další kroky.
- Uživatel chce **velmi stručné** odpovědi, tabulky/diagramy místo prózy, česky.
- Hardware je fyzicky u uživatele; nic nefunguje bez jeho zásahu (RESET, pájení). Vždy řekni, co má udělat, a ověř to logem/měřením.
- `MacroPadApp/`: `./build.sh` staví `dist/MacroPad.app`. Screenshot okna: viz `screenshot.png`.
- `zmk-config-macropad/`: git submodul, GitHub mrpajzl/zmk-config-macropad. Neměň `a-gpios/b-gpios` – směr encoderu je ověřený.
- Aktuální stav firmwaru a ověření čti v `HANDOFF.md`.
