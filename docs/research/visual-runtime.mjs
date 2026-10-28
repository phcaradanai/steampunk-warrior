import {chromium} from '/Users/oyl-mac_m1/.npm/_npx/af752b90495482d7/node_modules/playwright-core/index.mjs';
import {mkdir,writeFile,readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const root='/Users/Projects/Steampunk-warrior';
const dir=root+'/docs/research/runtime/visual-2026-10-28';
await mkdir(dir,{recursive:true});
const browser=await chromium.connectOverCDP('http://127.0.0.1:9338');
const page=browser.contexts()[0].pages().find(p=>p.url().includes('/runtime/'));
if(!page)throw new Error('Original reference page missing');
await page.setViewportSize({width:800,height:600});
const records=[];
async function shot(name){const path=dir+'/'+name+'.png';await page.screenshot({path});records.push({name,path,at:Date.now()});}
const phase=process.argv[2]||'boot';
try{
 if(phase==='boot'){
  await page.goto('http://127.0.0.1:8765/runtime/');await page.waitForTimeout(3500);
  await shot('title');await page.mouse.click(517,440);await page.waitForTimeout(700);
  await shot('intro');await page.mouse.click(552,18);await page.waitForTimeout(700);
  await shot('menu');await page.mouse.click(75,325);await page.waitForTimeout(400);
  await shot('create');await page.mouse.click(456,430);await page.waitForTimeout(400);
  await shot('classes');await page.mouse.click(358,132);await page.waitForTimeout(700);
  await shot('hub');
 }else if(phase==='walk'){
  await page.keyboard.down('ArrowRight');
  for(let i=0;i<6;i++){await page.waitForTimeout(90);await shot('walk-'+i);}
  await page.keyboard.up('ArrowRight');await shot('stop');
 }else if(phase==='input'){
  const actions=JSON.parse(process.argv[3]);
  for(let i=0;i<actions.length;i++){
   const a=actions[i];
   if(a.click)await page.mouse.click(...a.click);
   if(a.key){await page.keyboard.down(a.key);await page.waitForTimeout(a.hold||80);await page.keyboard.up(a.key);}
   await page.waitForTimeout(a.wait||150);await shot(a.name||'input-'+i);
  }
 }
 const manifest={phase,authority:'Original unmodified SWF in Ruffle; ordinary input; screenshot intervals include capture overhead',original_sha256:createHash('sha256').update(await readFile(root+'/reference/sinjid/original.swf')).digest('hex'),records};
 await writeFile(dir+'/'+phase+'-manifest.json',JSON.stringify(manifest,null,2));
 console.log(JSON.stringify(manifest));
}finally{await page.keyboard.up('ArrowRight').catch(()=>{});await browser.close();}
