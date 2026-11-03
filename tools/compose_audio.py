"""Original Vesper score and effects. Offline synthesis, no sampled third-party audio."""
from array import array
from pathlib import Path
import math, random, wave
ROOT=Path(__file__).resolve().parents[1]/'game'/'audio'
RATE=22050
TAU=math.tau

def save(name,values,stereo=False,rms=None):
 peak=max(abs(v) for v in values) or 1
 if rms:
  # Area scores match the loudness of the first three (RMS ~.16); tanh keeps peaks below clipping.
  gain=rms/(math.sqrt(sum(v*v for v in values)/len(values)) or 1);values=[math.tanh(v*gain*1.15)/1.15 for v in values];peak=.72
 pcm=array('h',(int(max(-1,min(1,v/peak*.72))*32767) for v in values))
 path=ROOT/(name+'.wav')
 with wave.open(str(path),'wb') as f:
  f.setnchannels(2 if stereo else 1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(pcm.tobytes())
 return path

CHORDS=[(50,57,65),(46,53,62),(48,55,64),(45,52,61),(50,57,65),(46,53,62),(43,50,58),(45,52,61)]
def tri(root,minor):return (root,root+7,root+12+(3 if minor else 4))

def music(name,bpm,melody,aggressive=False,chords=CHORDS,bars=8,kick=(1,1,1,1),tick=0,drone=0,bell=0,drip=0,area=False):
 beat=60/bpm;duration=beat*4*bars;n=int(duration*RATE);mix=array('f',[0])*(n*2)
 def note(midi,start,length,gain,metal=False,pan=0):
  frequency=440*2**((midi-69)/12);samples=int(length*RATE)
  for i in range(samples):
   t=i/RATE;attack=min(1,t/.012);release=min(1,(length-t)/.14)
   env=attack*release*(math.exp(-t*4) if metal else .7+.3*math.exp(-t))
   value=math.sin(TAU*frequency*t)+.27*math.sin(TAU*frequency*(2.003 if metal else 2)*t)+.12*math.sin(TAU*frequency*(3.997 if metal else 3)*t)
   k=(int(start*RATE)+i)%n;mix[k*2]+=value*env*gain*(1-pan*.4);mix[k*2+1]+=value*env*gain*(1+pan*.4)
 chords=[(50,57,65),(46,53,62),(48,55,64),(45,52,61),(50,57,65),(46,53,62),(43,50,58),(45,52,61)]
 for bar in range(bars):
  chord=chords[bar%len(chords)]
  for pitch in chord:note(pitch,bar*beat*4,beat*3.9,.055,False,-.3)
  for step in range(8):
   pitch=melody[(bar*8+step)%len(melody)]
   if pitch:note(pitch,bar*beat*4+step*beat/2,beat*.85,.12,True,.35)
   note(chord[step%3]+12,bar*beat*4+step*beat/2,beat*.4,.022,True,-.6)
  if drone:note(drone,bar*beat*4,beat*3.95,.07,False,0)
  if bell:
   for b in (0,2):note(chord[0]+bell,bar*beat*4+b*beat,beat*1.6,.1,True,.2)
  for k in range(drip):
   r=random.Random(bar*31+k);note(r.choice((81,84,86,88,91)),bar*beat*4+r.random()*beat*3.6,beat*.5,.05,True,r.random()*1.6-.8)
  if tick:
   for step in range(8):
    r=random.Random(bar*9+step);start=int((bar*4+step/2)*beat*RATE)
    for i in range(int(RATE*.04)):
     v=(r.random()*2-1)*tick*math.exp(-i/RATE*90);k=(start+i)%n;mix[k*2]+=v;mix[k*2+1]+=v
  for step in range(4):
   if not kick[step]:continue
   start=int((bar*4+step)*beat*RATE);rng=random.Random(bar*8+step)
   for i in range(int(RATE*.11)):
    t=i/RATE;v=(math.sin(TAU*(70-220*t)*t)*.09+(rng.random()*2-1)*(.035 if aggressive else .012))*math.exp(-t*32)
    k=(start+i)%n;mix[k*2]+=v;mix[k*2+1]+=v
 if area:save(name,[(mix[i*2]+mix[i*2+1])/2 for i in range(n)],False,.16)
 else:save(name,mix,True)

music('city',88,[74,0,77,76,74,69,72,0,70,0,74,72,70,65,69,0,72,0,76,74,72,67,70,0,69,0,73,76,81,76,73,0])
music('combat',108,[62,74,69,74,65,77,69,74,58,70,65,70,62,74,65,70,60,72,67,72,64,76,67,72,57,69,64,69,61,73,64,73],True)
music('boss',116,[50,62,69,74,77,74,69,62,46,58,65,70,74,70,65,58,48,60,67,72,76,72,67,60,45,57,64,69,73,69,64,57],True)
AREAS={
 'hub':dict(bpm=94,bars=24,chords=[tri(53,0),tri(48,0),tri(50,1),tri(46,0),tri(53,0),tri(48,0),tri(46,0),tri(48,0)],tick=.018,
  melody=[77,0,81,79,77,72,74,0,72,0,77,76,74,69,72,0,74,0,77,74,70,74,77,0,72,0,76,79,81,79,76,0]),
 'canal':dict(bpm=72,bars=18,chords=[tri(50,1),tri(46,0),tri(43,1),tri(45,1),tri(50,1),tri(46,0)],kick=(1,0,0,0),drone=38,drip=3,
  melody=[74,0,0,0,69,0,0,0,0,0,72,0,0,0,65,0,70,0,0,0,74,0,0,0,0,0,69,0,0,72,0,0]),
 'rail':dict(bpm=116,bars=32,chords=[tri(52,1),tri(48,0),tri(45,1),tri(47,0)],tick=.05,aggressive=True,
  melody=[64,64,67,64,69,64,67,64,60,60,64,60,67,60,64,60,57,57,60,57,64,57,60,57,59,59,62,59,66,59,62,59]),
 'lab':dict(bpm=88,bars=24,chords=[tri(45,1),tri(41,0),tri(48,0),tri(43,1)],kick=(1,0,1,0),drip=6,
  melody=[69,72,76,72,81,76,72,69,70,74,77,74,82,77,74,70,72,76,79,76,84,79,76,72,67,71,74,71,79,74,71,67]),
 'foundry':dict(bpm=88,bars=24,chords=[tri(48,1),tri(44,0),tri(51,0),tri(46,0)],bell=12,aggressive=True,tick=.025,
  melody=[60,0,63,0,67,0,63,0,56,0,60,0,63,0,60,0,63,0,67,0,70,0,67,0,58,0,62,0,65,0,62,0]),
 'archive':dict(bpm=76,bars=20,chords=[tri(44,1),tri(40,0),tri(47,0),tri(42,1),tri(44,1)],kick=(0,0,0,0),drone=32,bell=24,drip=2,
  melody=[80,0,0,0,83,0,0,0,78,0,0,0,76,0,0,0,80,0,0,83,0,0,87,0,85,0,0,0,83,0,0,0]),
 'ending':dict(bpm=72,bars=20,chords=[tri(48,0),tri(55,0),tri(45,1),tri(53,0),tri(48,0)],kick=(1,0,1,0),drone=36,bell=12,
  melody=[76,0,79,0,84,0,79,76,77,0,81,0,84,0,81,77,76,0,79,0,81,0,79,76,74,0,77,0,79,0,0,0]),
}
if __name__=='__main__':
 import sys
 for name,args in AREAS.items():
  if len(sys.argv)<2 or name in sys.argv[1:]:
   args=dict(args);music(name,args.pop('bpm'),args.pop('melody'),area=True,**args)
 if len(sys.argv)>1:sys.exit()
EXTRA=[('shot',.22),('charge',.6),('heavy',.45),('whoosh',.38),('burn',.45),('acid',.42)]
for name,duration in [('ui',.065),('metal',.19),('electric',.25),('vent',.5),('heal',.45),('shield',.28),('victory',1.2),('defeat',1.0)]+EXTRA:
 rng=random.Random(name);values=[];lp=0
 for i in range(int(RATE*duration)):
  t=i/RATE;u=t/duration;envelope=min(1,t/.005)*(1-u)**2;noise=rng.random()*2-1
  if name=='charge':envelope=min(1,t/.02)*u**1.4*min(1,(1-u)/.04)
  elif name in ('whoosh','burn','acid'):envelope=math.sin(math.pi*u)**(1.5 if name=='whoosh' else .7)
  if name=='ui':v=math.sin(TAU*880*t)*.4
  elif name=='metal':v=math.sin(TAU*530*t)+.5*math.sin(TAU*1371*t)+noise*.25
  elif name=='electric':v=math.sin(TAU*(210+1300*u)*t)*.6+noise*.3
  elif name=='vent':v=noise*.65*(.6+.4*math.sin(TAU*38*t))
  elif name=='heal':v=math.sin(TAU*(440+440*u)*t)+math.sin(TAU*660*t)*.3
  elif name=='shot':v=math.sin(TAU*(1400-1100*u)*t)*.5+noise*.7*math.exp(-u*9)
  elif name=='charge':v=math.sin(TAU*(140+900*u*u)*t)*.55+math.sin(TAU*(280+1800*u*u)*t)*.25*(.5+.5*math.sin(TAU*24*t))+noise*.08
  elif name=='heavy':v=math.sin(TAU*(95-60*u)*t)*1.1+noise*.8*math.exp(-u*14)+math.sin(TAU*310*t)*.3*math.exp(-u*8)
  elif name=='whoosh':
   lp+=(noise-lp)*(.06+.5*math.sin(math.pi*u));v=lp*3
  elif name=='burn':v=noise*(1 if rng.random()<.35 else .15)*.6+math.sin(TAU*95*t)*.3
  elif name=='acid':v=math.sin(TAU*(300+500*((u*7)%1))*t)*.4*(1 if math.sin(TAU*17*t)>0 else .3)+noise*.25
  elif name=='shield':v=math.sin(TAU*(820-600*u)*t)*.6+noise*.4
  else:
   notes=[62,65,69,74] if name=='victory' else [62,58,53,50]
   pitch=notes[min(3,int(u*4))];freq=440*2**((pitch-69)/12);v=math.sin(TAU*freq*t)+math.sin(TAU*freq*2*t)*.2
  values.append(v*envelope)
 save(name,values)
print('Composed original loop scores and sound effects.')
