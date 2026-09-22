#!/usr/bin/env python3
"""Check a design inventory; supplied evidence is not independently certified."""
import argparse,json,math,re,sys
from pathlib import Path
from urllib.parse import urlparse
STATUS={'PASS','FAIL','BLOCKED','NOT_RUN'}
EVIDENCE={'observed','inferred','proposed','unknown'}
SCOPES={'static','browser','engine','gameplay','device','art'}

def validate(folder):
    folder=Path(folder).resolve();errors=[];pending=[]
    def issue(condition,message):
        if not condition:errors.append(message)
    def finite(x):return isinstance(x,(int,float)) and not isinstance(x,bool) and math.isfinite(x)
    def local(path):
        if not isinstance(path,str) or not path:return False
        p=(folder/path).resolve()
        return p.is_relative_to(folder) and p.is_file()
    def indexed(items,label):
        out={}
        if not isinstance(items,list):errors.append(label+' must be a list');return out
        for item in items:
            if not isinstance(item,dict):errors.append(label+' entry must be an object');continue
            i=item.get('id');issue(isinstance(i,str) and bool(i),label+' missing id')
            if not isinstance(i,str):continue
            issue(i not in out,label+' duplicate id: '+i);out[i]=item
        return out
    def load(name):
        try:
            d=json.loads((folder/name).read_text(encoding='utf-8'))
            if not isinstance(d,dict):raise ValueError('root must be an object')
            return d
        except (OSError,ValueError) as e:errors.append(name+': '+str(e));return {}
    data=load('system.json')
    issue(data.get('schemaVersion')==1,'unsupported schemaVersion');issue(bool(data.get('name')),'missing name');issue(data.get('mode') in ('web','game'),'invalid mode')
    sources=indexed(data.get('sources',[]),'sources')
    for id,s in sources.items():
        url=s.get('url');path=s.get('path')
        if url:issue(isinstance(url,str) and urlparse(url).scheme in ('https','http') and bool(urlparse(url).netloc),id+': invalid URL')
        elif path:issue(local(path),id+': missing or outside-root source file')
        else:errors.append(id+': URL or local path required')
        issue(bool(s.get('revision') or s.get('captured_at')),id+': revision or capture date required')
    def evidence(ev,label):
        issue(isinstance(ev,list) and bool(ev),label+': evidence required')
        if not isinstance(ev,list):return
        for e in ev:
            if not isinstance(e,dict):errors.append(label+': invalid evidence entry');continue
            issue(e.get('source_id') in sources,label+': unresolved source_id');issue(bool(e.get('locator')),label+': missing evidence locator')
            if e.get('artifact'):issue(local(e['artifact']),label+': missing local evidence artifact')
    tokens=data.get('tokens',{})
    if not isinstance(tokens,dict):errors.append('tokens must be an object');tokens={}
    if not tokens:pending.append('no tokens extracted')
    for id,t in tokens.items():
        if not isinstance(t,dict):errors.append('invalid token '+id);continue
        status=t.get('classification');issue(status in EVIDENCE,id+': invalid classification');issue(bool(t.get('kind')),id+': missing kind')
        if status=='observed':evidence(t.get('evidence'),id)
        if status in ('inferred','proposed'):issue(bool(t.get('rationale')),id+': rationale required')
        if t.get('value') is None or status=='unknown':pending.append(id+': unknown token')
    def resolve(id,stack):
        if id in stack:errors.append('token alias cycle: '+' -> '.join(stack+[id]));return
        t=tokens.get(id)
        if not isinstance(t,dict):errors.append('unresolved token alias: '+id);return
        v=t.get('value')
        if isinstance(v,str) and re.fullmatch(r'\{[^{}]+\}',v):
            target=v[1:-1];target_token=tokens.get(target)
            if isinstance(target_token,dict):issue(t.get('kind')==target_token.get('kind'),id+': alias type mismatch')
            resolve(target,stack+[id])
    for id in tokens:resolve(id,[])
    screens=indexed(data.get('screens',[]),'screens')
    if not screens:pending.append('no screens documented')
    for id,s in screens.items():
        status=s.get('status');issue(status in ('implemented','proposed','unknown'),id+': invalid screen status')
        if status=='implemented':evidence(s.get('evidence'),id)
        else:pending.append(id+': screen not implemented')
    flows=indexed(data.get('flows',[]),'flows')
    for id,f in flows.items():
        steps=f.get('screens');issue(isinstance(steps,list) and bool(steps),id+': flow needs screen IDs')
        if isinstance(steps,list):
            for step in steps:issue(isinstance(step,str) and step in screens,id+': unresolved screen '+str(step))
    checks=indexed(data.get('checks',[]),'checks')
    if not checks:pending.append('no checks declared')
    for id,c in checks.items():
        issue(c.get('scope') in SCOPES,id+': invalid scope');issue(c.get('status') in STATUS,id+': invalid check status')
        if c.get('status')=='PASS':evidence(c.get('evidence'),id)
        else:pending.append(id+': '+str(c.get('status')))
    if (folder/'VFX_SPEC.json').exists():
        v=load('VFX_SPEC.json');duration=v.get('duration_seconds');states=v.get('states',[])
        if duration is None:pending.append('VFX duration unknown')
        else:
            issue(finite(duration) and duration>0,'VFX duration must be finite and positive')
            state_map=indexed(states,'VFX states');issue(bool(state_map),'VFX states required')
            previous=0
            for id,s in state_map.items():
                a,b=s.get('start'),s.get('end')
                if not(finite(a) and finite(b)):errors.append(id+': non-finite timeline');continue
                issue(abs(a-previous)<1e-6 and b>a,id+': timeline gap, overlap or reverse interval');previous=b
            if finite(duration):issue(abs(previous-duration)<1e-6,'VFX timeline must end at duration')
        layers=v.get('layers',[]);issue(isinstance(layers,list) and all(isinstance(x,str) for x in layers),'VFX layers must be strings')
        if isinstance(layers,list) and all(isinstance(x,str) for x in layers):issue(len(layers)==len(set(layers)),'duplicate VFX layer')
        for id,e in indexed(v.get('events',[]),'VFX events').items():
            t=e.get('at');issue(finite(t) and finite(duration) and 0<=t<=duration,id+': event outside timeline')
            issue(e.get('binding') in ('visual-only','proposed','implemented'),id+': invalid binding')
        runtime=v.get('runtime',{});vr=v.get('verification',{})
        issue(isinstance(runtime,dict),'runtime must be an object');issue(isinstance(vr,dict),'verification must be an object')
        if isinstance(vr,dict):
            for scope,status in vr.items():
                issue(scope in SCOPES and status in STATUS,'invalid VFX verification')
                if status=='PASS':
                    issue(any(c.get('scope')==scope and c.get('status')=='PASS' for c in checks.values()),scope+': VFX PASS needs matching evidence-backed check')
                    if scope=='engine' and isinstance(runtime,dict):issue(all(runtime.get(k) for k in ['target_engine','version','renderer','scene']),'engine PASS needs actual engine/version/renderer/scene')
                else:pending.append('VFX '+scope+': '+str(status))
    return {'integrity':'FAIL' if errors else 'PASS','readiness':'NOT_READY' if errors or pending else 'READY','errors':errors,'pending':pending,'limits':'Evidence references only; no live fetch, image review, engine execution or artistic certification.'}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('folder');p.add_argument('--require-ready',action='store_true');a=p.parse_args()
    try:r=validate(a.folder)
    except (TypeError,ValueError,KeyError) as e:r={'integrity':'FAIL','readiness':'NOT_READY','errors':['malformed input: '+str(e)],'pending':[]}
    print(json.dumps(r,ensure_ascii=False,indent=2))
    return 1 if r['integrity']=='FAIL' or (a.require_ready and r['readiness']!='READY') else 0
if __name__=='__main__':sys.exit(main())
