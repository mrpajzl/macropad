#!/usr/bin/env python3
"""Fallback CLI (kdyby WebHID nešel). Vyžaduje: brew install libusb && pip3 install --user pyusb
Použití:
  python3 macropad.py list
  python3 macropad.py key 1 ctrl+c                # klávesa 1 = Ctrl+C
  python3 macropad.py key 2 cmd+shift+4 enter     # sekvence (max 5)
  python3 macropad.py media 3 mute
  python3 macropad.py key knob-ccw ctrl+minus ; python3 macropad.py key knob-cw ctrl+equal
  python3 macropad.py media knob-press play
  python3 macropad.py led 1
Protokol stejný jako index.html (ch57x-keyboard-tool, model 1189:8890)."""
import sys, time
from server import write_packets, find

VID = 0x1189
KEYS = {"1":1,"2":2,"3":3,"knob-ccw":13,"knob-press":14,"knob-cw":15}
MODS = {"ctrl":1,"shift":2,"alt":4,"opt":4,"cmd":8,"win":8,"rctrl":16,"rshift":32,"ralt":64,"rcmd":128}
CODES = {**{c:4+i for i,c in enumerate("abcdefghijklmnopqrstuvwxyz")}, **{c:30+i for i,c in enumerate("1234567890")},
 "enter":40,"esc":41,"backspace":42,"tab":43,"space":44,"minus":45,"equal":46,"lbracket":47,"rbracket":48,"backslash":49,
 "semicolon":51,"quote":52,"grave":53,"comma":54,"period":55,"slash":56,"capslock":57,"printscreen":70,"insert":73,"home":74,
 "pageup":75,"delete":76,"end":77,"pagedown":78,"right":79,"left":80,"down":81,"up":82, **{f"f{i}":57+i for i in range(1,13)}}
MEDIA = {"volup":0xe9,"voldown":0xea,"mute":0xe2,"play":0xcd,"stop":0xb7,"next":0xb5,"prev":0xb6,"brightup":0x6f,"brightdown":0x70}

def send(_, msgs): write_packets(msgs); [print("→", (bytes(m)+bytes(9))[:9].hex(" ")) for m in msgs]

def parse(tok):
    mod, code = 0, 0
    for p in tok.lower().split("+"):
        if p in MODS: mod |= MODS[p]
        else: code = CODES[p]
    return mod, code

def main(a):
    if not a or a[0]=="list":
        d=find(); print("Pad:", "nalezen 1189:8890" if d else "nenalezen"); return
    d = None; layer = 0; kl = (layer+1)<<4
    cmd, *rest = a
    if cmd=="led": send(d,[[3,0xa1,1],[3,0xb0,0x18,int(rest[0])],[3,0xaa,0xa1]]); return
    k = KEYS[rest[0]]; msgs=[[3,0xfe,layer+1,1,1]]
    if cmd=="key":
        presses=[(0,0)]+[parse(t) for t in rest[1:6]]
        for i,(mod,code) in enumerate(presses): msgs.append([3,k,kl|1,len(presses)-1,i,mod,code,0,0])
    elif cmd=="media":
        c=MEDIA[rest[1]]; msgs.append([3,k,kl|2,c&0xff,c>>8,0,0,0,0])
    msgs.append([3,0xaa,0xaa]); send(d,msgs); print("OK")

if __name__=="__main__": main(sys.argv[1:])
