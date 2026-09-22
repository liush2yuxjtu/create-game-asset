"""Validate the actual distributable against canonical source and metadata."""
import hashlib,json,struct,zipfile
from pathlib import Path
root=Path(__file__).resolve().parent.parent
sha=lambda b:hashlib.sha256(b).hexdigest()
model=root/'public/assets/qinglan/v1/qinglan-sword-formation.glb'
b=model.read_bytes()
assert sha(b)=='05abf3a6468c29b82731f791aa0d097dab45dc7bc54d1f5a644f0b3fcc95865c','V1 changed'
magic,version,length=struct.unpack_from('<4sII',b)
assert magic==b'glTF' and version==2 and length==len(b),'Invalid GLB'
n=struct.unpack_from('<I',b,12)[0];g=json.loads(b[20:20+n])
names=[x.get('name','') for x in g['nodes']]
assert names.count('main-sword')==1
assert len([x for x in names if x.startswith('flying-sword-')])==6
assert len(g['animations'])==1
end=max(g['accessors'][s['input']]['max'][0] for s in g['animations'][0]['samplers'])
assert abs(end-3.2)<1e-5,'Animation duration drift'
folder=root/'public/assets/qinglan/v2'
spec=json.loads((folder/'asset-spec.json').read_text())
assert spec['duration_seconds']==3.2 and spec['identity']['flying_swords']==6
assert [(s['id'],s['start'],s['end']) for s in spec['states']]==[('charge',0,1.1),('slash',1.1,1.8),('dissipate',1.8,3.2)]
files={
 'models/qinglan-v1-source.glb':model,
 **{f'runtime/{n}':root/'src'/n for n in ['qinglan-vfx.js','timeline.js','shaders.js']},
 'sprites/ink-burst-atlas.png':folder/'ink-burst-atlas.png',
 'sprites/sprite-manifest.json':folder/'sprite-manifest.json',
 'INTEGRATION.md':root/'docs/qinglan-v2.md',
 'THREE-LICENSE.txt':root/'node_modules/three/LICENSE'
}
with zipfile.ZipFile(folder/'qinglan-v2-runtime.zip') as z:
 assert z.testzip() is None
 m=json.loads(z.read('manifest.json'))
 expected=set(files)|{'asset-spec.json'}
 assert set(m['sha256'])==expected
 assert set(z.namelist())==expected|{'manifest.json'},'Unexpected or missing files'
 for name,h in m['sha256'].items():assert sha(z.read(name))==h,name+' hash mismatch'
 for name,p in files.items():assert z.read(name)==p.read_bytes(),name+' differs from source'
 packed_spec=json.loads(z.read('asset-spec.json'))
 spec['canonical_reference']='models/qinglan-v1-source.glb'
 assert packed_spec==spec
 assert m['entry']=='runtime/qinglan-vfx.js' and m['runtime']=='three@0.170.0'
 assert m['v2_effects_require_runtime'] is True and m['glb_is_v1_source'] is True
 png=z.read('sprites/ink-burst-atlas.png')
 assert png[:8]==b'\x89PNG\r\n\x1a\n'
 assert struct.unpack_from('>II',png,16)==(512,512) and png[24:26]==bytes([8,6])
 sprite=json.loads(z.read('sprites/sprite-manifest.json'))
 assert len(sprite['frames'])==16 and sprite['alpha']=='straight'
 for i,f in enumerate(sprite['frames']):assert (f['index'],f['x'],f['y'],f['w'],f['h'])==(i,(i%4)*128,(i//4)*128,128,128)
print('PASS: canonical V1, sword identity, 3.2s clip, asset states, exact ZIP inventory, source equality, SHA-256, RGBA atlas and frames')
