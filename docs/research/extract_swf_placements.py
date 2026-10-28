from pathlib import Path
import struct,json,hashlib
b=Path('reference/sinjid/uncompressed.swf').read_bytes()
class Bits:
 def __init__(self,d,p=0):self.d=d;self.bit=p*8
 def u(self,n):
  v=0
  for _ in range(n):v=(v<<1)|((self.d[self.bit//8]>>(7-self.bit%8))&1);self.bit+=1
  return v
 def s(self,n):
  x=self.u(n);return x-(1<<n) if n and x&(1<<(n-1)) else x
 def end(self):return (self.bit+7)//8
r=Bits(b,8);n=r.u(5);rect=[r.s(n) for _ in range(4)];pos=r.end();fps=struct.unpack_from('<H',b,pos)[0]/256;declframes=struct.unpack_from('<H',b,pos+2)[0];pos+=4
def matrix(d,p):
 r=Bits(d,p);sx=sy=1.;r0=r1=0.
 if r.u(1):n=r.u(5);sx=r.s(n)/65536;sy=r.s(n)/65536
 if r.u(1):n=r.u(5);r0=r.s(n)/65536;r1=r.s(n)/65536
 n=r.u(5);tx=r.s(n)/20;ty=r.s(n)/20
 return {'scale_x':sx,'scale_y':sy,'rotate_skew_0':r0,'rotate_skew_1':r1,'x':tx,'y':ty},r.end()
def cxform(d,p):
 r=Bits(d,p);ha=r.u(1);hm=r.u(1);n=r.u(4)
 for _ in range(4*(ha+hm)):r.s(n)
 return r.end()
def tags(d,p):
 while p<len(d):
  x=struct.unpack_from('<H',d,p)[0];p+=2;t=x>>6;l=x&63
  if l==63:l=struct.unpack_from('<I',d,p)[0];p+=4
  yield t,d[p:p+l];p+=l
  if t==0:break
snapshots={};sprites={};labels={};display={};frame=1;unknown=[];tag_counts={}
for tag,d in tags(b,pos):
 tag_counts[tag]=tag_counts.get(tag,0)+1
 if tag in (4,70):unknown.append({'tag':tag,'frame':frame})
 if tag==39:
  ident,nf=struct.unpack_from('<HH',d,0);sprites[ident]={'frames':nf,'data':d[4:]}
 if tag==26:
  fl=d[0];dep=struct.unpack_from('<H',d,1)[0];p=3;o=dict(display.get(dep,{})) if fl&1 else {}
  if fl&2:o['character_id']=struct.unpack_from('<H',d,p)[0];p+=2
  if fl&4:o['matrix'],p=matrix(d,p)
  if fl&8:p=cxform(d,p)
  if fl&16:o['ratio']=struct.unpack_from('<H',d,p)[0];p+=2
  if fl&32:end=d.index(0,p);o['name']=d[p:end].decode(errors='replace');p=end+1
  o['depth']=dep;display[dep]=o
 if tag==28:display.pop(struct.unpack_from('<H',d,0)[0],None)
 if tag==5:display.pop(struct.unpack_from('<H',d,2)[0],None)
 if tag==43:labels[frame]=d.split(b'\0')[0].decode()
 if tag==1:
  if frame in [3,7,8,9,10,11,12,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,85,88,90,91]:snapshots[frame]=list(display.values())
  frame+=1
sprite_labels={}
for ident,sprite in sprites.items():
 frame_num=1;sl={}
 for t,payload in tags(sprite['data'],0):
  if t==43:sl[payload.split(b'\0')[0].decode()]=frame_num
  if t==1:frame_num+=1
 if sl:sprite_labels[ident]=sl
assert rect==[0,12000,0,9400] and fps==24.0 and declframes==323
assert len([x for x in labels.values() if x.startswith('Arena')])==11
assert not unknown
out={'sprite_labels':sprite_labels,'top_level_tag_counts':tag_counts,'source':'direct SWF header / PlaceObject2 / RemoveObject2 / FrameLabel decode, not runtime positions','rect_twips':rect,'fps':fps,'declared_frames':declframes,'labels':labels,'snapshots':snapshots,'unsupported_placement_tags':unknown}
Path('docs/research/sinjid-npc-placements.json').write_text(json.dumps(out,indent=2)+'\n')
print('rect',rect,'fps',fps,'frames',declframes)
print('placements indexed',len(snapshots),'snapshots',len(sprite_labels),'labeled sprites')
