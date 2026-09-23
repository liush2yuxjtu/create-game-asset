// Local JS is never imported into the app's origin. Opaque iframe + disposable worker.
// CSP blocks network, external imports, DOM access, cookies and storage. Watchdog kills hangs.
export class PluginHost {
 constructor(onFrame,onError){this.onFrame=onFrame;this.onError=onError;this.busy=false;this.seq=0;this.listener=e=>this.receive(e);window.addEventListener('message',this.listener);}
 dispose(){clearTimeout(this.timer);this.frame?.remove();this.frame=null;this.busy=false;this.reject?.(new Error('导入已取消'));this.reject=null;}
 destroy(){this.dispose();window.removeEventListener('message',this.listener);}
 fail(message){this.reject?.(new Error(message));this.reject=null;this.dispose();this.onError(message);}
 receive(e){if(!this.frame||e.source!==this.frame.contentWindow)return;const m=e.data;if(!m||typeof m!=='object')return;
  if(m.type==='boot'){this.frame.contentWindow.postMessage({type:'load',source:this.source},'*');return;}
  if(m.type==='error'){this.fail(String(m.message).slice(0,200));return;}
  if(m.type==='ready'){clearTimeout(this.timer);this.reject=null;this.resolve(m.meta);return;}
  if(m.type==='frame'&&m.bitmap instanceof ImageBitmap){if(m.seq!==this.seq){m.bitmap.close();return;}clearTimeout(this.timer);this.busy=false;this.onFrame(m.bitmap,m.time);}
 }
 async load(file){if(file.size>65536||!file.name.toLowerCase().endsWith('.js'))throw new Error('请选择不超过64KB的自包含 .js 模块。');const source=await file.text();this.dispose();this.source=source;
  const workerCode=`let asset; const canvas=new OffscreenCanvas(480,320); const ctx=canvas.getContext('2d');
self.onmessage=async e=>{try{const m=e.data;if(m.type==='load'){const u='data:text/javascript;charset=utf-8,'+encodeURIComponent(m.source);try{const mod=await import(u);asset=mod.default;if(!asset||typeof asset.id!=='string'||!/^[a-z][a-z0-9-]{0,63}$/.test(asset.id)||typeof asset.name!=='string'||!asset.name.trim()||asset.name.length>80||!Number.isFinite(asset.duration)||asset.duration<=0||asset.duration>30||typeof asset.draw!=='function')throw new Error('JS合同无效：default须提供id/name/duration/draw');postMessage({type:'ready',meta:{id:asset.id,name:asset.name,duration:asset.duration}});}finally{URL.revokeObjectURL(u);}}else if(m.type==='render'){canvas.width=480;asset.draw(ctx,m.time,m.options);const bitmap=canvas.transferToImageBitmap();postMessage({type:'frame',seq:m.seq,time:m.time,bitmap},[bitmap]);}}catch(e){postMessage({type:'error',message:e.message});}};`;
  const script=`const code=${JSON.stringify(workerCode)};const u=URL.createObjectURL(new Blob([code],{type:'text/javascript'}));const w=new Worker(u);URL.revokeObjectURL(u);w.onmessage=e=>{const m=e.data;parent.postMessage(m,'*',m.bitmap?[m.bitmap]:[]);};w.onerror=e=>parent.postMessage({type:'error',message:e.message||'插件运行失败'},'*');onmessage=e=>{if(e.source===parent)w.postMessage(e.data);};parent.postMessage({type:'boot'},'*');`;
  const frame=document.createElement('iframe');frame.hidden=true;frame.title='本地技能隔离沙箱';frame.setAttribute('sandbox','allow-scripts');frame.referrerPolicy='no-referrer';frame.srcdoc=`<!doctype html><meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline' blob: data:; worker-src blob:; connect-src 'none'; img-src 'none'; style-src 'none'; child-src 'none'; form-action 'none'; base-uri 'none'"><script>${script.replace(/<\/script/gi,'<\\/script')}<\/script>`;this.frame=frame;
  return new Promise((resolve,reject)=>{this.resolve=resolve;this.reject=reject;this.timer=setTimeout(()=>this.fail('插件加载超时，已终止沙箱。'),2500);document.body.append(frame);});
 }
 render(time,options){if(this.busy||!this.frame)return;this.busy=true;this.seq++;this.timer=setTimeout(()=>this.fail('插件绘制超时，已终止Worker。'),1500);this.frame.contentWindow.postMessage({type:'render',seq:this.seq,time,options},'*');}
}
