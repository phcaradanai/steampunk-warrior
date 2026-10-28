import assert from 'node:assert/strict';
import {readFile, writeFile, mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {inflateSync} from 'node:zlib';
import {chromium} from '/Users/oyl-mac_m1/.npm/_npx/af752b90495482d7/node_modules/playwright-core/index.mjs';

const root='/Users/Projects/Steampunk-warrior';
const phase=process.argv[2] || 'census';
const sha=b=>createHash('sha256').update(b).digest('hex');
const original=await readFile(`${root}/reference/sinjid/original.swf`);
assert.equal(sha(original),'e258423f2a5887ff236a67eb6eaf674a8d573a5cdb721c20b79c831da4d9e008');
const patched=await readFile(`${root}/reference/sinjid/probe.swf`);
function tags(buf){
  const b=buf.subarray(0,3).toString()==='CWS'?Buffer.concat([buf.subarray(0,8),inflateSync(buf.subarray(8))]):buf;
  let p=8+Math.ceil((5+4*(b[8]>>3))/8)+4, frame=1;const result=[];
  while(p<b.length){let h=b.readUInt16LE(p);p+=2;let len=h&63;const code=h>>6;if(len===63){len=b.readUInt32LE(p);p+=4;}
    result.push({frame,code,sha256:sha(b.subarray(p,p+len))});p+=len;if(code===1)frame++;if(code===0)break;}
  return result;
}
const a=tags(original),b=tags(patched);assert.equal(a.length,b.length);
const changes=a.flatMap((t,i)=>JSON.stringify(t)===JSON.stringify(b[i])?[]:[{index:i,before:t,after:b[i]}]);
assert.equal(changes.length,1);assert.equal(changes[0].before.frame,17);assert.equal(changes[0].before.code,12);
const result={authority:'Controlled instrumented SWF6 browser probes; companion REA process Evidence establishes execution provenance. Not a natural progression playthrough.',phase,
 original_sha256:sha(original),probe_sha256:sha(patched),instrumentation_sha256:sha(await readFile(`${root}/docs/research/runtime-probe.as`)),runner_sha256:sha(await readFile(new URL(import.meta.url))),loader_sha256:sha(await readFile(`${root}/reference/sinjid/runtime/probe.html`)),audio_observer_sha256:sha(await readFile(`${root}/reference/sinjid/runtime/audio-observer.js`)),changes,inputs:[],records:[]};
await mkdir(`${root}/reference/sinjid/probe-versions`,{recursive:true});
await writeFile(`${root}/reference/sinjid/probe-versions/${result.probe_sha256}.swf`,patched);
await writeFile(`${root}/reference/sinjid/probe-versions/${result.instrumentation_sha256}.as`,await readFile(`${root}/docs/research/runtime-probe.as`));
await writeFile(`${root}/reference/sinjid/probe-versions/${result.runner_sha256}.mjs`,await readFile(new URL(import.meta.url)));
await writeFile(`${root}/reference/sinjid/probe-versions/${result.audio_observer_sha256}.js`,await readFile(`${root}/reference/sinjid/runtime/audio-observer.js`));
const output=`${root}/docs/research/runtime-${phase}-results.json`;
await mkdir(`${root}/docs/research/runtime/probes`,{recursive:true});
const save=async()=>writeFile(output,JSON.stringify(result,null,2)+'\n');
const browser=await chromium.connectOverCDP('http://127.0.0.1:9337');
const context=browser.contexts()[0];
let page=context.pages().find(p=>p.url().includes('/runtime/probe.html'));
if(!page)page=await context.newPage();
let seq=Date.now();
async function command(mode,fields={}){
  seq++;const query=new URLSearchParams({reaSeq:String(seq),reaMode:mode,...fields});
  result.inputs.push({seq:String(seq),mode,fields});
  await writeFile(`${root}/reference/sinjid/runtime/probe.txt`,query.toString());
  await page.waitForFunction(s=>window.reaState?.reaSeq===s,String(seq),{timeout:10000});
  return page.evaluate(()=>structuredClone(window.reaState));
}
async function record(name,state,extra={}){
  result.records.push({name,state,...extra});await save();console.log(JSON.stringify({test:name,frame:state.frame,status:'captured'}));
}
async function playerReady(){
  for(let attempt=0;attempt<15;attempt++){
    const state=await command('snapshot');
    if(state.midfight==='false'&&state.playermove.split(',')[Number(state.turnnum)]==='hero1')return state;
    await page.waitForTimeout(250);
  }
  throw new Error('Original four-actor round did not return to a selectable player turn');
}
async function waitFrame(frame){
  for(let attempt=0;attempt<15;attempt++){
    const state=await command('snapshot');if(Number(state.frame)===frame)return state;
    await page.waitForTimeout(200);
  }
  throw new Error(`Original movie did not reach frame ${frame}`);
}
async function boot(choice='Warrior'){
  await writeFile(`${root}/reference/sinjid/runtime/probe.txt`,'reaSeq=0&reaMode=snapshot');
  await page.goto('http://127.0.0.1:8765/runtime/probe.html');await page.waitForTimeout(2200);
  await page.mouse.click(517,440);await page.waitForTimeout(400);await page.mouse.click(552,18);
  await page.waitForFunction(()=>window.reaState?.frame==='17',{timeout:15000});
  await page.mouse.click(75,325);await page.waitForTimeout(350);await page.mouse.click(456,430);
  const classes={Balanced:{xy:[58,132],stats:[75,75,15,15,8,2],starter:1},Warrior:{xy:[358,132],stats:[85,65,17,13,10,0],starter:0},Spellcaster:{xy:[58,312],stats:[75,90,15,13,0,10],starter:9},Shadow:{xy:[358,312],stats:[70,80,13,17,8,3],starter:7}};
  await page.waitForTimeout(350);await page.mouse.click(...classes[choice].xy);await page.waitForTimeout(650);
  const s=await command('snapshot');assert.equal(s.frame,'21');
  assert.deepEqual(['lifeb','manab','strb','speedb','phydmgb','magdmgb'].map(k=>Number(s[k])),classes[choice].stats);
  assert.equal(s.skill.split(',')[classes[choice].starter],'1');await record(`natural-${choice}-initialization-in-instrumented-copy`,s);
}
try{
  if(phase==='census'){
    await boot();await command('prepare');
    const world=JSON.parse(await readFile(`${root}/docs/research/sinjid-world-inventory.json`));
    for(const room of world.rooms){
      const s=await command('jump',{reaTarget:room.id});assert.equal(Number(s.frame),room.frame);
      await record(room.id,s,{fixture:'direct scene seek after normal hub initialization; progression counters seeded',expected_frame:room.frame});
      await page.screenshot({path:`${root}/docs/research/runtime/probes/${room.id}.png`});
    }
    for(const e of world.encounters.filter(e=>!/WASP/.test(e.id))){
      const s=await command('jump',{reaTarget:e.id});assert.equal(Number(s.frame),e.frame);
      assert.ok(Number(s.enemy1life)>0,`${e.id}: living enemy1 missing`);
      await record(e.id,s,{fixture:'seeded level30, HP/MP50000, skills rank10; original enemy initializer and controllers',expected_frame:e.frame});
      if(e.id.startsWith('DARK')||['HUMAN4','TRAIN3'].includes(e.id))await page.screenshot({path:`${root}/docs/research/runtime/probes/${e.id}.png`});
    }
    let s=await command('arithmetic');
    assert.equal(s.reaResult,'omitted:20,physical:15,magical:10,shield:0,life:100');
    await record('original-damage-callback-semantics',s);
    s=await command('tie');await record('all-four-speeds-equal-original-speedorder',s);
    assert.equal(s.undefinedPlusOne,'1');
  } else if(phase==='skills'){
    await boot();await command('resetSkills');await command('inventory',{reaTarget:'SkillPut'});
    let s=await command('snapshot');await record('skill-tree-reset-fixture',s);
    await page.mouse.click(270,290);await page.waitForTimeout(250);s=await command('snapshot');
    assert.equal(s.skill.split(',')[15],'0');assert.equal(s.skillpts,'10');await record('two-predecessor-node-rejects-no-parents',s);
    await command('skillRank',{reaIndex:'7',reaValue:'1'});await page.mouse.click(270,290);s=await command('snapshot');
    assert.equal(s.skill.split(',')[15],'0');await record('two-predecessor-node-rejects-one-parent',s);
    await command('skillRank',{reaIndex:'11',reaValue:'1'});await page.mouse.click(270,290);s=await command('snapshot');
    assert.equal(s.skill.split(',')[15],'1');assert.equal(s.skillpts,'9');await record('two-predecessor-node-accepts-both-parents',s);
    await command('skillRank',{reaIndex:'0',reaValue:'10'});await page.mouse.click(180,70);s=await command('snapshot');
    assert.equal(s.skill.split(',')[0],'10');assert.equal(s.skillpts,'9');await record('rank10-cap-rejects-spending',s);
    await command('skillRank',{reaIndex:'8',reaValue:'1'});await command('skillRank',{reaIndex:'11',reaValue:'0'});
    await command('set',{reaName:'level',reaValue:'4'});await page.mouse.click(270,235);s=await command('snapshot');
    assert.equal(s.skill.split(',')[11],'0');await record('level5-node-rejects-level4',s);
    await command('set',{reaName:'level',reaValue:'5'});await page.mouse.click(270,235);s=await command('snapshot');
    assert.equal(s.skill.split(',')[11],'1');await record('level5-node-accepts-level5',s);
    await page.mouse.click(532,408);await command('prepare');await command('encounter',{reaTarget:'HUMAN4'});await page.waitForTimeout(3500);
    s=await command('snapshot');assert.equal(s.frame,'35');await record('original-encounter-transition-to-dual-fight',s);
    const coordinates={0:[232,374],1:[277,374],2:[322,374],3:[366,374],4:[412,374],5:[457,374],6:[502,374],9:[545,374],11:[232,416],12:[277,416],13:[322,416],14:[367,416],15:[412,416],16:[458,416],17:[501,416],18:[545,416]};
    const catalog=JSON.parse(await readFile(`${root}/docs/research/sinjid-skills-static.json`));
    for(const skill of catalog.skills.filter(s=>s.type!=='passive')){
      await playerReady();
      const before=await command('skillFixture');
      const [x,y]=coordinates[skill.index];await page.mouse.click(x,y);await page.waitForTimeout(800);
      const after=await playerReady();
      const mana=Number(after.hero1mana);
      const expected=skill.index===11?0:skill.index===9?1250:1000-Number(skill.mana_display);
      assert.equal(mana,expected,`${skill.name}: original button/callback mana result`);
      if(skill.index===12)assert.ok(Number(after.hero1life)>25000,'Heal did not restore life');
      else if(skill.index===18){assert.ok(Number(after.hero2life)>0,'Summon absent');assert.equal(after.hero2speed,'60');assert.ok(Number(after.enemy1life)<50000,'Summon did not act');}
      else if(skill.index!==9){assert.ok(Number(after.enemy1life)<50000,`${skill.name}: no primary damage`);}
      if([1,5].includes(skill.index))assert.ok(Number(after.enemy2life)<50000,`${skill.name}: no second target damage`);
      await record(`active-skill-${skill.index}-${skill.name}`,after,{before,input:{x,y},expected_mana:expected,fixture:'original battle button and animation at rank10; seeded HP/MP, targets and selectable turn'});
    }
    await command('skillRank',{reaIndex:'1',reaValue:'1'});const before=await command('skillFixture');
    await page.mouse.click(412,416);await page.waitForTimeout(800);s=await playerReady();
    const baseline=result.records.find(r=>r.name==='active-skill-15-Shadow Strike');
    const highDamage=50000-Number(baseline.state.enemy1life),lowDamage=50000-Number(s.enemy1life);
    assert.ok(highDamage-lowDamage>170,'Shadow Strike Shurikens-rank dependency not reproduced');
    await record('Shadow-Strike-depends-on-Shurikens-rank',s,{before,rank10_damage:highDamage,rank1_damage:lowDamage,fixture:'only Shurikens rank differs; Shadow Strike remains rank10'});
  } else if(phase==='quests'){
    for(const cls of ['Balanced','Warrior','Spellcaster','Shadow'])await boot(cls);
    await command('bagFull');await command('jump',{reaTarget:'Arena9'});await command('position',{reaX:'252',reaY:'217'});
    await page.keyboard.press('Space');let s=await command('snapshot');
    assert.equal(s.moon_q,'false');assert.ok(!s.itemstats.includes("Mendo's Ring"));await record('ring-gift-rejects-full-bag',s);
    await command('dropFull');s=await command('snapshot');assert.ok(!s.itemstats.includes('Katana'));await record('full-bag-drop-is-not-inserted',s);
    await page.keyboard.press('Space');await page.waitForTimeout(300);await command('bagEmpty');
    await command('position',{reaX:'252',reaY:'217'});await page.keyboard.press('Space');s=await command('snapshot');
    assert.equal(s.moon_q,'true');assert.ok(s.itemstats.includes("Mendo's Ring"));await record('ring-gift-accepted',s);
    await page.keyboard.press('Space');await page.waitForTimeout(250);await command('jump',{reaTarget:'Arena7'});
    const points=Number(s.skillpts);await command('position',{reaX:'406',reaY:'115'});await page.keyboard.press('Space');s=await command('snapshot');
    assert.equal(Number(s.skillpts),points+1);assert.ok(!s.itemstats.includes("Mendo's Ring"));await record('moon-consumes-ring-and-awards-skill-point',s);
    await page.keyboard.press('Space');await page.waitForTimeout(250);await command('jump',{reaTarget:'Arena6'});
    await command('item',{reaTarget:'White Leaves'});await command('position',{reaX:'226',reaY:'267'});await page.keyboard.press('Space');s=await command('snapshot');
    assert.ok(s.itemstats.includes('Medicine'));assert.ok(!s.itemstats.includes('White Leaves'));await record('lady-converts-leaves-to-medicine',s);
    await page.keyboard.press('Space');await page.waitForTimeout(250);await command('jump',{reaTarget:'Arena9'});
    await command('portal',{reaValue:'20'});await command('position',{reaX:'300',reaY:'124'});await page.keyboard.press('Space');s=await command('snapshot');
    assert.equal(s.frame,'30');assert.equal(s.talking,'true');await record('Dark-gate-rejects-incomplete-Human-route',s);
    await page.keyboard.press('Space');await page.waitForTimeout(250);await command('portal',{reaValue:'21'});
    await command('position',{reaX:'300',reaY:'124'});await page.keyboard.press('Space');await page.waitForTimeout(1000);s=await command('snapshot');
    assert.equal(s.frame,'31');assert.equal(s.portals,'21,1,1');await record('Dark-gate-accepts-Human-complete-with-other-routes-incomplete',s);
    await command('jump',{reaTarget:'Arena0'});await command('portal',{reaValue:'20'});await command('position',{reaX:'300',reaY:'309'});
    await page.keyboard.press('Space');s=await command('snapshot');assert.equal(s.frame,'21');await record('story-exit-rejects-incomplete-Human-route',s);
    await page.keyboard.press('Space');await page.waitForTimeout(250);await command('portal',{reaValue:'21'});await command('position',{reaX:'300',reaY:'309'});
    await page.keyboard.press('Space');await page.waitForTimeout(500);s=await command('snapshot');assert.ok(Number(s.frame)>=91);assert.equal(s.portals,'21,1,1');
    await record('story-ending-without-Monster-or-Dark-completion',s);
    await page.screenshot({path:`${root}/docs/research/runtime/probes/ending.png`});
  } else if(phase==='economy'){
    await boot();await command('bagEmpty');await command('set',{reaName:'gold',reaValue:'100'});
    await command('inventory',{reaTarget:'Items_0'});
    await page.mouse.click(307,105);let s=await command('snapshot');
    assert.equal(s.gold,'70');assert.equal(s.itempick,'Silver Knife');await record('shop-purchase-charges30-and-holds-item',s);
    await page.mouse.click(76,268);s=await command('snapshot');
    assert.equal(s.Weapon,'Silver Knife');assert.equal(s.phydmgb,'15');assert.equal(s.itempick,'Iron Knife');await record('equip-swaps-weapon-and-applies-net-stats',s);
    await page.mouse.click(59,373);s=await command('snapshot');
    assert.equal(s.gold,'77');assert.equal(s.itempick,'None');await record('weapon-sale-uses-rounded-category-formula',s,{sold:'Iron Knife',price:7});
    await page.mouse.click(76,268);s=await command('snapshot');assert.equal(s.Weapon,'None');assert.equal(s.phydmgb,'5');assert.equal(s.itempick,'Silver Knife');await record('unequip-removes-exact-item-bonus',s);
    await command('set',{reaName:'strb',reaValue:'1'});await page.mouse.click(76,268);s=await command('snapshot');
    assert.equal(s.Weapon,'None');assert.equal(s.itempick,'Silver Knife');assert.equal(s.phydmgb,'5');await record('insufficient-strength-rejects-equip',s);
    await command('set',{reaName:'strb',reaValue:'20'});await page.mouse.click(76,268);s=await command('snapshot');assert.equal(s.Weapon,'Silver Knife');assert.equal(s.itempick,'None');
    await command('set',{reaName:'gold',reaValue:'0'});await page.mouse.click(307,105);s=await command('snapshot');
    assert.equal(s.gold,'0');assert.equal(s.itempick,'None');await record('insufficient-gold-rejects-shop-purchase',s);
    await command('set',{reaName:'gold',reaValue:'100'});await page.mouse.click(307,105);s=await command('snapshot');assert.equal(s.itempick,'Silver Knife');
    await page.mouse.click(532,409);s=await command('snapshot');assert.equal(s.pause,'true');assert.equal(s.itempick,'Silver Knife');await record('normal-close-rejects-held-item',s);
    await page.mouse.click(55,86);s=await command('snapshot');assert.equal(s.itempick,'None');assert.equal(s.itemstats.split(',')[4],'Silver Knife');await record('place-purchased-item-in-bag',s);
    await page.mouse.click(532,409);s=await command('snapshot');assert.equal(s.pause,'false');await record('normal-close-succeeds-with-empty-cursor',s);
    await command('item',{reaTarget:'Medicine'});await command('inventory',{reaTarget:'Trade'});await command('set',{reaName:'gold',reaValue:'0'});
    await page.mouse.click(55,86);s=await command('snapshot');assert.equal(s.itempick,'Medicine');
    await page.mouse.click(59,373);s=await command('snapshot');assert.equal(s.gold,'3');assert.equal(s.itempick,'None');await record('medicine-trade-pays3',s);
    await page.screenshot({path:`${root}/docs/research/runtime/probes/economy.png`});
  } else if(phase==='progression'){
    await boot();await command('encounter',{reaTarget:'HUMAN1'});await page.waitForTimeout(3500);await playerReady();
    await command('progressFixture');await page.waitForTimeout(600);let s=await command('snapshot');
    assert.equal(s.level,'5');assert.equal(s.expb,'249');assert.equal(s.expmaxb,'250');assert.equal(s.skillpts,'2');assert.equal(s.statpts,'1');
    assert.equal(s.strb,'22');assert.equal(s.speedb,'22');assert.equal(s.lifemaxb,'105');assert.equal(s.manamaxb,'85');assert.equal(s.engmaxb,'53');
    await record('level5-bonus-and-oversized-XP-clamp',s,{fixture:'level4 XP99/100, pending XP1000, classWarrior; original reward callback'});
    await page.mouse.click(514,409);await page.waitForTimeout(300);s=await command('snapshot');assert.equal(s.frame,'87');
    await page.mouse.click(275,179);s=await command('snapshot');assert.equal(s.statpts,'0');assert.equal(s.strb,'25');assert.equal(s.engmaxb,'55');await record('Warrior-strength-choice-adds3-and-energy2',s);
    await page.mouse.click(514,409);await page.waitForTimeout(300);s=await command('snapshot');assert.equal(s.lifeb,'105');assert.equal(s.manab,'85');assert.equal(s.engb,'55');await record('levelup-continue-refills-resources',s);
    await page.screenshot({path:`${root}/docs/research/runtime/probes/progression.png`});
  } else if(phase==='recovery'){
    await boot();await command('jump',{reaTarget:'Arena2'});await command('position',{reaX:'299',reaY:'166'});
    await page.keyboard.press('Space');await page.waitForTimeout(3500);let s=await playerReady();assert.equal(s.frame,'49');assert.equal(s.portals,'2,1,1');await record('actual-Human-portal-entry-increments-counter',s);
    await command('set',{reaName:'hero1life',reaValue:'1'});await page.mouse.click(45,360);
    s=await waitFrame(90);await record('original-enemy-counterattack-causes-defeat-from-seeded-one-life',s);
    await page.mouse.click(53,384);s=await waitFrame(23);
    assert.equal(s.frame,'23');assert.equal(s.portals,'1,1,1');assert.equal(s.lifeb,'5');assert.equal(s.manab,'5');assert.ok(Number(s.engb)<=5&&Number(s.engb)>=0);
    await record('retry-rolls-back-portal-and-restores5-returning-to-portal-room',s);
    await page.screenshot({path:`${root}/docs/research/runtime/probes/recovery.png`});
  } else if(phase==='training'){
    await boot();await command('inventory',{reaTarget:'Training'});await page.mouse.click(500,154);await page.waitForTimeout(3500);
    let s=await playerReady();assert.equal(s.frame,'81');assert.equal(s.exprate,'3');assert.equal(s.engrate,'2');await record('original-Basic-training-entry',s);
    const before=await command('trainingFixture',{reaShield:'300'});await page.mouse.click(45,360);await page.waitForTimeout(500);s=await playerReady();
    assert.equal(s.expup,'3');assert.equal(s.engb,'98');assert.ok(Number(s.enemy1shdpts)<300);await record('training-normal-hit-gives3-costs2',s,{before});
    await command('set',{reaName:'enemy1shdpts',reaValue:'1'});await page.mouse.click(45,360);await page.waitForTimeout(500);s=await playerReady();
    assert.equal(s.expup,'3');assert.equal(s.engb,'98');assert.equal(s.enemy1shdpts,'0');await record('training-breaking-hit-awards-no-XP-and-costs-no-energy',s);
    await page.mouse.click(45,360);await page.waitForTimeout(500);s=await playerReady();assert.equal(s.expup,'9');assert.equal(s.engb,'96');await record('training-unshielded-body-hit-gives-double-XP',s);
    await page.mouse.click(79,149);s=await waitFrame(85);assert.equal(s.expb,'9');await record('manual-training-exit-settles-earned-XP',s);
    await boot();await command('position',{reaX:'300',reaY:'205'});await command('set',{reaName:'engb',reaValue:'10'});
    await page.keyboard.down('ArrowRight');await page.waitForTimeout(500);await page.keyboard.up('ArrowRight');s=await command('snapshot');const positiveDistance=Number(s.charx)-300;await record('positive-energy-movement',s,{distance:positiveDistance});
    await command('position',{reaX:'300',reaY:'205'});await command('set',{reaName:'engb',reaValue:'0'});
    await page.keyboard.down('ArrowRight');await page.waitForTimeout(500);await page.keyboard.up('ArrowRight');s=await command('snapshot');const emptyDistance=Number(s.charx)-300;
    assert.ok(positiveDistance>emptyDistance*1.15);await record('empty-energy-movement-is-slower',s,{positive_distance:positiveDistance,empty_distance:emptyDistance});
    await command('set',{reaName:'lifeb',reaValue:'70'});await command('set',{reaName:'manab',reaValue:'50'});await page.waitForTimeout(1100);s=await command('snapshot');
    assert.ok(Number(s.lifeb)<70&&Number(s.manab)<50);await record('empty-energy-drains-life-and-mana',s);
    await command('inventory',{reaTarget:'Inventory'});const paused=await command('snapshot');await page.waitForTimeout(1500);s=await command('snapshot');
    assert.equal(s.lifeb,paused.lifeb);assert.equal(s.manab,paused.manab);assert.equal(s.engb,paused.engb);await record('paused-inventory-stops-overworld-drain',s,{before:paused});
  } else if(phase==='options'){
    await writeFile(`${root}/reference/sinjid/runtime/probe.txt`,'reaSeq=0&reaMode=snapshot');
    await page.goto('http://127.0.0.1:8765/runtime/probe.html');await page.waitForTimeout(2200);
    await page.mouse.click(517,440);await page.waitForTimeout(400);await page.mouse.click(552,18);
    await page.waitForFunction(()=>window.reaState?.frame==='17',{timeout:15000});
    await page.mouse.click(55,400);await page.waitForTimeout(250);let s=await command('snapshot');await record('title-options-open',s);
    await page.screenshot({path:`${root}/docs/research/runtime/probes/options-initial.png`});
    await page.mouse.click(200,177);await page.keyboard.press('End');await page.keyboard.press('Enter');s=await command('snapshot');
    assert.equal(s.qset2,'LOW');await record('quality-dropdown-selects-LOW',s);
    await page.mouse.click(200,207);await page.keyboard.press('End');await page.keyboard.press('Enter');s=await command('snapshot');
    assert.equal(s.soundon,'Off');await page.waitForTimeout(350);
    const off=await page.evaluate(()=>window.reaAudioRMS());await record('sound-Off-control',s,{audio:off});
    await page.mouse.click(200,207);await page.keyboard.press('Home');await page.keyboard.press('Enter');s=await command('snapshot');assert.equal(s.soundon,'On');
    const samples=[];for(let i=0;i<8;i++){samples.push(await page.evaluate(()=>window.reaAudioRMS()));await page.waitForTimeout(100);}
    const maxOn=Math.max(...samples.map(x=>x.rms));
    result.limitations=['Sound On/Off state transitions verified; output analyser remained zero even while On. Audible playback, music transitions and action cues remain unverified in this headless environment.'];
    await record('sound-On-control-audio-output-unverified',s,{off,on_samples:samples,max_on_rms:maxOn,scope:'Control state only; zero PCM measurement is inconclusive and is not treated as proof of silence or a game defect'});
    await page.mouse.click(200,177);await page.keyboard.press('Home');await page.keyboard.press('Enter');s=await command('snapshot');assert.equal(s.qset2,'HIGH');await record('quality-dropdown-restores-HIGH',s);
    await page.screenshot({path:`${root}/docs/research/runtime/probes/options.png`});
  } else {
    throw new Error(`Unknown phase ${phase}`);
  }
  result.status='passed';await save();console.log(JSON.stringify({status:'passed',phase,records:result.records.length,output_sha256:sha(await readFile(output))}));
}catch(error){result.status='failed';result.error=String(error.stack||error);await save();throw error;}
finally{await browser.close();}
