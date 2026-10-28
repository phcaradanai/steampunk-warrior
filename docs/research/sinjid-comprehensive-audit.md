# Sinjid 2004 — วิเคราะห์ต้นฉบับก่อนสร้าง Steampunk Warrior

27 ตุลาคม 2026 · ผู้ใช้เลือก Godot 2D สำหรับคอมพิวเตอร์

## สถานะ

วิเคราะห์ระบบที่ระบุได้ครบทุกหมวดและจัดบัญชีเนื้อหาของ Archive build นี้แล้ว ใช้ REA เก็บหลักฐานการถอด bytecode การตรวจ hash ภาพการเล่นปกติ และการทดสอบพฤติกรรมตัวแทนบนสำเนาที่ใส่เครื่องมือวัด ครอบคลุมห้องทั้ง11 การโหลด35ไฟต์หลัก+3ฝึก สกิลกดใช้ทั้ง16 และเส้นทางสำคัญของทุกระบบ ดู[ความครอบคลุมและข้อจำกัด](runtime-coverage.md) **ไม่ใช่คำรับรองว่าเล่นชนะครบ35ด่านตามความก้าวหน้าปกติ ทดสอบทุกแรงก์ ทุกผลสุ่ม ทุกแขนงเซฟ หรือฟังเสียงจริงครบแล้ว**

ผู้ใช้สั่งให้วิเคราะห์ด้วย REA ก่อนสร้าง และให้เกมใหม่มีเนื้อหา/ความลึกมากกว่าต้นฉบับ ขอบเขตเดิม6สกิล/9ไฟต์ถูกยกเลิก ไม่มีเกม Godot ถูกสร้างในรอบนี้

## ตัวตนของเกมและหลักฐาน

