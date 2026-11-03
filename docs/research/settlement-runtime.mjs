// Drives the original SWF (Ruffle, Chrome for Testing on CDP 9338) through a first fight to its settlement screens.
// Usage: node settlement-runtime.mjs <phase> [actionsJSON]; phases: boot, route, input.
import {chromium} from '/Users/oyl-mac_m1/.npm/_npx/af752b90495482d7/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile,readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const root='/Users/Projects/Steampunk-warrior';
const dir=root+'/docs/research/runtime/settlement-2026-11-03';
await mkdir(dir,{recursive:true});
const browser=await chromium.connectOverCDP('http://127.0.0.1:9338');
const page=browser.contexts()[0].pages().find(p=>p.url().includes('/runtime/'));
if(!page)throw new Error('Original reference page missing');
await page.setViewportSize({width:800,height:600});
const records=[];
async function shot(name){const path=dir+'/'+name+'.png';await page.screenshot({path,clip:{x:0,y:0,width:600,height:470}});records.push({name,path,at:Date.now()});}
async function run(actions){
 for(let i=0;i<actions.length;i++){
  const a=actions[i];
  if(a.click)await page.mouse.click(...a.click);
  if(a.key){await page.keyboard.down(a.key);await page.waitForTimeout(a.hold||80);await page.keyboard.up(a.key);}
  await page.waitForTimeout(a.wait||150);if(a.name)await shot(a.name);
 }
}
const phase=process.argv[2]||'boot';
try{
 if(phase==='boot'){
  await page.goto('http://127.0.0.1:8765/runtime/');await page.waitForTimeout(3500);
  await run([{click:[517,440],wait:700},{click:[552,18],wait:700},{click:[75,325],wait:400},{click:[456,430],wait:400},{click:[358,132],wait:900,name:'hub'}]);
 }else if(phase==='route'){
  // Route recorded in rea-visual-resume-2026-10-28-evidence.json: hub door, Human Gateway room, activate gateway.
  await run([{key:'ArrowRight',hold:540,wait:200},{key:'ArrowLeft',hold:920},{key:'ArrowUp',hold:520},{key:'Space',wait:600,name:'room-2'},
   {key:'ArrowLeft',hold:1800},{key:'Space',wait:600,name:'gateway-room'},
   {key:'ArrowLeft',hold:1650},{key:'ArrowUp',hold:650},{key:'Space',wait:2300,name:'combat-ready'}]);
 }else if(phase==='input'){
  await run(JSON.parse(process.argv[3]));
 }
 const manifest={phase,authority:'Original unmodified SWF in Ruffle; ordinary input; screenshot intervals include capture overhead',original_sha256:createHash('sha256').update(await readFile(root+'/reference/sinjid/original.swf')).digest('hex'),records};
 await writeFile(dir+'/'+phase+'-'+Date.now()+'-manifest.json',JSON.stringify(manifest,null,2));
 console.log(JSON.stringify(records.map(r=>r.name)));
}finally{await browser.close();}
