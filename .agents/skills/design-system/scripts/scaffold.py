#!/usr/bin/env python3
"""Create a draft in a NEW directory; no network, no installation, no overwrite."""
import argparse,json,shutil,sys
from pathlib import Path

def scaffold(dest,name,mode):
    dest=Path(dest)
    if not name.strip():raise ValueError('name must not be empty')
    if mode not in ('web','game'):raise ValueError('mode must be web or game')
    templates=Path(__file__).resolve().parents[1]/'assets/templates'
    files=['DESIGN.md','SCREEN.md','FLOW.md','VERIFY.md','system.json']
    if mode=='game':files.append('VFX_SPEC.json')
    # Prepare before mkdir so malformed templates cannot leave a half-written draft.
    contents={}
    for file in files:
        s=(templates/file).read_text(encoding='utf-8')
        if file.endswith('.json'):
            d=json.loads(s);d['name']=name
            if 'mode' in d:d['mode']=mode
            s=json.dumps(d,ensure_ascii=False,indent=2)+'\n'
        else:s=s.replace('{{name}}',name).replace('{{mode}}',mode)
        contents[file]=s
    dest.mkdir(parents=True,exist_ok=False)
    for file,s in contents.items():(dest/file).write_text(s,encoding='utf-8')
    return dest

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('output');p.add_argument('--name',required=True);p.add_argument('--mode',choices=['web','game'],default='web');a=p.parse_args()
    try:out=scaffold(a.output,a.name,a.mode)
    except (OSError,ValueError) as e:print(f'ERROR: {e}',file=sys.stderr);return 1
    print(f'DRAFT created: {out}. No source extraction or runtime verification performed.');return 0
if __name__=='__main__':sys.exit(main())
