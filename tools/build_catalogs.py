"""Materialize the approved original content plan as Godot runtime catalogs."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
plan=json.loads((ROOT/'docs/design/steampunk-content-plan.json').read_text())
out=ROOT/'game/data'
def emit(kind,data):
 (out/f'{kind}.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
classes=[]
for c in plan['classes']:
 row=dict(c);row['attributes']={k:c[k] for k in ['VIT','STR','INT','AGI']};classes.append(row)
emit('classes',classes)
# Effects are data consumed by the one shared combat resolver.
effects={
'S01':dict(power=1.25,damage_type='physical',shield_multiplier=1.5),
'S02':dict(power=.70,hits=2,damage_type='physical'),
'S03':dict(power=1.10,damage_type='physical',status='Marked',duration=2),
'S04':dict(power=1.25,damage_type='electric'),
'S05':dict(power=.85,damage_type='physical'),
'S06':dict(power=.95,damage_type='electric'),
'S07':dict(power=1.8,damage_type='physical',armor_ignore=.5),
'S08':dict(power=.7,damage_type='chemical',status='Corroded',duration=2),
'S09':dict(heal=1.3),
'S10':dict(status='Haste',duration=2),
'S11':dict(barrier=1.5),
'S12':dict(summon=True,drone_power=.5,drone_actions=3),
'S13':dict(power=1.5,damage_type='physical',marked_multiplier=1.5),
'S14':dict(power=1.6,damage_type='thermal',status='Heated',duration=2),
'S15':dict(power=2.1,damage_type='electric',stagger_wet=True),
'S16':dict(power=1.5,damage_type='physical',low_hp_multiplier=1.5),
'S17':dict(passive='max_hp',per_rank=.02),
'S18':dict(passive='max_fp',per_rank=.02),
'S19':dict(passive='initiative',per_rank=1),
'S20':dict(power=.5,damage_type='chemical',status='Wet',duration=2),
'S21':dict(power=1.,damage_type='chemical',status='Sealed',duration=2),
'S22':dict(barrier=.5,remove_status='Heated',cooldown=2)}
skills=[]
for s in plan['skills']:
 row=dict(s);row['parents']=s['parents'].split(',') if s['parents'] else [];row['rank_cap']=10;row['effects']=effects[s['id']];skills.append(row)
descriptions=[
'โจมตีเดี่ยว ทำความเสียหายต่อโล่เพิ่ม50%',
'โจมตีสองครั้ง ถ้าโล่แตกจากครั้งแรก ครั้งถัดไปถึงร่างกายได้',
'ยิงเป้าหมายพร้อมทำเครื่องหมายเพื่อเตรียมท่าต่อเนื่อง',
'ปล่อยไฟฟ้าใส่เป้าหมาย เปียกทำให้รับไฟฟ้าแรงขึ้น',
'ยิงกระจายใส่ศัตรูทุกตัว',
'ปล่อยไฟฟ้าผ่านศัตรูทุกตัว',
'กระแทกเดี่ยวโดยไม่นับเกราะกายภาพครึ่งหนึ่ง',
'ปล่อยหมอกกรดใส่ทุกตัว ทำให้เกราะผุ',
'ฟื้น HP ของตน ถูกหยุดได้ด้วยสถานะปิดการฟื้นฟู',
'เร่งลำดับเทิร์นของตน ไม่มีเทิร์นแถมในรอบเดียวกัน',
'สร้างโล่รับแรงกระแทกก่อนถึงร่างกาย',
'เรียกโดรนยิงตามหลัง3คำสั่งของเจ้าของ ไม่กินเทิร์นแยก',
'ยิงเป้าหมายที่มีเครื่องหมายแรงขึ้น50% แล้วใช้เครื่องหมายนั้น',
'โจมตีความร้อน ทำให้เสียHPเมื่อจบเทิร์น',
'ปลดประจุแรงสูง ถ้าเป้าเปียกจะเสียจังหวะหนึ่งเทิร์น',
'โจมตีฉุกเฉิน แรงขึ้น50%เมื่อHPไม่เกิน35%',
'ติดตัว เพิ่มHPสูงสุด2%ต่อระดับ',
'ติดตัว เพิ่มFPสูงสุด2%ต่อระดับ',
'ติดตัว เพิ่มค่าลำดับเทิร์น1ต่อระดับ',
'พ่นละอองเปียกใส่ทุกตัวเพื่อเปิดคอมโบไฟฟ้า',
'โจมตีเคมีและปิดการฟื้นฟูของเป้าหมาย',
'ลดแรงดัน40 ล้างความร้อนและสร้างโล่เล็กน้อย']
for skill,description in zip(skills,descriptions):skill['description_th']=description
emit('skills',skills)
items=[]
group_indices={}
for i,g in enumerate(plan['equipment']):
 row={k:v for k,v in g.items() if k!='differentiation'};tier=g['tier'];local=int(g['id'][1:]);slot=g['slot'];bonuses={}
 group=(slot,tier);variant=group_indices.get(group,0);group_indices[group]=variant+1
 if slot=='weapon':
  attack,tech,speed=[(7,1,0),(1,7,0),(5,5,1),(9,0,-2),(0,9,-2),(3,3,4)][variant]
  bonuses={'attack':tier*attack,'tech':tier*tech,'initiative':speed}
 elif slot=='shield':
  barrier,armor,resist,speed=[(12,3,2,0),(20,2,1,-1),(8,1,5,1),(9,5,3,-2)][variant]
  bonuses={'barrier':15+tier*barrier,'armor':tier*armor,'resist':tier*resist,'initiative':speed}
 elif slot=='head':
  bonuses={'max_fp':tier*(5+variant*2),'initiative':3-variant,'resist':tier*(2+variant)}
 else:
  hp,armor,resist=[(12,4,3),(8,2,6),(16,3,2)][variant]
  bonuses={'max_hp':tier*hp,'armor':tier*armor,'resist':tier*resist}
 row['bonuses']=bonuses;row['special']='vent_breaker' if g['id']=='W26' else ('condensate_barrier' if g['id']=='A09' else '')
 row['description']={'weapon':'อาวุธสำหรับปรับสมดุลการโจมตีและเทคโนโลยี','shield':'โล่รับแรงกระแทกก่อนถึงร่างกาย','head':'อุปกรณ์มองเห็นและป้องกันไอเอเธอร์','suit':'เสื้อป้องกันสำหรับคนทำงานนอกกำแพง'}[slot]
 items.append(row)
emit('items',items)
rooms=[];gates={'R05':'B01','R07':'B02','R09':'B03','R11':'B04','R12':'B05'}
for idx,r in enumerate(plan['rooms']):
 row=dict(r);row['exits']=[{'to':x,'requires':gates.get(x,'') if int(x[1:])>idx+1 else ''} for x in r['exits'].split(',')]
 row['fast_travel']=r['id'] in ['R01','R05','R07','R09','R11'];row['palette']=['hub','hub','canal','canal','rail','rail','garden','garden','coal','foundry','archive','reactor'][idx]
 row['hazard']={'R03':'Wet','R04':'Wet','R07':'Corroded','R08':'Corroded','R09':'Heated','R10':'Heated'}.get(r['id'],'');rooms.append(row)
emit('rooms',rooms)
names=['หนูกัดท่อ','หมาควัน','ค้างคาวเอเธอร์','ตะขาบทองแดง','ด้วงเกราะ','แมงมุมแก้ว','หมูป่าถ่านหิน','นกกระสาไอกรด','หมาป่ารากไม้','ยามกระบอง','มือปืนราง','ทหารโล่','พลวางระเบิด','ช่างซ่อมศัตรู','เจ้าหน้าที่อาร์ก','มือสังหารควัน','นักลักลอบยา','นักวิจัยติดอาวุธ','ทหารเกราะหนัก']
roles=['bite','heat','quick','corrode','guard','sealed','charge','wet','howl','stagger','mark','guard','area','repair','electric','quick','heal','sealed','charge']
enemies=[]
for i,(name,role) in enumerate(zip(names,roles),1):
 enemies.append({'id':f'N{i:02d}','name':name,'kind':'mutant' if i<=9 else 'human','role':role,'boss':False,'base_hp':34+i*3,'attack':7+i,'tech':8+i,'armor':i%4*4,'resist':i%3*5,'initiative':12+i%7,'barrier':20 if role=='guard' else 0,'intent':{'bite':'กัดท่อ','heat':'พ่นควันร้อน','quick':'พุ่งเร็ว','corrode':'พ่นกรด','guard':'ตั้งโล่','sealed':'ปล่อยสารยับยั้ง','charge':'ชาร์จแรงกระแทก','wet':'พ่นของเหลว','howl':'ขู่ทำเครื่องหมาย','stagger':'ฟาดให้เสียจังหวะ','mark':'เล็งเป้าหมาย','area':'ระเบิดกระจาย','repair':'ซ่อมโล่','electric':'ปล่อยอาร์ก','heal':'ฉีดยาฟื้นฟู'}[role]})
for j,b in enumerate(plan['bosses'],1):
 row=dict(b);row.update(boss=True,role=['charge','guard','heal','heat','mark','electric'][j-1],base_hp=180+j*60,attack=14+j*5,tech=14+j*5,armor=10+j*3,resist=8+j*3,initiative=16+j,barrier=40+j*15,phase_thresholds=[.75,.4] if j==6 else [.5],intent=['ชาร์จหม้อน้ำ','ตั้งโล่ขบวน','เรียกหน่อฟื้นฟู','อัดแรงดันเตาหลอม','ตราประทับสลับคำสั่ง','เปิดสนามเอเธอร์'][j-1]);enemies.append(row)
emit('enemies',enemies)
counts=[3,3,3,4,3,4,3,4,4,5];boss_rooms={b['room']:b['id'] for b in plan['bosses']};encounters=[];normal_i=0;previous=''
for room_index,(r,count) in enumerate(zip(rooms[2:],counts)):
 for slot in range(count):
  boss=boss_rooms.get(r['id'],'') if slot==count-1 else ''
  if boss:
   ids=[boss];xp=400+100*int(boss[1:]);gold=150+50*int(boss[1:]);n=0
  else:
   normal_i+=1;n=normal_i;first=(room_index*2+slot)%19+1;ids=[f'N{first:02d}'];
   if n%3==0:ids.append(f'N{(first+6)%19+1:02d}')
   xp=80+20*n;gold=30+10*n
  eid=f'E{len(encounters)+1:02d}'
  encounters.append({'id':eid,'name':next(e['name'] for e in enemies if e['id']==ids[0])+(' และพวก' if len(ids)>1 else ''),'room':r['id'],'enemies':ids,'scale':round(1+room_index*.20+slot*.04,2),'boss_id':boss,'xp':xp,'gold':gold,'energy_cost':12 if boss else 8,'requires':previous,'optional_bypass':'rescued_specimen' if r['id']=='R07' and slot==1 else '', 'normal_index':n})
  previous=eid
emit('encounters',encounters)
emit('training',plan['training'])
npc_names=['อาจารย์เรน','อิง','คีตา','สารวัตรวาล์ค','ดร.ลิน','โบลท์','ซาเรน','มีรา']
quest_names=['น้ำให้คนงาน','ยาของผู้คุม','พยานขบวนรถ','ตัวอย่างที่ยังมีชีวิต','เครื่องมือของมีรา','คืนชื่อผู้สูญหาย','สัญญาแรงงาน','คำสั่งที่ถูกลบ']
quest_rooms=['R03','R05','R06','R07','R08','R09','R10','R11'];quests=[]
for i,(name,room) in enumerate(zip(quest_names,quest_rooms),1):
 quests.append({'id':f'Q{i:02d}','name':name,'room':room,'xp':100+50*i,'gold':80+20*i,'skill_point':1 if i in [1,3,5,7,8] else 0,'item':'W25' if i==5 else ('A09' if i==8 else ''),'npc_id':f'NPC{[6,2,4,5,8,7,6,7][i-1]:02d}','objective':'interact','choices':['help','pragmatic']})
npcs=[{'id':f'NPC{i:02d}','name':name,'room':room} for i,(name,room) in enumerate(zip(npc_names,['R01','R02','R02','R05','R07','R03','R11','R08']),1)]
story={'title':'เถ้าถ่านแห่งนครเหล็ก','prologue':'นครเวสเปอร์เดินด้วยไอน้ำ แต่แหล่งน้ำเริ่มเรืองแสงสีเขียว คืนที่โรงงานระเบิด มีราหายตัวไป เหลือเพียงแบบวงจรในมือคุณ และเสียงสัตว์ที่ดังมาจากท่อใต้เมือง','npcs':npcs,'quests':quests,'dialogue':[],'endings':[{'id':'Shutdown','name':'รุ่งเช้าที่ไร้ควัน','requires':[]},{'id':'Seize','name':'ผู้ถือกุญแจเมือง','requires':[]},{'id':'Cure','name':'ลมหายใจใหม่','requires':['rescued_specimen','Q08']}]}
objects=['water_valve','medical_crate','rail_terminal','control_emitter','mira_toolbox','memorial_register','worker_contract','original_order']
object_names=['วาล์วน้ำสะอาด','ลังยาที่ตกค้าง','เครื่องบันทึกรถไฟ','เครื่องส่งคลื่นเอเธอร์','กล่องเครื่องมือของมีรา','ทะเบียนผู้สูญหาย','สัญญาคนงาน','คำสั่งต้นฉบับ']
lines=[
('พวกเขาให้เราเลือกว่าจะต้มน้ำกินหรือเก็บน้ำไว้เดินเครื่อง ถ้าคุณไปถึงวาล์ว ช่วยดูหน่อยว่ายังเปิดทางน้ำสะอาดได้ไหม','ฟังเสียงท่อเบาลงสิ คราวนี้มีคนได้ยินเสียงลูกของตัวเองแทนเครื่องจักรแล้ว','เปิดน้ำให้คนงานก่อน','ส่งตัวอย่างน้ำให้เมืองตรวจ'),
('ฉันมีคนไข้รออยู่ที่ชานชาลา ลังยาของโรงงานยังติดอยู่ด้านใน ตรวจตราก่อนเปิดนะ','เรารักษาคนโดยไม่ถามสีเครื่องแบบได้ แต่หลังจากวันนี้ พวกเขาต้องตอบว่าทำไมยาถึงถูกกักไว้','แบ่งยาให้คนงานกับยามเท่ากัน','ให้ผู้คุมรับผิดชอบการแจกยา'),
('ขบวนนี้ไม่ได้ขนแค่เชื้อเพลิง มีคนอยู่ในตู้ที่ถูกลบออกจากตาราง ถ้าบันทึกยังอยู่ ฉันอยากเห็นด้วยตาตัวเอง','ฉันเลือกทำหน้าที่รักษาคน ไม่ใช่รักษาคำสั่งที่ไม่มีใครยอมลงชื่อ','เปิดเผยชื่อผู้สั่งย้ายขบวน','ส่งสำเนาโดยปิดชื่อพยาน'),
('มันกัดเพราะเครื่องส่งคลื่นสั่งให้ป้องกันรัง ปิดเครื่องก่อน แล้วฉันจะพามันออกไป','เซลล์ของมันตอบสนองต่อสัญญาณเหมือนคนที่พยายามจำบ้าน ฉันยังเชื่อว่าเราหยุดความเจ็บปวดนี้ได้','ปิดเครื่องและช่วยตัวอย่างที่ยังมีชีวิต','เก็บตัวอย่างด้วยการทำลายรัง'),
('ฉันไม่ตาย แต่พวกเขาใช้ชื่อฉันอนุมัติการทดลอง เครื่องมือในกล่องมีวงจรที่ฉันใช้ตอนสร้างแกนรุ่นแรก','เอามันไป ฉันสร้างของชิ้นนี้ให้ช่วยคน ไม่ใช่ให้ช่างคนใดคนหนึ่งถือกุญแจเมืองไว้คนเดียว','คืนเครื่องมือให้มีราตรวจวงจร','เก็บแบบไว้ใช้ต่อรองกับฝ่ายเมือง'),
('ในทะเบียนเขียนว่าคนเหล่านี้ลาออก ทั้งที่ค่าแรงงวดสุดท้ายยังแขวนอยู่บนโต๊ะ มาช่วยคืนชื่อให้พวกเขาเถอะ','ชื่อหนึ่งชื่อทำให้ครอบครัวเลิกเดินหาในหมอกได้ แม้มันไม่ใช่คำตอบที่พวกเขาหวัง','ประกาศทะเบียนให้ทุกครอบครัว','ให้ผู้รักษาบันทึกส่งข่าวทีละบ้าน'),
('สัญญาเขียนว่าคนงานยินยอมรับความเสี่ยง แต่ไม่มีใครเคยเห็นหน้าที่สองก่อนลงชื่อ หาต้นฉบับมาให้เราดู','คืนนี้เราอาจเปิดเตาใหม่ แต่คนที่ยืนหน้าเตาต้องมีสิทธิ์ปิดมันด้วย','ให้คนงานร่วมถือกุญแจโรงหล่อ','ให้เจ้าหน้าที่เซ็นรับรองสัญญาใหม่'),
('คำสั่งต้นฉบับยังอยู่ ถ้าเผยแพร่พร้อมชื่อพยาน คนที่ช่วยเราอาจไม่ได้เห็นรุ่งเช้า คุณจะรักษาทั้งสองอย่างได้ไหม','ข้อมูลที่รอดออกไปต้องมีคนรอดกลับมาอ่านด้วย จำประโยคนี้ก่อนเปิดประตูปฏิกรณ์','เผยแพร่สำเนาและปกป้องพยาน','ส่งสำเนาให้เมืองโดยปิดชื่อผู้ให้ข้อมูล')]
for i,q in enumerate(quests):
 q['object_id']=objects[i];q['object_name']=object_names[i]
 before,after,help_text,pragmatic_text=lines[i]
 story['dialogue'].append({'id':'D'+q['id'][1:],'quest_id':q['id'],'speaker':q['npc_id'],'text':before,'active_text':'เป้าหมายคือ '+object_names[i]+' ที่'+next(r['name'] for r in rooms if r['id']==q['room'])+' สำรวจแล้วกลับมาคุยกัน','complete_text':'คุณพบหลักฐานแล้ว ต่อจากนี้เราต้องเลือกว่าจะใช้มันอย่างไร','after_text':after,'choices':[{'id':'help','text':help_text},{'id':'pragmatic','text':pragmatic_text}]})
ambient=[
('เรนเคาะหม้อน้ำสามครั้ง “ฟังเสียงก่อนเชื่อมาตรวัด มีรารู้ว่าแกนกำลังร้อง แต่ฝ่ายเมืองไม่ยอมฟังเธอ”','“ฉันซ่อมเครื่องมาทั้งชีวิต” เรนวางประแจ “วันนี้คนงานสอนฉันว่า บางเครื่องต้องยอมให้หยุด”'),
('อิงจัดหลอดยาที่เหลือ “อย่าเอาแสงสีเขียวมาใกล้แผล น้ำในถังที่ปิดฝาไว้ยังสะอาด เติมใส่ขวดไปด้วย”','อิงพับเตียงสนาม “เราเย็บแผลของคนกับยามด้วยด้ายเส้นเดียวกัน อย่าให้ใครแบ่งพวกเขาอีกตอนหายดี”'),
('คีตาลดเสียง “ยามตรวจตราเลขลัง แต่ไม่เคยนับคนบนรถไฟ ถ้าจะหารายชื่อ ไปถามสารวัตรวาล์คที่สถานี”','“ข่าววิ่งเร็วกว่ารถไฟแล้ว” คีตายิ้มบาง “เก็บสำเนาคำสั่งไว้หลายชุด อย่าฝากความจริงไว้ที่คนคนเดียว”'),
('วาล์คเก็บตราเข้ากระเป๋า “เครื่องแบบช่วยเปิดประตู แต่ไม่รับประกันว่าคนข้างในพูดจริง อ่านบันทึกก่อนตัดสินฉัน”','วาล์คยืนข้างประตูที่เปิดไว้ “ฉันจะลงชื่อในสิ่งที่สั่งเอง และจะไม่ให้ใครใช้คำว่าเพื่อเมืองซ่อนชื่ออีก”'),
('ลินหยุดฟังเสียงในรัง “สัตว์พวกนี้ตอบสนองต่อคลื่น หยุดคลื่นได้ก็หยุดการต่อสู้บางครั้งได้ ฉันต้องการตัวอย่างที่ยังหายใจ”','ลินล้างมือที่เปื้อนสารเรืองแสง “ความกลัวทำให้เราเรียกมันว่าความผิดพลาด แต่สิ่งมีชีวิตไม่ควรถูกลงโทษแทนคนสร้างเครื่อง”'),
('โบลท์ยกถังน้ำเปล่าให้ดู “น้ำหนึ่งถังหักจากค่าแรงหนึ่งวัน ลองถามเครื่องจักรสิว่ามันเคยต้องเลือกกินหรือทำงานไหม”','โบลท์ยื่นรายชื่อคนที่กลับบ้าน “อย่าเอารายชื่อไปแขวนบนกำแพง ให้พวกเขาเป็นคนถือกุญแจด้วย”'),
('ซาเรนซ่อนกระดาษใต้เสื้อ “ต้นฉบับบอกว่าแกนมีโหมดฟื้นฟู แต่สำเนาที่ส่งให้โรงงานลบหน้านั้นออก ฉันจำลายมือคนสั่งได้”','ซาเรนส่งสำเนาอีกฉบับ “หลักฐานต้องออกจากห้องนี้ แต่พยานก็ต้องออกไปด้วย ความจริงที่ไม่มีคนรอดอ่านช่วยใครไม่ได้”'),
('มีราเลื่อนวงจรให้ดู “ฉันใส่ทางหยุดไว้สามทาง พวกเขาลบสองทางออกจากคู่มือ แต่ไม่ได้ลบออกจากเครื่อง”','มีรามองสะพานที่มีคนเดินกลับ “ตอนสร้างแกน ฉันคิดถึงแสงไฟ ตอนนี้ฉันคิดถึงคนที่ต้องเป็นคนเลือกว่าจะเปิดมันเมื่อไร”')]
for npc,(before,after) in zip(npcs,ambient):
 npc['rooms']=sorted({npc['room'],*[q['room'] for q in quests if q['npc_id']==npc['id']]})
 npc['ambient_before']=before
 npc['ambient_after']=after
story['boss_intros']={
 'B01':'หม้อน้ำที่ฝังบนหลังจระเข้เต้นตามท่อส่งน้ำ โบลท์ชี้วาล์วฝั่งคลอง: ตัดแรงดันก่อนเข้าใกล้กรามมัน',
 'B02':'ผู้คุมยืนขวางตู้โดยสารที่ไม่มีในตาราง “คำสั่งให้ผมปิดตู้ ไม่ได้ให้ผมถามว่าข้างในมีใคร” เสียงกลไกเติมกระสุนดังอยู่หลังโล่',
 'B03':'รากแก้วแตกหน่อขึ้นรอบกวาง ลินกระซิบว่าอย่าปล่อยให้หน่อส่งน้ำเลี้ยงถึงตัวมัน ผนึกการฟื้นฟูหรือโค่นหน่อก่อน',
 'B04':'นายช่างเสียบสัญญาคนงานเข้าเตา “เมืองต้องเดินต่อ” เขาว่า ไอน้ำเริ่มกลบคำตอบของโบลท์ วาล์วหล่อเย็นยังอยู่ข้างประตู',
 'B05':'ผู้เก็บความทรงจำอ่านคำสั่งสามบรรทัดซ้ำ เสียงแรกเตรียมตัว เสียงที่สองหมายหัว เสียงที่สามลั่นไก คำสั่งต้นฉบับเปิดเผยว่าบรรทัดต่อไปคืออะไร',
 'B06':'มีราวางมือบนกุญแจสำรอง “หลังชนะ ฉันเปิดทางได้ แต่คนเลือกต้องเป็นเธอ” ปีกของราชินีห่อหุ้มแกนเมือง หมอก ความร้อน และแสงจากหัวใจหมุนสลับกัน'}
story['harvest_warning']='การเก็บตัวอย่างด้วยการทำลายรังจะปิดทางจบแบบลมหายใจใหม่ (Cure) ในเซฟนี้ถาวร ยังเลือก Shutdown หรือ Seize ได้ คุณยืนยันหรือไม่?'
story['chapters']=[{'id':'CH01','name':'น้ำดำ','bosses':['B01']},{'id':'CH02','name':'ขบวนที่หายไป','bosses':['B02']},{'id':'CH03','name':'เรือนเพาะ','bosses':['B03']},{'id':'CH04','name':'หัวใจแรงงาน','bosses':['B04']},{'id':'CH05','name':'เสียงของเมือง','bosses':['B05','B06']}]
story['endings'][0]['text']='คุณปลดแกนออกจากสายส่ง เมืองมืดลงเป็นครั้งแรก มีราพาคนอพยพผ่านสะพาน เช้าวันใหม่ไม่มีควัน แต่ทุกคนต้องเรียนรู้ว่าจะอยู่ด้วยกันอย่างไรโดยไม่ให้เครื่องจักรเลือกแทน'
story['endings'][1]['text']='กุญแจปฏิกรณ์อยู่ในมือฝ่ายรักษาการณ์ แสงไฟกลับมาอย่างรวดเร็ว บันทึกของคุณถูกเก็บไว้ใต้ตราเมือง มีราถามว่าในวันที่เครื่องจักรเริ่มส่งเสียงอีกครั้ง ใครจะมีสิทธิ์สั่งหยุดมัน'
story['endings'][2]['text']='ลินใช้ตัวอย่างที่รอดชีวิตปรับวงจรของมีรา หมอกเอเธอร์จางลงทีละถนน คนงานกับนักวิจัยร่วมกันเฝ้าแกน เมืองยังมีบาดแผล แต่ครั้งนี้มันมีคนยอมรับฟังเสียงจากอีกฝั่งของท่อ'
emit('story',story)
print('Wrote 8 runtime catalogs: 5 classes, 22 skills, 62 gear, 12 rooms, 25 enemies, 36 encounters, 4 training, authored quest dialogue.')
