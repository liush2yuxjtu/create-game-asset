#!/usr/bin/env python3
"""Real-browser checks, not screenshot/code self-assessment. Requires Playwright + Pillow.
Install separately: python3 -m pip install playwright Pillow; python3 -m playwright install chromium.
"""
import argparse, base64, hashlib, io, json, time
from pathlib import Path
from urllib.parse import urljoin
from PIL import Image, ImageChops
from playwright.sync_api import sync_playwright

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--url',required=True)
    parser.add_argument('--out',default='verification/playground')
    args=parser.parse_args();out=Path(args.out);out.mkdir(parents=True,exist_ok=True)
    report={'url':args.url,'startedAt':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'runtime':'RUNNING','checks':[],'effects':[],'referenceParity':'NOT_RUN','artApproval':'PENDING','devicePerformance':'NOT_RUN'}
    errors=[];expected_errors=[]
    def check(name,condition,detail=''):
        report['checks'].append({'name':name,'status':'PASS' if condition else 'FAIL','detail':detail})
        assert condition, name+': '+str(detail)
    def pixels(page):
        data=page.locator('#stage').evaluate('(c)=>c.toDataURL("image/png").split(",")[1]')
        raw=base64.b64decode(data)
        return Image.open(io.BytesIO(raw)).convert('RGB')
    def diff(a,b):
        d=ImageChops.difference(a,b);return sum(1 for px in d.getdata() if max(px)>3)
    def seek(page,p):
        page.locator(f'[data-progress="{p}"]').click()
    with sync_playwright() as pw:
        browser=pw.chromium.launch(headless=True)
        context=browser.new_context(viewport={'width':1440,'height':1040},device_scale_factor=1)
        page=context.new_page();page.on('pageerror',lambda e:errors.append(str(e)))
        page.on('console',lambda m: errors.append('console: '+m.text) if m.type=='error' else None)
        try:
            page.goto(args.url,wait_until='networkidle')
            check('initial render',page.locator('.effect-card').count()==40)
            check('source index',page.locator('.source-row').count()>=59)
            r=context.request.get(urljoin(args.url,'../build-info.json'));check('build info',r.ok);report['build']=r.json()
            page.screenshot(path=str(out/'desktop.png'),full_page=True)
            page.locator('#telegraph').uncheck()
            ids=page.locator('#skill option').evaluate_all('(xs)=>xs.map(x=>x.value)')
            for aid in ids:
                page.locator('#skill').select_option(aid)
                samples={}
                for p in [0,20,49,80,100]:
                    seek(page,p);samples[p]=pixels(page)
                active={str(p):diff(samples[0],samples[p]) for p in [20,49,80]}
                check(aid+' active phases',min(active.values())>15,active)
                check(aid+' clean endpoint',diff(samples[0],samples[100])==0)
                check(aid+' phase differences',diff(samples[20],samples[49])>15 and diff(samples[49],samples[80])>15)
                seek(page,49);check(aid+' deterministic backward seek',diff(samples[49],pixels(page))==0)
                if aid in ['v01','v04','v17','v25','v34','ground-fire','ice-step','jade-guard']:
                    samples[49].save(out/(aid+'-49.png'))
                report['effects'].append({'id':aid,'activePixels':active,'endpoint':'PASS','backwardSeek':'PASS'})
            # A local module must actually generate pixels, not merely appear as an option.
            module="export default {id:'local-probe',name:'本地验证方块',duration:2,draw(g,t){if(t<=0||t>=2)return;g.fillStyle='#fe4177';g.fillRect(185+t*20,120,55,55);}};"
            page.locator('#plugin-file').set_input_files({'name':'probe.js','mimeType':'text/javascript','buffer':module.encode()})
            page.wait_for_function("document.querySelector('#stage').dataset.effect==='local-effect'")
            page.wait_for_function("document.querySelector('#stage').dataset.renderTime===document.querySelector('#stage').dataset.time")
            local_frame=pixels(page);check('local JS imported',page.locator('#notice').inner_text().startswith('已接入'))
            seek(page,0);page.wait_for_function("Number(document.querySelector('#stage').dataset.renderTime)===0")
            local_empty=pixels(page);check('local JS produces pixels',diff(local_frame,local_empty)>500)
            seek(page,100);page.wait_for_function("Number(document.querySelector('#stage').dataset.renderTime)===2")
            check('local JS cleanup',diff(local_empty,pixels(page))==0)
            page.locator('#remove-plugin').click();check('local JS removal',page.locator('#stage').get_attribute('data-effect')!='local-effect')
            page.locator('#plugin-file').set_input_files({'name':'bad.js','mimeType':'text/javascript','buffer':b'export default {id:"invalid"};'})
            page.wait_for_function("document.querySelector('#notice').textContent.includes('拒绝') || document.querySelector('#notice').textContent.includes('未接入')")
            check('invalid module rejected',page.locator('#stage').get_attribute('data-effect')!='local-effect')
            loop_code=b'export default {id:"timeout-probe",name:"Timeout probe",duration:2,draw(){while(true){}}};'
            page.locator('#plugin-file').set_input_files({'name':'timeout.js','mimeType':'text/javascript','buffer':loop_code})
            page.wait_for_function("document.querySelector('#notice').textContent.includes('超时')",timeout=7000)
            check('infinite worker terminated',page.locator('#stage').get_attribute('data-effect')!='local-effect')
            # Boundary rejects happen before module execution.
            page.locator('#plugin-file').set_input_files({'name':'large.js','mimeType':'text/javascript','buffer':b' '*65537})
            page.wait_for_function("document.querySelector('#notice').textContent.includes('64KB')")
            check('oversized import rejected',page.locator('#stage').get_attribute('data-effect')!='local-effect')
            page.locator('#skill').select_option('v01');seek(page,49)
            fhash=[]
            for fid in ['courtyard','crowd','bamboo','snow','night']:
                page.locator('#fixture').select_option(fid);img=pixels(page);fhash.append(hashlib.sha256(img.tobytes()).hexdigest());img.save(out/('fixture-'+fid+'.png'))
            check('five different rendered fixtures',len(set(fhash))==5)
            page.locator('#fixture').select_option('courtyard')
            original=pixels(page);page.locator('#stage').click(position={'x':240,'y':220});changed=pixels(page)
            check('pointer moves actual effect',diff(original,changed)>150)
            caster0=page.locator('#stage').get_attribute('data-caster');page.locator('#stage').press('ArrowRight');check('keyboard moves caster',page.locator('#stage').get_attribute('data-caster')!=caster0)
            page.locator('#reset-scene').click();page.locator('#telegraph').uncheck();seek(page,49)
            before=pixels(page);page.locator('#angle').fill('90');page.locator('#angle').dispatch_event('input');check('rotation changes pixels',diff(before,pixels(page))>100)
            before=pixels(page);page.locator('#scale').fill('0.6');page.locator('#scale').dispatch_event('input');check('scale changes pixels',diff(before,pixels(page))>100)
            before=pixels(page);page.locator('#effect-visible').uncheck();check('effect visibility changes pixels',diff(before,pixels(page))>100);page.locator('#effect-visible').check()
            before=pixels(page);page.locator('#grid').check();check('grid changes pixels',diff(before,pixels(page))>100);page.locator('#grid').uncheck()
            before=pixels(page);page.locator('#actors').uncheck();check('actors change pixels',diff(before,pixels(page))>100);page.locator('#actors').check()
            page.locator('#search').fill('no-match-zzzz');check('empty search visible',page.locator('#empty').is_visible());page.locator('#clear-filter').click()
            page.locator('#family').select_option('paper');check('family filter',page.locator('.effect-card:visible').count()==3);page.locator('#clear-filter').click();check('clear filter',page.locator('.effect-card:visible').count()==40)
            # URL state comes from actual interaction, then is loaded in a fresh page.
            seek(page,80);shared=page.url;state=page.locator('#stage').get_attribute('data-time');page.reload(wait_until='networkidle');check('shareable seek restored',page.locator('#stage').get_attribute('data-time')==state)
            page.locator('#reset-scene').click();page.locator('#skill').select_option('ground-fire');page.locator('#loop').uncheck();page.locator('#speed').select_option('2');page.locator('#replay').click()
            motion=[];wrapped=[]
            for i in range(13):
                page.wait_for_timeout(180);img=pixels(page);motion.append(hashlib.sha256(img.tobytes()).hexdigest());img.resize((480,300)).save(out/f'continuous-{i:02d}.png');wrapped.append(float(page.locator('#stage').get_attribute('data-time')))
            check('continuous playback has changing pixels',len(set(motion))>=6)
            check('nonloop stops at endpoint',page.locator('#stage').get_attribute('data-playing')=='false' and abs(float(page.locator('#stage').get_attribute('data-time'))-3.6)<.01)
            page.locator('#loop').check();page.locator('#replay').click();times=[]
            for _ in range(14):page.wait_for_timeout(170);times.append(float(page.locator('#stage').get_attribute('data-time')))
            check('loop wraps and keeps running',any(b<a for a,b in zip(times,times[1:])) and page.locator('#stage').get_attribute('data-playing')=='true',times)
            page.locator('#play').click();t0=page.locator('#stage').get_attribute('data-time');im0=pixels(page);page.wait_for_timeout(250)
            check('pause freezes clock and pixels',page.locator('#stage').get_attribute('data-time')==t0 and diff(im0,pixels(page))==0)
            page.locator('#speed').select_option('0.25');seek(page,20);t0=float(page.locator('#stage').get_attribute('data-time'));start=time.monotonic();page.locator('#play').click();page.wait_for_timeout(800);page.locator('#play').click();elapsed=time.monotonic()-start;dt=float(page.locator('#stage').get_attribute('data-time'))-t0
            check('quarter-speed clock advances at expected scale',.10<dt<.36,{'wallSeconds':elapsed,'effectSeconds':dt,'tolerance':'0.10–0.36 effect seconds for ~0.8 wall seconds plus automation overhead'})
            page.locator('#speed').select_option('1');seek(page,49)
            page.set_viewport_size({'width':390,'height':844});page.wait_for_timeout(100)
            check('390px no horizontal overflow',page.evaluate('document.documentElement.scrollWidth<=innerWidth'))
            check('mobile stage fully within viewport',page.locator('#stage').bounding_box()['width']<=390)
            page.screenshot(path=str(out/'mobile.png'),full_page=True)
            page.set_viewport_size({'width':1440,'height':1040});page.screenshot(path=str(out/'desktop-final.png'),full_page=True)
            # Every public source in the generated index really ships; src links stay repo links.
            index=context.request.get(urljoin(args.url,'source-index.json')).json();source_results=[]
            for f in index['files']:
                if f['path'].startswith('public/'):
                    resp=context.request.get(urljoin(args.url,f['url']));check('source '+f['path'],resp.ok and 'text/html' not in resp.headers.get('content-type',''))
                    source_results.append(f['path'])
            report['publicSourcesFetched']=len(source_results)
            r=context.request.get(urljoin(args.url,'../assets/qinglan/v2/qinglan-v2-runtime.zip'));check('legacy runtime ZIP accessible',r.ok and r.body()[:2]==b'PK');report['legacyZipSha256']=hashlib.sha256(r.body()).hexdigest()
            check('no application console errors',not errors,errors)
            report['runtime']='PASS';report['continuousEffectTimes']=wrapped
        except Exception as e:
            report['runtime']='FAIL';report['failure']=str(e)
            page.screenshot(path=str(out/'failure.png'),full_page=True)
            raise
        finally:
            report['consoleErrors']=errors
            (out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
            print(json.dumps({'runtime':report['runtime'],'checks':len(report['checks']),'effects':len(report['effects']),'failure':report.get('failure'),'report':str(out/'report.json')},ensure_ascii=False))
            context.close();browser.close()
if __name__=='__main__':main()
