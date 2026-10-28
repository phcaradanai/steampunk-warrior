"""Original Vesper score and effects. Offline synthesis, no sampled third-party audio."""
from array import array
from pathlib import Path
import math, random, wave
ROOT=Path(__file__).resolve().parents[1]/'game'/'audio'
RATE=22050
TAU=math.tau

def save(name,values,stereo=False):
 peak=max(abs(v) for v in values) or 1
 pcm=array('h',(int(max(-1,min(1,v/peak*.72))*32767) for v in values))
 path=ROOT/(name+'.wav')
 with wave.open(str(path),'wb') as f:
  f.setnchannels(2 if stereo else 1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(pcm.tobytes())
 return path

def music(name,bpm,melody,aggressive=False):
 beat=60/bpm;duration=beat*32;n=int(duration*RATE);mix=array('f',[0])*(n*2)
 def note(midi,start,length,gain,metal=False,pan=0):
  frequency=440*2**((midi-69)/12);samples=int(length*RATE)
  for i in range(samples):
   t=i/RATE;attack=min(1,t/.012);release=min(1,(length-t)/.14)
   env=attack*release*(math.exp(-t*4) if metal else .7+.3*math.exp(-t))
   value=math.sin(TAU*frequency*t)+.27*math.sin(TAU*frequency*(2.003 if metal else 2)*t)+.12*math.sin(TAU*frequency*(3.997 if metal else 3)*t)
   k=(int(start*RATE)+i)%n;mix[k*2]+=value*env*gain*(1-pan*.4);mix[k*2+1]+=value*env*gain*(1+pan*.4)
 chords=[(50,57,65),(46,53,62),(48,55,64),(45,52,61),(50,57,65),(46,53,62),(43,50,58),(45,52,61)]
 for bar,chord in enumerate(chords):
  for pitch in chord:note(pitch,bar*beat*4,beat*3.9,.055,False,-.3)
  for step in range(8):
   pitch=melody[(bar*8+step)%len(melody)]
   if pitch:note(pitch,bar*beat*4+step*beat/2,beat*.85,.12,True,.35)
   note(chord[step%3]+12,bar*beat*4+step*beat/2,beat*.4,.022,True,-.6)
  for step in range(4):
   start=int((bar*4+step)*beat*RATE);rng=random.Random(bar*8+step)
   for i in range(int(RATE*.11)):
    t=i/RATE;v=(math.sin(TAU*(70-220*t)*t)*.09+(rng.random()*2-1)*(.035 if aggressive else .012))*math.exp(-t*32)
    k=(start+i)%n;mix[k*2]+=v;mix[k*2+1]+=v
 save(name,mix,True)

music('city',88,[74,0,77,76,74,69,72,0,70,0,74,72,70,65,69,0,72,0,76,74,72,67,70,0,69,0,73,76,81,76,73,0])
music('combat',108,[62,74,69,74,65,77,69,74,58,70,65,70,62,74,65,70,60,72,67,72,64,76,67,72,57,69,64,69,61,73,64,73],True)
music('boss',116,[50,62,69,74,77,74,69,62,46,58,65,70,74,70,65,58,48,60,67,72,76,72,67,60,45,57,64,69,73,69,64,57],True)
for name,duration in [('ui',.065),('metal',.19),('electric',.25),('vent',.5),('heal',.45),('shield',.28),('victory',1.2),('defeat',1.0)]:
 rng=random.Random(name);values=[]
 for i in range(int(RATE*duration)):
  t=i/RATE;u=t/duration;envelope=min(1,t/.005)*(1-u)**2;noise=rng.random()*2-1
  if name=='ui':v=math.sin(TAU*880*t)*.4
  elif name=='metal':v=math.sin(TAU*530*t)+.5*math.sin(TAU*1371*t)+noise*.25
  elif name=='electric':v=math.sin(TAU*(210+1300*u)*t)*.6+noise*.3
  elif name=='vent':v=noise*.65*(.6+.4*math.sin(TAU*38*t))
  elif name=='heal':v=math.sin(TAU*(440+440*u)*t)+math.sin(TAU*660*t)*.3
  elif name=='shield':v=math.sin(TAU*(820-600*u)*t)*.6+noise*.4
  else:
   notes=[62,65,69,74] if name=='victory' else [62,58,53,50]
   pitch=notes[min(3,int(u*4))];freq=440*2**((pitch-69)/12);v=math.sin(TAU*freq*t)+math.sin(TAU*freq*2*t)*.2
  values.append(v*envelope)
 save(name,values)
print('Composed3 original loop scores and8 original sound effects.')
