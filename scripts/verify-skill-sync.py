"""Check installed project skills against reviewed pinned file manifests; no network."""
import hashlib,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
for name,spec in json.loads((root/'skills.lock.json').read_text()).items():
 folder=root/spec['destination'];assert folder.is_dir(),name+' missing'
 actual={p.relative_to(folder).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(folder.rglob('*')) if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc'}
 assert actual==spec['sha256'],name+' differs from pinned source; reconcile before updating lock'
 print('PASS:',name,spec['revision'],len(actual),'file hashes')
