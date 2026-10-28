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
const result={authority:'REA-controlled process running browser probes against an explicitly instrumented SWF6 copy; not a natural progression playthrough',phase,
 original_sha256:sha(original),probe_sha256:sha(patched),instrumentation_sha256:sha(await readFile(`${root}/docs/research/runtime-probe.as`)),runner_sha256:sha(await readFile(new URL(import.meta.url))),changes,inputs:[],records:[]};
await mkdir(`${root}/reference/sinjid/probe-versions`,{recursive:true});
await writeFile(`${root}/reference/sinjid/probe-versions/${result.probe_sha256}.swf`,patched);
await writeFile(`${root}/reference/sinjid/probe-versions/${result.instrumentation_sha256}.as`,await readFile(`${root}/docs/research/runtime-probe.as`));
await writeFile(`${root}/reference/sinjid/probe-versions/${result.runner_sha256}.mjs`,await readFile(new URL(import.meta.url)));
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
async function boot(){
  await writeFile(`${root}/reference/sinjid/runtime/probe.txt`,'reaSeq=0&reaMode=snapshot');
  await page.goto('http://127.0.0.1:8765/runtime/probe.html');await page.waitForTimeout(2200);
  await page.mouse.click(517,440);await page.waitForTimeout(400);await page.mouse.click(552,18);
  await page.waitForFunction(()=>window.reaState?.frame==='17',{timeout:15000});
  await page.mouse.click(75,325);await page.waitForTimeout(350);await page.mouse.click(456,430);
  await page.waitForTimeout(350);await page.mouse.click(358,132);await page.waitForTimeout(650);
  const s=await command('snapshot');assert.equal(s.frame,'21');await record('natural-Warrior-initialization-in-instrumented-copy',s);
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
      const before=await command('skillFixture');
      const [x,y]=coordinates[skill.index];await page.mouse.click(x,y);await page.waitForTimeout(4400);
      const after=await command('snapshot');
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
    await page.mouse.click(410,416);await page.waitForTimeout(4400);s=await command('snapshot');
    const baseline=result.records.find(r=>r.name==='active-skill-15-Shadow Strike');
    const highDamage=50000-Number(baseline.state.enemy1life),lowDamage=50000-Number(s.enemy1life);
    assert.ok(highDamage-lowDamage>170,'Shadow Strike Shurikens-rank dependency not reproduced');
    await record('Shadow-Strike-depends-on-Shurikens-rank',s,{before,rank10_damage:highDamage,rank1_damage:lowDamage,fixture:'only Shurikens rank differs; Shadow Strike remains rank10'});
  } else {
    throw new Error(`Unknown phase ${phase}`);
  }
  result.status='passed';await save();console.log(JSON.stringify({status:'passed',phase,records:result.records.length,output_sha256:sha(await readFile(output))}));
}catch(error){result.status='failed';result.error=String(error.stack||error);await save();throw error;}
finally{await browser.close();}
