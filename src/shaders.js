export const noiseGLSL = `
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){return .57*noise(p)+.28*noise(p*2.03)+.15*noise(p*4.07);}
`;
export const vertexShader=`varying vec2 vUv; void main(){vUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}`;
export const ribbonFragment=`
uniform float time,life,dissolve;uniform vec3 jade;varying vec2 vUv;
${noiseGLSL}
void main(){
 float ink=fbm(vec2(vUv.x*32.-time*1.8,vUv.y*10.));
 float edge=sin(vUv.y*3.14159);float taper=pow(sin(vUv.x*3.14159),.55);
 float a=smoothstep(.12,.5,edge+ink*.45)*taper;
 float erosion=smoothstep(dissolve-.08,dissolve+.08,ink);
 float strand=pow(max(0.,sin(vUv.y*68.+ink*8.)),12.);
 vec3 c=mix(jade*.18,jade*1.6,edge)+strand*vec3(.9,1.,.85);
 gl_FragColor=vec4(c,a*life*erosion*.8);if(gl_FragColor.a<.015)discard;
}`;
export const ringFragment=`
uniform float time,life,dissolve;uniform vec3 jade;varying vec2 vUv;
${noiseGLSL}
void main(){vec2 p=(vUv-.5)*2.;float r=length(p),angle=atan(p.y,p.x);
 float rings=exp(-abs(r-.82)*210.)+exp(-abs(r-.72)*160.)*.6+exp(-abs(r-.38)*170.)*.7;
 float ticks=step(.91,cos(angle*36.))*smoothstep(.64,.66,r)*(1.-smoothstep(.70,.72,r));
 float marks=step(.85,cos(angle*8.+time*.1))*smoothstep(.46,.48,r)*(1.-smoothstep(.59,.61,r));
 float n=fbm(p*18.+time*.08);float ink=smoothstep(.68,.83,r)*(1.-smoothstep(.85,.97,r))*(.2+n*.7);
 float a=(rings+ticks+marks*.65+ink)*life*smoothstep(dissolve-.08,dissolve+.08,n);
 gl_FragColor=vec4(mix(jade*.4,jade*1.3,clamp(rings,0.,1.)),a);if(a<.01)discard;
}`;
