#!/bin/zsh
# Ceka na bootloader disk, nahraje CircuitPython, pak ceka na CIRCUITPY a nahraje code.py
cd "$(dirname "$0")"
echo "[$(date +%T)] cekam na XIAO-SENSE (2x reset)..."
for i in {1..600}; do [ -d /Volumes/XIAO-SENSE ] && break; sleep 1; done
[ -d /Volumes/XIAO-SENSE ] || { echo "timeout: XIAO-SENSE se neobjevil"; exit 1; }
echo "[$(date +%T)] bootloader nalezen, kopiruji CircuitPython..."
cp circuitpython-9.2.9-xiao-nrf52840.uf2 /Volumes/XIAO-SENSE/ 2>/dev/null || true
sleep 2
echo "[$(date +%T)] cekam na CIRCUITPY..."
for i in {1..120}; do [ -d /Volumes/CIRCUITPY ] && break; sleep 1; done
[ -d /Volumes/CIRCUITPY ] || { echo "timeout: CIRCUITPY se neobjevil"; exit 1; }
sleep 2
cp code.py /Volumes/CIRCUITPY/code.py && sync && echo "[$(date +%T)] code.py nahran, test bezi"
