# Bundled first-install firmware

`macropad-learn.uf2` is intentionally versioned: a fresh install of MacroPad.app
must flash an offline device without GitHub credentials, a compiler, or a network
connection. It is the `macropadstudio` / `seeeduino_xiao_ble` build from the private
firmware repository. `firmware.json` pins its source commit, Actions run and SHA256.

Only replace these files with the matching **successful CI build**. Do not bundle
`settings_reset` or the legacy fixed-layout `macropad` image. The app validates
board ID, UF2 family/block structure and SHA256 before writing. Its final wizard
step persists learned hardware/layout/actions into firmware NVS; recompilation
and a second firmware flash are not needed.
