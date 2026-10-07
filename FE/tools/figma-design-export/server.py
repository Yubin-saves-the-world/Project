from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import json, base64, secrets
ROOT=Path('/Users/yubin/StudioProjects/FE')
OUT=ROOT/'docs/figma-reference/current'
KEY=(ROOT/'tools/figma-design-export/key.txt').read_text() if (ROOT/'tools/figma-design-export/key.txt').exists() else secrets.token_hex(16)
(ROOT/'tools/figma-design-export/key.txt').write_text(KEY)
class Handler(BaseHTTPRequestHandler):
 def cors_headers(self):
  self.send_header('Access-Control-Allow-Origin','*')
  self.send_header('Access-Control-Allow-Headers','Content-Type, X-Export-Key')
  self.send_header('Access-Control-Allow-Methods','POST, OPTIONS, GET')
  self.send_header('Access-Control-Allow-Private-Network','true')
 def do_OPTIONS(self):
  self.send_response(204);self.cors_headers();self.end_headers()
 def do_POST(self):
  if self.headers.get('X-Export-Key')!=KEY:
   self.send_response(403);self.cors_headers();self.end_headers();return
  data=json.loads(self.rfile.read(int(self.headers.get('Content-Length','0'))))
  (OUT/'design.json').write_text(json.dumps(data['design'],ensure_ascii=False,indent=2))
  for name,raw in data['files'].items():
   if not all(c.isalnum() or c in '._-' for c in name):continue
   folder=ROOT/'assets/icons/figma' if name.endswith('.svg') or name.startswith('figma-') else OUT
   (folder/name).write_bytes(base64.b64decode(raw))
  self.send_response(200);self.cors_headers();self.end_headers();self.wfile.write(b'{"ok":true}')
  print('Export saved:',len(data['design']['screens']),'screens,',len(data['files']),'files',flush=True)
 def log_message(self,*args):pass
HTTPServer(('127.0.0.1',8766),Handler).serve_forever()
