# Testovaci FW pro macropad na XIAO nRF52840 (CircuitPython)
# Vypisuje do serioveho terminalu stisky tlacitek a otaceni encoderu.
import time, board, digitalio, rotaryio

PINS = {"U1 (D0)": board.D0, "U2 (D1)": board.D1, "U3 (D2)": board.D2, "ENC stisk (D3)": board.D3}
btns = {}
for name, pin in PINS.items():
    b = digitalio.DigitalInOut(pin); b.switch_to_input(pull=digitalio.Pull.UP); btns[name] = b

enc = rotaryio.IncrementalEncoder(board.D4, board.D5, divisor=2)
led = digitalio.DigitalInOut(board.LED_BLUE); led.switch_to_output(value=True)  # True = zhasnuto

print("\n=== MacroPad test ===")
print("Stiskni tlacitka / otacej encoderem. Ctrl+C = konec.")
print("Klidovy stav pinu (1 = OK / rozepnuto, 0 = ZKRAT nebo drzeno):")
for n, b in btns.items(): print(f"  {n}: {int(b.value)}")

last_pos = enc.position; prev = {n: b.value for n, b in btns.items()}
while True:
    for n, b in btns.items():
        v = b.value
        if v != prev[n]:
            print(f"[{time.monotonic():7.2f}] {n}: {'STISK' if not v else 'pusteno'}")
            prev[n] = v; led.value = v
    pos = enc.position
    if pos != last_pos:
        d = pos - last_pos
        print(f"[{time.monotonic():7.2f}] ENCODER {'-> doprava (CW)' if d > 0 else '<- doleva (CCW)'}  pozice={pos}")
        last_pos = pos
    time.sleep(0.005)
