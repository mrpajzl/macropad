#!/usr/bin/env python3
"""MacroPad CH552G (1189:8890) – lokální backend pro index.html.
Spuštění:  python3 server.py   → otevře http://localhost:8765
Závislosti: brew install libusb && pip3 install --user pyusb"""
import json, os, sys, time, webbrowser, threading
from http.server import HTTPServer, SimpleHTTPRequestHandler
import usb.core, usb.util

VID, PID, IFACE, EP_OUT, PORT = 0x1189, 0x8890, 1, 0x02, 8765
lock = threading.Lock()

def find():
    return usb.core.find(idVendor=VID, idProduct=PID)

def write_packets(packets):
    d = find()
    if d is None: raise RuntimeError("Pad nenalezen (1189:8890). Zkus jiný kabel / port.")
    try:
        if d.is_kernel_driver_active(IFACE): d.detach_kernel_driver(IFACE)
    except Exception: pass
    usb.util.claim_interface(d, IFACE)
    try:
        d.write(EP_OUT, bytes(64), 1000)                     # init (jako referenční tool)
        for p in packets:
            buf = bytes(p) + bytes(64 - len(p))
            d.write(EP_OUT, buf, 1000); time.sleep(0.015)
    finally:
        usb.util.release_interface(d, IFACE); usb.util.dispose_resources(d)

class H(SimpleHTTPRequestHandler):
    def log_message(self, *a): pass
    def _json(self, code, obj):
        b = json.dumps(obj).encode(); self.send_response(code)
        self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(b)))
        self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        if self.path == "/api/status":
            d = find(); return self._json(200, {"connected": d is not None, "name": "CH552G MacroPad 1189:8890" if d else None})
        return super().do_GET()
    def do_POST(self):
        if self.path != "/api/write": return self._json(404, {"error": "not found"})
        n = int(self.headers.get("Content-Length", 0)); body = json.loads(self.rfile.read(n) or b"{}")
        try:
            with lock: write_packets(body["packets"])
            self._json(200, {"ok": True, "sent": len(body["packets"])})
        except Exception as e:
            self._json(500, {"error": str(e)})

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    srv = HTTPServer(("127.0.0.1", PORT), H)
    print(f"MacroPad konfigurátor: http://localhost:{PORT}  (Ctrl+C = konec)")
    if "--no-browser" not in sys.argv: webbrowser.open(f"http://localhost:{PORT}")
    try: srv.serve_forever()
    except KeyboardInterrupt: pass