[หน้าอ้างอิง Museum](https://www.webdesignmuseum.org/flash-games/sinjid-shadow-of-the-warrior-in-2004) เชื่อมไป [Archive](https://archive.org/details/sinjid_sotw_flash); [หน้าเผยแพร่ผู้สร้าง](https://www.newgrounds.com/portal/view/209736) ยืนยันแนว RPG ที่เน้นต่อสู้ อุปกรณ์ สกิล และบอส

วิเคราะห์ Archive `sinjid-shadow-of-the-316817f.swf`,1,602,984ไบต์,SHA-256 `e258423f2a5887ff236a67eb6eaf674a8d573a5cdb721c20b79c831da4d9e008`. Headerจริงคือ SWF6/CWS,600×470,24fps,323rootframes; metadata Archive400×400ไม่ตรงกับไฟล์ URL SWFของ Museumตอบ403แม้ส่ง Referer จึงยังเทียบไม่ได้ว่า Museum/Archiveเป็นไบต์เดียวกัน ตัวเลขทั้งหมดผูกกับ Archive buildนี้

| Evidence | สิ่งที่พิสูจน์และข้อจำกัด |
| --- | --- |
| [REA export](rea-ffdec-evidence-retry.json), `ev_2895973c7147bd64e41b588ae68b61c9899e5ec6ad27afab76f72be80b5e49ef` | REAรันJPEXS26.4.0ถอดpcode จบexit0; ไม่อ้างว่าREAมีSWFdecompilerในตัว filesystem snapshotรอบนี้จำกัดจำนวนไฟล์/ขนาด จึงมีการตรวจซ้ำแบบเจาะจง |
| [REA verification](rea-verification-evidence.json), `ev_a93acc51a94ae52258fb00da51ed74b829000ec8049c6be8dc82583c7f85e1e0` | assertsผ่าน: source1,909/pcode1,909มีidentityชุดเดียวกัน ไม่มีรายการขาด; snapshotsเก็บhashSWFและ[manifest](reference-manifest.json)ครบ ยังมีprocess-samplingข้อจำกัด จึงไม่เรียกEvidenceทั้งก้อนว่าไม่truncated |
| [REAเปิดเกม](rea-runtime-load.json), `ev_6cecaed013c6100a232f0c25e341dbe68cf0f779991ed865b621117dc22af955` | SWFrequest200และRufflelogยืนยันSWF6/600×470/24fps; มีภาพ/เหตุการณ์จริง มีข้อจำกัดของCDPattachedeventcoverage |
| ผังสกิล `ev_47624bfb2f434f5325403a1a20fc5fef298bb75d33441c0be1806207390b9324` | เห็น19โหนดและเงื่อนไขระดับที่แสดงจริง |
| ไฟต์แรก `ev_5628c35c26ddc4cc01464f4e0be98a2498292eea73ac78ebfd8ddc6585373e3f` | ตัวละคร/ศัตรู/HP/โล่/คำสั่งจริง |
| ชนะ `ev_a881d06879234aeaa9439b5ae3634edd10121a247594194fa4f535d3fbd51204` | เงินรวม105และXP30หลังไฟต์แรก |

ใช้Ruffle0.7.1ตรึงเวอร์ชัน ภาพมาจากREA `capture_web_screenshot`; การกดพิกัดFlashทำด้วยPlaywrightแยก เพราะREAclickschemaระบุได้แค่locator-center ไม่มีpixelposition ไม่มีการเพิ่มเงิน/แก้ค่าผู้เล่นในไฟล์เดิมระหว่างการเล่นปกติ ไฟล์ต้นฉบับและงานส่งออกใช้ศึกษา ไม่ใช่assetsที่จะนำไปใส่เกมใหม่

## บัญชีทุกระบบ

| ระบบ | ผลจากไฟล์จริง | แหล่งรายละเอียดครบชุด |
| --- | --- | --- |
| Level design | ฐาน11ห้อง,collisiongrid20×11ช่อง×30px,ประตู/จุดเกิด/NPC/บริการ/ห้องสมุดและgateตามความก้าวหน้า | [ผัง+ตารางด่าน](sinjid-world-static.md),[ตำแหน่ง](sinjid-npc-placements.json) |
| ด่าน | Human20+Monster10+Dark5=35;Training3;9ไฟต์มีศัตรูคู่;35ไฟต์ไม่ใช่35พื้นที่เดินสำรวจ | [ทุกencounter/stat/reward](sinjid-world-inventory.json) |
| คลาส/เติบโต | 4คลาส ค่าเริ่ม/การโต/สกิลเริ่มต่างกัน ใช้ต้นไม้ร่วม ไม่ใช่4ต้นไม้แยก;95ไม่ใช่levelcapที่ยืนยัน | [คลาส/XP/stats](sinjid-skills-combat-static.md) |
| สกิล | 19nodes:โจมตี13/สนับสนุน3/ติดตัว3,rank10;levelgates1/5/10/15;บางโหนดต้องมีสองสกิลก่อนหน้า | [ครบ19สูตร/เงื่อนไข](sinjid-skills-static.json) |
| ต่อสู้ | Attack/LifePotion/ManaPotionเป็นพื้นฐาน;shieldHP/defenseแยก,หลบ/ความเร็ว,multi-hit,multi-target,ฮีล,ตามHP,อัญเชิญShadowReplicate | [สูตร/เทิร์น](sinjid-skills-combat-static.md) |
| สิ่งที่ไม่ได้มีตามแบบเดิม | ไม่พบGuardหรือข้อจำกัดติดตั้ง4สกิลแบบที่ข้อเสนอเดิมคิดขึ้น;ไม่พบgenericcooldown/statusframeworkในhandlersที่ตรวจ | [ขอบเขตการค้น](sinjid-skills-combat-static.md) |
| ศัตรู/บอส | 24gatewayarchetypesรวมDarkboss5แล้ว+TrainingWard;40encodedencounterframesเมื่อรวมtrainingและextra2;50livingenemyslots/51controllers | [ทุกAI/ท่า/ความน่าจะเป็น](sinjid-enemy-ai-static.md),[ข้อมูลเต็ม](sinjid-enemy-ai-static.json) |
| บอสและAI | selectedmovesสุ่มจากรายการ ไม่พบhealth-phasecontroller;บางencounterสืบทอดobjectจากframeก่อน จึงอ่านแต่localfileไม่ได้ | [inheritedcontrollers](sinjid-enemy-ai-static.md) |
| อุปกรณ์ | 60definitions:Weapon25/Shield17/Headgear10/Suit8;BloodRazorนิยามไว้แต่ไม่พบliteralเส้นทางได้มา แยกจาก59ที่มีหลักฐานแหล่งได้ | [ค่าทุกชิ้นCSV](sinjid-items-static.csv) |
| ร้าน/เศรษฐกิจ | 6ร้านgear45ข้อเสนอขาย,ราคาครบ,สูตรขายคืนตามประเภท,dropcandidates,Strengthrequirements,bag8+equipment4,quest/trade3items | [รายงานเศรษฐกิจ](sinjid-economy-static.md),[catalog](sinjid-items-static.json) |
| พลังงาน/ฝึก/พัก | เดินเสียenergy หมดแล้วช้าและเสียHP/MPตามtimeline;ฝึก3tier:ตีโล่ปกติได้XP,ตีแตกไม่คิดXP/energy,ตีHPหลังโล่หมดได้XPสองเท่า;พักฟรีเต็มจำกัด10ครั้ง | [การจัดการทรัพยากร](sinjid-world-static.md) |
| เรื่อง/บทคุย | Baka/Hattori/FujinและShadowTemple;Human20คือSamuraiคู่ไม่ใช่Baka;endingจดหมายเชื่อมเรื่องต่อ;NPCส่วนใหญ่fixedmessage/service | [เรื่อง+เงื่อนไข](sinjid-world-static.md) |
| เนื้อหาเสริม | library4texts;WhiteLeaves→Medicine→ขายซ้ำ;Mendo’sRing→moonให้แต้มสกิล | [sideactivities](sinjid-world-static.md) |
| UI/input/audio/save | flowเมนู/คลาส/กระเป๋า/สกิล/แพ้/ชนะ;arrows/WASD/Space/mouse;quality3ระดับ,SoundOn/Off;manualSharedObject31fields+arrays,savevariants | [schemaและUIครบ](sinjid-ui-save-static.md) |
| โครงสร้างภาพ/เสียง | sprites353/buttons194/vectorshapes1,019/morphs42/bitmaps6/sounds16/fonts7;timelineframecallbacksขับผลต่อสู้ | [assetarchitecture](sinjid-economy-static.md) |

WASP/WASP2มีโค้ดจริงแต่ยังไม่ยืนยันทางเข้าปกติ จึงไม่นับเป็นด่านเล่นได้เพิ่ม ส่วนShadowWolvesในหนังสือเป็นlore ไม่ใช่หลักฐานศัตรูในencounter

## สิ่งที่เห็นจากการเล่นปกติ

เห็นบทนำ/เมนู/4คลาส,เลือกWarrior,เปิด19-nodeผังสกิลและกระเป๋า,เดินArena0→Arena1→Arena2,เข้าต่อสู้Thiefแรกจนชนะ,กลับฐานพร้อมค่าคงเหลือ

Warriorเริ่มHP85/MP65/เงิน75/ยาทั้งสองอย่างชนิดละ5. ThiefมีHP60+shield20. Stabใช้MP15(65→50)และทำลายโล่ จากนั้นAttackจึงลดHPแยก. คำสั่งที่กดระหว่างanimationไม่ถูกใช้เป็นคำสั่งซ้อนอัตโนมัติ. ชนะแล้วเงิน75→105และXP0→30;ตัวเลขรางวัลบนหน้าชนะไหลเข้าค่ารวมจนเหลือ0 จึงห้ามอ่านภาพหลังanimationว่าได้รางวัล0. กลับฐานHP65/MP50/เงิน105/XP30 ไม่ได้ฟื้นเต็มเอง

## ข้อขัดแย้งและข้อบกพร่องที่แยกจากเอกลักษณ์เกม

- บางสกิลอ่านrankShurikensแทนrankตัวเอง;physical/magiccallbackและshieldบางจุดสลับ
- currentstageบางห้องระบุArena0ต่างจากชื่อห้อง แต่ห้องเหล่านั้นไม่มีทางเข้าไฟต์ที่ยืนยัน จึงยังไม่เรียกว่าreturnผิดที่เห็นจริง;saveบางvariantไม่เก็บmoon_q
- กระเป๋าเต็มแล้วดรอปหาย,tooltipโชว์เพียง4stats,SearchItemใช้assignmentในเงื่อนไข
- PoisonWaspไม่ได้พิสูจน์ว่ามีpoisonDoT;bossชื่อแตกต่างไม่ได้แปลว่ามีphase
- รีวิวประมาณจำนวนห้อง/gear/Monsterstageคลาดเคลื่อน:ใช้definition+guard+FrameLabelยืนยันแทน

รายละเอียดพร้อมตำแหน่งโค้ดอยู่ในรายงานแต่ละระบบ ข้อบกพร่องเหล่านี้ไม่ใช่สิ่งที่ควรคัดลอกไปเกมใหม่

## ความครอบคลุมก่อนออกแบบเกมใหม่

[รายงาน runtime พร้อม Evidence ID และขอบเขตของแต่ละชุด](runtime-coverage.md) แยกการเล่นไฟล์เดิมจากการทดสอบที่ตั้งค่าเริ่มต้นไว้ชัดเจน เครื่องมือวัดเปลี่ยนเพียง root DoAction หนึ่งแท็กในframe17 ของสำเนา ไม่แทนที่สูตรต่อสู้/รางวัล/เควสต์ของเดิม ตรวจเทียบ hash สำเนาและผลลัพธ์กับ REA ทุกชุด

| หมวด | บัญชีจากต้นฉบับ | พฤติกรรมที่ตรวจจริงและขอบเขต |
| --- | --- | --- |
| แผนที่/ประตู/collision/NPC | 11ห้อง ทุกexit,grid,NPC,gate | เดินปกติ3ห้อง;โหลดครบ11ห้องด้วยสำเนาวัดค่า;ประตูHuman/Darkและทางออกเรื่องทำงานตามguard ไม่ใช่เดินชนทุกช่อง |
| คลาส/สกิล/สูตร/XP | 4คลาส,19nodes ทุกguard/effect | เริ่มครบ4คลาส;กดใช้16activeผ่านhandlers/animationเดิม;ทดสอบสองparent,rank10,level5gate;XP4→5และแต้ม/ฟื้นพลัง;ไม่ครบ190คู่node/rank |
| encounter/AI/boss | 35gateway+3training+extra2 ทุกselectedactionรวมinherited | โหลด35หลัก+3ฝึก;Thiefชนะตามปกติ;มีไฟต์คู่/อัญเชิญ/ปลายทาง;ไม่ได้เล่นชนะทุกด่านหรือสุ่มทุกท่าบอส |
| ไอเทม/ร้าน/ราคา/ดรอป | ทุกdefinition/shop/price/handler | ซื้อ/ขาย/สลับ/ถอด/โบนัส/เงินไม่พอ/Strengthไม่พอ/มือค้าง/กระเป๋าเต็ม/MedicineTrade;ไม่ได้ซื้อทุกชิ้น |
| เรื่อง/คุย/quest/ending | บทคุยและเงื่อนไขที่ส่งออกครบ | ringรับ→moonแลกแต้ม,เต็มแล้วปฏิเสธ,leaves→medicine,Humangate/ending;ยืนยันMonster/Darkไม่บังคับด้วยcounterที่ตั้งไว้ |
| ฝึก/energy/แพ้/พัก | 3tier/ต้นทุน/settlement/recovery | ฝึกBasic3กรณี+ออกเก็บXP,หมดenergyเดินช้า/HP-MPลด/หยุดเมื่อเปิดเมนู;แพ้จากcounterattackเดิมแล้วRetryย้อนcounter/กลับห้องประตู;พัก10→9และโหลดกลับ9ในไฟล์เดิม |
| เซฟ/ตัวเลือก/เสียง | SharedObject31fields+arrays+variants,quality3ระดับ,sounds16 | Save/Loadค่าพักที่เปลี่ยน;LOW→HIGH,SoundOff→Onเปลี่ยนสถานะจริง;ยังไม่ยืนยันPCM/การได้ยินและเซฟทุกvariant |

ข้อสงสัยที่ปิดแล้ว: SWF6 `undefined+1` ให้1, callbackที่ละrandomargumentให้ค่าตัวเลข20ในfixture,ความเร็วเท่ากันทั้ง4เรียงenemy2→hero2→enemy1→hero1,โล่แตกไม่มีdamageทะลุ,ShadowStrikeอ่านrankShurikensจริง(333เทียบ142ในfixtureเดียวกัน),โบนัสlevel5และXPก้อนใหญ่ถูกหนีบใต้thresholdถัดไป

ข้อจำกัดคงไว้: Museumตอบ403จึงเทียบไบต์ไม่ได้;WASP/WASP2และBloodRazorไม่ยืนยันทางได้ปกติ;duplicateWASP2ไม่ถูกนับเป็นเนื้อหาเล่นเพิ่ม;ไม่ได้ทดสอบเซฟเสียหาย/ทุกvariantหรือทุกRNG/แรงก์/ความยากปลายเกมตามการเล่นปกติ;ตัววัดเสียงในสภาพแวดล้อมนี้อ่านศูนย์ทั้งOn/Offจึงไม่สรุปว่าเกมไม่มีเสียง ไม่มีช่องเหล่านี้ถูกเปลี่ยนเป็นผ่านด้วยการอ่านโค้ดอย่างเดียว

## เกมต้นแบบทำงานอย่างไร และบทเรียนสำหรับเกมใหม่

แกนของเกมคือเดินฐาน → คุย/อ่านข้อมูล → เลือกซื้อของและเรียนสกิล → เลือกประตู/ฝึก → ต่อสู้เป็นรอบ → รับรางวัลหรือรับผลแพ้ → กลับเตรียมตัว ฐานเป็นเครือข่ายบริการแตกแขนง ไม่ใช่ฉากตกแต่งเดียว ตำแหน่งร้าน อาหาร พัก ฝึก และประตูทำให้การเดินกับenergyสัมพันธ์กัน ส่วนbackgroundการต่อสู้Snow/Coast/Grass/Desertที่สุ่มเปลี่ยนไม่เพิ่มโจทย์leveldesignด้วยตัวเอง ดู[ผังทุกห้อง](sinjid-world-static.md)

การไล่ด่านไม่ใช่เพิ่มHPอย่างเดียว: Human9/15ใช้HPต่ำแต่speed50/60,ไฟต์คู่จับบทบาทมาร่วมกัน;LiquidMetalมีphysicaldefense70%,BloodSpiritมีshield4000,FallenNinjaมีspeed80,ShadowReaperHPเพียง1000แต่defenseทั้งสอง85% ตัวเลขนี้เป็นค่าตั้งจากsource ไม่ใช่คำรับรองสมดุล การขยายเกมใหม่จึงต้องมีโจทย์เตรียมbuild เลือกเป้าหมาย และตอบโต้ที่ต่างกันจริง

4คลาสใช้ผัง19โหนดเดียวกัน ความต่างอยู่ที่ค่าเริ่ม สกิลเริ่ม และการโต ความลึกมาจากparentหลายทาง/levelgate/การลงทุนrank/ประเภทdamage/โล่/ฮีล/หลายเป้าหมาย/อัญเชิญ การเพิ่มคลาสด้วยการเปลี่ยนชื่ออย่างเดียวไม่ตอบคำขอให้มากกว่าเดิม เกมใหม่ควรเพิ่มspecializationที่เปลี่ยนวิธีเล่นและมีข้อแลกเปลี่ยน พร้อมแสดงสูตร/ต้นทุนที่ตรงกับผลจริง

เรื่องเดิมเล่าผ่านบทนำ ข้อความNPC ห้องสมุด และending;เควสต์เสริมเป็นเงื่อนไขไอเทมเฉพาะมากกว่าระบบบทสนทนาแตกแขนงทั่วไป โลกsteampunkที่ผู้ใช้ต้องการจึงควรให้มนุษย์/สัตว์กลายพันธุ์สัมพันธ์กับเหตุการณ์ของเขต และให้การคุย/การเลือกส่งผลต่อภารกิจหรือending ไม่ใช่เปลี่ยนคำนินจาเป็นชื่อเครื่องจักรเท่านั้น เนื้อเรื่อง/บทคุย/ภาพของเกมใหม่ต้องเขียนขึ้นใหม่

## เกณฑ์ให้เกมใหม่มากกว่าต้นฉบับ

ผู้ใช้ยืนยันว่าต้องมากกว่าต้นฉบับแล้ว ตัวเลขเป้าหมายต่อไปนี้เป็นข้อเสนอวางแผนหลังรู้baseline ไม่ใช่อ้างว่าสร้างเสร็จหรือผู้ใช้เลือกตัวเลขเอง

| มิติ | Baselineจากไฟล์ | เป้าหมายเสนอ |
| --- | --- | --- |
| พื้นที่มีหน้าที่ต่างกัน | 11ห้องฐาน | ≥18ห้องใน6เขต มีทางเลือก/ทางลัด/เรื่องย่อย ไม่นับแค่เปลี่ยนฉากหลัง |
| authoredencounters | 35หลัก+3training | ≥60หลัก/เสริม+6trainingที่โจทย์ต่างกัน |
| สกิล/build | 19nodes/4classes | ≥36nodes(24active/12passive),4archetypes+8specializationsที่มีข้อแลกเปลี่ยนจริง |
| ศัตรู/บอส | 24gatewayarchetypesรวม5Darkbossesแล้ว (19นอกRift+5Rift) | ≥44archetypesรวม8bossesที่มีmechanics/phaseอ่านได้ |
| อุปกรณ์ | 60defined/59มีหลักฐานแหล่งได้ | ≥90obtainableที่เปลี่ยนbuildจริง มีแหล่งหาชัด |
| เรื่อง/quest | 1ending+2sideactivities | 5บท,≥12sidequests,บทคุยมีตัวเลือก/ผลจริง,3endings |
| ยุทธวิธี | shield/speed/multi-hit/multi-target/summon | รักษาแกนเดิม เพิ่มenemyintent,6statusที่โต้ตอบกัน,environmenthazardsเฉพาะเขต |
| ข้อมูล/ความปลอดภัยเซฟ | manual1profile,tooltipจำกัด | autosave+3slots,respec,statsครบ,ของล้นไม่หายเงียบ |

จำนวนต้องวัดสิ่งที่เข้าถึงและใช้ได้จริง ห้ามpaddingด้วยreskin/เปลี่ยนชื่อ/rankซ้ำ แล้วอ้างว่าลึกขึ้น แผนเกมฉบับใหม่ต้องเริ่มจากbaselineนี้ แปลงแต่ละเป้าหมายเป็นเนื้อหาที่มีหน้าที่/เงื่อนไข/ผลลัพธ์และเกณฑ์ตรวจรับ ก่อนเริ่มสร้างGodot
