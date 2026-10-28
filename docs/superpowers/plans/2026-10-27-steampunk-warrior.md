# Steampunk Warrior Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking. Execute natively unless the user selects another method; review gates do not authorize product changes before design approval.

**Goal:** สร้างGodot2D desktop RPGต้นฉบับใหม่ให้ครบ5อาชีพ22สกิล6บอส12ห้อง62อุปกรณ์4การฝึก ตามขอบเขตผู้ใช้

**Architecture:** Data-defined contentแยกจากcanonicalstateและUI. สูตรต่อสู้/ธุรกรรมเป็นฟังก์ชันทดสอบได้ก่อนทำanimation;sceneแสดงผลจากeventเท่านั้น. GameSessionคุมการcommitความคืบหน้า/รางวัลและSaveServiceเขียนsnapshotที่commitแล้ว

**Tech Stack:** Godot4stable/GDScript,2DControl/Node2D/CharacterBody2D,JSONcatalogs,headlessasserttests;ไม่เพิ่มpluginจนมีเหตุผลจากงานจริง

**Spec:** [แบบฉบับขยาย](../specs/2026-10-27-steampunk-warrior-expanded-design.md),[บัญชีเนื้อหา](../../design/steampunk-content-plan.md),[JSONวางแผน](../../design/steampunk-content-plan.json)

สถานะ: แผนพร้อมตรวจทานก่อนอนุมัติสร้าง จำนวนผู้ใช้ยืนยันแล้ว แต่ชื่อ/สูตร/เรื่อง/หน้าที่ใหม่ยังเป็นข้อเสนอ แผนนี้ไม่ใช่หลักฐานว่ามีเกมทำงาน ไม่มีproductcodeถูกสร้างในช่วงวางแผน

## Global Constraints

- เล่นคนเดียวออฟไลน์ Godot2D desktop;macOSทดสอบจริงบนเครื่องนี้ Windows64-bitต้องผ่านเครื่องWindowsก่อนรับรอง
- 5classes/22learnednodes(19active3passive)/6bosses/12walkablerooms/62obtainablegear/4training;36encountersรวม6bossesและแยกจากtraining
- 8sidequests/5chapters/3endingsเป็นข้อเสนอของผู้ช่วย;เปลี่ยนสาระตามผลreviewก่อนเริ่มทำ
- ไม่ใช้assets/บทคุยจากSinjid;วิจัยเดิมอยู่reference/และdocs/research/ไม่ถูกpackในเกม
- ภาษาไทย,1280×720design,ทดสอบ1920×1080และ960×540,keyboard/mouseพร้อมfocusและrebinding
- โลกtop-down,ต่อสู้เป็นรอบ;คำสั่งAttack/Guard/Vent/Potionไม่นับใน22สกิล
- Godotยังไม่พบในPATH/Applicationsตอนวางแผน:หลังแบบอนุมัติเลือกเวอร์ชันstableที่ใช้จริง บันทึกversion/buildhashก่อนสร้างและตรึงตลอดรอบ ไม่มีการอ้างว่าเวอร์ชันหนึ่งติดตั้งแล้ว
- ไม่ทำtestเพิ่มให้ข้อความ/สีที่แก้เล็กน้อย;ใช้unit testsเฉพาะสูตร ธุรกรรม การเปลี่ยนstate เซฟ และการเข้าถึงเนื้อหา ซึ่งมีความเสี่ยงจริง

## Review Focus

1. กดซ้ำ/โดรนฆ่าซ้อน/actioncancelต้องไม่จ่ายcostหรือrewardสองครั้ง — task2/3/4
2. ก้อนXPข้ามหลายlevel,rankgate/respecและสวมถอดโหลดกลับต้องไม่ทำstatdrift — task3/4
3. เงิน0/energy0/กระเป๋าเต็มต้องไม่ทำให้ผู้เล่นติดทางหรือของรางวัลหาย — task4/6
4. เลือกQ04/Q08คนละทางและกลับpostgameต้องรักษาendinggates/firstclearได้ — task5/9
5. เซฟเขียนขัดข้อง/unknownID/futureversionต้องคงเซฟดีและแจ้งกู้คืน — task7

---

## โครงไฟล์และข้อตกลงที่ใช้ร่วมกัน

Rootเกมใหม่คือ `game/` ไม่สร้างโครงการทับreference. แหล่งข้อมูลruntimeจะเป็นJSONที่คัดเฉพาะเนื้อหาใหม่จากบัญชีแผนและเติมค่าผ่านbalancegate ไม่loadบัญชีวิจัยต้นฉบับ

| ไฟล์ที่จะสร้าง | รับผิดชอบ |
| --- | --- |
| game/project.godot; game/main.tscn | ตั้งค่ารัน/หน้าจอ/InputMapและเปลี่ยนscene |
| game/core/content_catalog.gd | load/validate8catalogและค้นด้วยID |
| game/core/game_session.gd | canonicalplayer/world/quests/firstclears;commitผลสำเร็จครั้งเดียว |
| game/combat/combat_resolver.gd | pureaction/target/damage/status/phase/cooldown |
| game/combat/combat_controller.gd; combat.tscn | inputlock/turn/intent/แสดงevents |
| game/rpg/progression.gd; inventory_service.gd | derive/XP/skills/respec และtransactionซื้อขายสวมรับของ |
| game/story/quest_service.gd; dialogue_service.gd | questobjectives/flags/choicegraph/endingconditions |
| game/world/world_controller.gd; room.tscn; player.gd | movement/collision/exit/interact/checkpoint/fasttravel |
| game/training/training_service.gd | unlock/objectives/firstreward/repeat25% |
| game/save/save_service.gd | versionedatomicJSON/backup/restore/slots |
| game/ui/*.tscn; *.gd | title/class/HUD/shop/skills/dialogue/quests/settings/results |
| game/data/{classes,skills,items,enemies,encounters,rooms,training,story}.json | 内容数据และstableIDs;storyรวมquests/dialogue/endings |
| game/tests/run_tests.gd; test_*.gd | headlessSceneTreerunnerและdomainassertions |
| game/art/; game/audio/; game/ASSET_CREDITS.md | เฉพาะassetsใหม่/มีlicenseและเครดิต |
| game/export_presets.cfg; docs/release/desktop-checklist.md | buildsและผลทดสอบจริงตามแพลตฟอร์ม |

SharedresultของoperationคือDictionary `{ok:bool, reason:String, state:Dictionary, events:Array}`;ถ้าไม่ผ่านต้องคืนstateเท่าinputและeventsว่าง Event `{id:String,type:String,payload:Dictionary}` ใช้IDซ้ำปฏิเสธที่GameSession. Dictionaryจากไฟล์/เซฟต้องผ่านschemaก่อนใช้;ภายในใช้typedmethod/Arrayและenumที่จำเป็น ไม่สร้างframeworkserialisationเพิ่ม

canonicalplayer: class_id/level/xp/base_attributes/skill_ranks/items/equipment/stash/currency/current_hp/current_fp/energy. Sessionเพิ่มquest_states/world_flags/first_clears/claimed_rewards/checkpoint(room_id/spawn_id). Derivedstatsไม่saveเป็นความจริง Combatstateมีactors/round/acted_ids/pressure/seed/statuses/cooldowns;โดรนเป็นowner-linked effectไม่อยู่ในactorsหรือturnorder;ไม่saveกลางไฟต์ในรุ่นนี้

คำสั่งverificationใช้ `godot` เป็นชื่อแทนbinaryเวอร์ชันที่ตรึงจริง;ถ้าไม่อยู่PATHให้ใช้absolute pathที่ตรวจแล้ว บันทึกคำสั่งจริงลงreleasechecklist. `godot --headless --path game --script res://tests/run_tests.gd -- --suite NAME` ต้องexit0และพิมพ์passed/failed count;assertfailต้องexitnonzero

### Task 1: โครงการที่เปิดได้และบัญชีเนื้อหาที่ตรวจอัตโนมัติ

**Files:** project.godot/main.tscn,core/content_catalog.gd,data/*.json,tests/run_tests.gd,test_catalog.gd

**Interfaces:** `ContentCatalog.load_all(root:String)->Dictionary`, `get_entry(kind:String,id:String)->Dictionary`, `validate_all()->Array[String]`. คืนerrorlistครบก่อนเริ่มเกม ไม่ยอมmissingrefเงียบ

- [x] ยืนยันแบบ/ค่าที่แก้หลังreview,ตรวจGodotจริงและตรึงversion;ตั้งโครงการใหม่ในgame/พร้อมmainและtestentrypointในงานเดียวกัน
- [x] เพิ่มtest_catalog_counts_and_references: assert5/22/6/12/62/4,19active3passive,gear26/17/10/9,36encounters;ฉีดIDซ้ำ/parentcycle/missingroomแล้วต้องerror
- [x] รันcatalogsuiteให้เห็นล้มเหลวจากcatalogยังไม่ครบ แล้วสร้างcatalogด้วยstableIDในแผน เติมschemaของแต่ละkindให้ครบ อ่านเฉพาะgame/data
- [x] ตรวจroomgatesด้วยreachable-statewalkตามkeyที่จะได้ก่อนgate;ปฏิเสธgateที่keyอยู่หลังประตูตัวเอง และตรวจทุกgearมีแหล่งได้โดยทุกclass
- [x] รันcatalogsuiteผ่าน+เปิดmainได้;เก็บversion/checkresult และcheckpointการเปลี่ยนแปลง (commitเมื่อworkspaceเป็นGitที่จัดไว้แล้ว ไม่แสร้งว่าrepoปัจจุบันเป็นGit)

### Task 2: สูตรต่อสู้และการยืนยันaction

**Files:** combat/combat_resolver.gd,tests/test_combat.gd;อ่านdata/skills,enemies

**Interfaces:** `CombatResolver.apply_action(state:Dictionary,action:Dictionary,rng:RandomNumberGenerator)->Dictionary`, `get_turn_order(actors:Array[Dictionary],acted_ids:Array[String])->Array[String]`;resultเป็นsharedformat,ไม่mutateinput

- [x] เพิ่มfailingtest_damage_barrier_and_multihit: armor/resistที่0/100,barrierแตกไม่spill,hitถัดไปถึงHP,minimum1;fixedseedตรงผลคำนวณspec
- [x] เพิ่มtest_pressure_commit_boundaries:99+2ปฏิเสธโดยcostไม่ลด,100ยังVent/Attackได้,Ventไม่ต่ำ0;targetตายก่อนcommitปฏิเสธโดยไม่เสียFP;กดcommitIDซ้ำไม่ลดFPอีก
- [x] เพิ่มtest_status_order_and_phases:Wetล้างHeated,electricWet×1.25,duration/refresh/Sealed,เสมอinitiativeเรียงID,Haste/Staggeredจัดคิวเฉพาะunactedไม่เพิ่มaction,statusใหม่บนตัวเองไม่หมดทันที,intentล็อกผ่านthresholdจนactionจบแล้วphaseถูก,โดรน3owneractionsและไม่เกิน1,ไม่มีactionเพิ่มจากโดรนในinitiativequeue
- [x] ใช้resolverร่วมทุกฝ่ายตามสูตรspec;หลังeffectชุดเดียวตรวจตาย/จบหนึ่งครั้ง แยกeventจากเวลาanimation
- [x] รันcombatsuiteและtestskipanimations_equal_resultทั้งเปิด/ข้ามanimation:state/cost/seed/ผลรวมเหมือนกัน

### Task 3: ตัวละคร สกิล และเลเวล

**Files:** rpg/progression.gd,tests/test_progression.gd;data/classes,skills

**Interfaces:** `Progression.new_player(class_id:String)->Dictionary`, `derive(player:Dictionary,catalog:Dictionary)->Dictionary`, `gain_xp(player:Dictionary,amount:int)->Dictionary`, `learn_skill(player:Dictionary,skill_id:String)->Dictionary`, `respec(player:Dictionary)->Dictionary`

- [x] เพิ่มtest_five_class_starts_equal_budget:VIT/STR/INT/AGIตามcatalog,starterrank1,traitทำงานต่างกัน,ไม่มีaccessล็อกsharedskills
- [x] เพิ่มtest_xp_multiple_levels_remainder_and_cap:รางวัลก้อนใหญ่ขึ้นหลายครั้งไม่ทิ้งเศษ,แต้มตรงจำนวนlevelที่ผ่าน,level30ไม่เกินcap;deriveไม่เปลี่ยนbase
- [x] เพิ่มtest_skill_prerequisites_cost_rank_and_respec:ทุกnode/rank1–10ผลตามspec,parentsทั้งสอง,levelgate,costtooltipตรงresolver,35แต้มทั้งแคมเปญ,คืนแต้มยกเว้นstarter
- [x] สร้างprogressionและreusecalculationในการแสดงtooltipจริง ไม่คำนวณcopyแยกในUI
- [x] รันprogressionsuite;ตรวจ5classbuildที่ต่างกันในcombatfixedseed ไม่ใส่คำรับรองสมดุลก่อนplaytest

### Task 4: ของ ร้านค้า และรางวัลที่จ่ายครั้งเดียว

**Files:** rpg/inventory_service.gd,core/game_session.gd,tests/test_inventory.gd,test_rewards.gd

**Interfaces:** `InventoryService.transact(player:Dictionary,request:Dictionary,catalog:Dictionary)->Dictionary`, `GameSession.commit_result(kind:String,payload:Dictionary)->Dictionary`, `snapshot()->Dictionary`;sessionใช้Progressionจากtask3,transactionส่งreasonเมื่อไม่ผ่าน

- [x] เพิ่มtest_purchase_equip_unequip_no_drift:เงินพอดี/ไม่พอ,levelไม่ถึง,slotผิด,สวมถอด100ครั้งbaseคงเดิมและderiveตรง,ขายfloor35%,ยาstack99
- [x] เพิ่มtest_overflow_and_reward_idempotence:bag24เต็มส่งgearเข้าคลังR01และeventแจ้ง;questkeyไม่กินslot;victoryIDเดียวจากhero/โดรน/กดซ้ำclaimได้ครั้งเดียว
- [x] สร้างtransactionsจากcopy canonicalstate ตรวจเงื่อนไขครบก่อนcommit;ราคา/level/gearreferenceต้องมาจากcatalog
- [x] สร้างfirst-clearต่างrepeat25%XPและbossitemไม่ซ้ำ;applyXP/เงิน/item/flagเป็นcommitเดียวไม่เซฟครึ่งรางวัล
- [x] รันinventory/rewards suite และตรวจsnapshotก่อน/หลังrejectedtransactionเท่ากันทุกfield

### Task 5: เรื่อง บทคุย เควสต์ และทางเลือกจบ

**Files:** story/quest_service.gd,dialogue_service.gd,data/story.json,tests/test_story.gd

**Interfaces:** `QuestService.on_event(session:Dictionary,event:Dictionary)->Dictionary`, `DialogueService.available_choices(node_id:String,session:Dictionary)->Array[Dictionary]`, `choose(node_id:String,choice_id:String,session:Dictionary)->Dictionary`, `get_ending_options(session:Dictionary)->Array[String]`;แจกrewardผ่านtask4เพียงจุดเดียว

- [x] เพิ่มtest_quest_rewards_once_all_choices:Q01/Q03/Q05/Q07/Q08สองทางchoiceได้skillpointอย่างละ1,turned_inซ้ำไม่ได้,objectiveก่อนรับquestไม่หายเมื่อspecระบุเป็นworldflag
- [x] เพิ่มtest_three_endings_and_missing_evidence:Shutdown/Seizeเสมอ,Cureต้องQ04rescue+Q08turned_in;UIระบุสิ่งขาดก่อนfinalconfirm;Q04harvestเตือนและยืนยันCureปิดถาวรแต่Shutdown/Seizeยังได้ ห้ามปลอมrescueflag
- [x] เขียนdialoguegraphครบ8NPC/5บท/8questพร้อมlocalizationkey,choiceflagsมีผลต่อข้อความ/route/endingที่อ้างจริง ไม่มีchoiceที่ทำmainpathปิดถาวรโดยไม่บอก
- [x] ทดสอบQ04routeเลี่ยงหนึ่งไฟต์ด้วยวาล์ว ไม่ทำให้gear62หรือQ08เข้าถึงไม่ได้;postgameกลับR11คงfirstclear/gearและเข้าfinalใหม่ไม่ให้รางวัลซ้ำ
- [x] รันstorysuiteและอ่านบทคุยหลักต่อเนื่องภาษาไทย ตรวจmotivationมีรา/ลิน/คนงานก่อนผูกกับฉาก

### Task 6: โลกเดินได้ การฝึก และวงจรเล่นช่วงแรก

**Files:** world/world_controller.gd,room.tscn,player.gd;training/training_service.gd;tests/test_world.gd,test_training.gd;world/combat/UIscenesที่ใช้ในslice

**Interfaces:** `WorldController.can_travel(from_id:String,to_id:String,session:Dictionary)->bool`, `enter_room(room_id:String,spawn_id:String)->void`, `TrainingService.start(id:String,session:Dictionary)->Dictionary`, `settle(id:String,objectives:Array[String],session:Dictionary)->Dictionary`

- [x] เพิ่มtest_energy_zero_can_return_and_rest:energy0/เงิน0ยังกลับR01และพักฟรีได้ ห้ามเริ่มไฟต์ใหม่/การเดินไม่drain;แพ้คืนcheckpointไม่เพิ่มcounterก่อนชนะ;จุดencounterที่clearไม่ขวางทางกลับและReplayต้องสั่งเอง;บอสReplayเฉพาะpostgame
- [x] เพิ่มtest_training_four_unlocks_and_claims:เปิดตามB01/B02/B04,firstXP40/80/120/160,repeat25%,ออกกลางทางได้XPเฉพาะobjectiveเสร็จและไม่claimซ้ำจากUI
- [x] สร้างgreyboxR01/R03/R04ด้วย32grid/180px/s/ทาง≥96px/interaction64px,ต่อR02เป็นผ่านทางและร้านแบบgreybox;เปิดชนิดห้องครบตามIDในtask9
- [x] ต่อactualcombatviewจากresolver/controllerและmodalfocus,เลือก2classes6skillsเพื่อตรวจวงจรR01→B01→reward→พัก/แพ้ โดยแสดงสถานะslice
- [x] รันworld/training suitesและเล่นsliceจริงด้วยmouse+keyboard ให้ผู้เล่นอ่านintent/วาล์วก่อนเจอบอส;แก้flowก่อนลงฉากจริง

### Task 7: เซฟเต็มข้อมูลและการกู้คืน

**Files:** save/save_service.gd,tests/test_save.gd;core/game_session.gd,ui/save_menu.tscn

**Interfaces:** `SaveService.save_slot(slot_id:String,snapshot:Dictionary)->Dictionary`, `load_slot(slot_id:String)->Dictionary`, `list_slots()->Array[Dictionary]`;manual01–03/autosave/backupต่อslot,settingsfileแยก

- [x] เพิ่มtest_save_roundtrip_all_canonical_fieldsหลังequip/learn/questchoice/rest/firstclearรวมcurrentHP/FP/energyและoverflowstash;loadแล้วderiveเท่ากันและไม่มีrewardclaimใหม่
- [x] เพิ่มtest_failed_write_preserves_good_saveด้วยfile-I/Otestseam;tmpinvalid/renamefail/unknownID/futureversionไม่เขียนทับต้นฉบับและloadbackupเมื่อผู้เล่นเลือก
- [x] ทำatomicwriteตามspec;slotpathรับเฉพาะwhitelist ห้ามนำslotnameอิสระไปเป็นfilesystempath;schema version1และtype/rangevalidationก่อนapplystate
- [x] ทำautosaveเฉพาะcommit/roomtransitionที่ไม่มีcombat/heldtransaction;pre-finalcheckpointใช้autosaveเดิมก่อนconfirm ไม่เพิ่มslotลับ
- [x] รันsave suiteพร้อมปิดเปิดเกมจริงจากcontinue ตรวจคืนcheckpointและภารกิจไม่หล่น

### Task 8: หน้าจอและการควบคุมที่อ่านไทยได้

**Files:** ui/title,class_select,hud,inventory,shop,skill_tree,dialogue,quest_log,settings,result,ending scenes/scripts;ui/input_settings.gd;tests/test_ui_state.gd

**Interfaces:** viewsส่งrequestไปGameSession/Controller,รับsharedresult; `InputSettings.rebind(action:String,keycode:int)->Dictionary`, `restore_defaults()->void`;focus/targetstateมีเจ้าของที่activeviewเท่านั้น

- [x] เพิ่มtest_modal_and_action_locks:เปิดmodalซ้อนไม่ได้,Escปิดชั้นเดียว,กดย้ำระหว่างactionไม่queueเป็นcostใหม่,rebindingชนแจ้งก่อนแทน
- [x] สร้างหน้าจอครบตามspec ใช้tooltipsจากderive/skilldefinitionจริง แสดงHP/FP/energy/pressureตัวเลข+icon และintent/targetก่อนconfirm
- [x] เพิ่มquestlog/backlog/textspeed/instanttext,settingsmaster/music/sfx/reducedshake/flash;Thai fontตรวจlicenseและdiacriticsก่อนเลือกถาวร
- [x] ตรวจkeyboardonlyเดินเมนูได้ทุกปุ่ม,focusคืนถูกหลังปิด,1280×720/1920×1080/960×540ไม่ทับข้อความ;ทำmanualchecksไม่เขียนtestสี/ระยะทุกพิกเซล
- [x] รันui-state suiteและเล่นวงจรต่อจากslotที่loadเพื่อจับstateค้าง

### Task 9: ผลิตเนื้อหาเต็มและปรับสมดุล

**Files:** data/*.json,world/rooms/R01–R12.tscn,art/audio,ASSET_CREDITS.md,tests/test_campaign.gd;docs/design/content-completion.csv

**Interfaces:** ใช้catalog/resolver/sessionเดิม ไม่เพิ่มสูตรเฉพาะsceneหรือscriptbossที่ข้ามtransaction;content-completionตามstableIDและsourceacquisition

- [x] เติม36encountersตามจำนวนห้อง3/3/3/4/3/4/3/4/4/5,25enemyarchetypesรวม6boss,22nodesทุกrankและ62gear;กำหนดstats/โบนัสไอเทมให้sidegradeต่างจริงในbalancegate
- [x] ทำบอส6intent/phaseและT04ต่างจากT03,ครบ12ห้อง/ทางลัด/วาล์ว/หลักฐานQ08;R11มีdecisionที่เปลี่ยนendingจริง
- [x] เพิ่มtest_campaign_reachability_each_class:mainpath/62gear/all22nodes/4trainingเปิดได้โดยไม่อาศัยitemหลังgateตัวเอง;มีtest3endingด้วยflagsตามเส้นเรื่องจริงและfirstclearซ้ำไม่เพิ่ม
- [x] ทำartdirectionชุดเล็กก่อนผลิตครบ:ตัวละคร/ศัตรู/ห้อง/skillicon/gearicon,ตรึงstyleแล้วขยาย;creditsใหม่ทุกasset ไม่มีreferenceSWFpackเข้าบิลด์
- [x] เพิ่มเพลงhub/explore/combat/bossและcueสำคัญ ตรวจplaybackจริง/duckingเมื่อคุย,ลดflash/สั่นไม่ทำintentหาย
- [x] เล่นจบ5อาชีพในfreshsaveโดยไม่repeatบังคับ,จดturncount/จุดตาย/เงินซื้อupgrade/เลเวลปลายเกมเป้า20–25;ปรับnumericbalanceไม่ลดcountsหรือปิดความต่างอาชีพ
- [x] ตรวจcompletioncsvไม่มีentryที่นับผ่านด้วยแค่ชื่อ/fileplaceholder;แยกพบได้/ได้มา/ใช้ได้/tooltipตรง/ภาพเสียงครบ

### Task 10: Desktop buildและตรวจรับสุดท้าย

**Files:** export_presets.cfg,docs/release/desktop-checklist.md,artcredits;outputแยกgame/builds/ไม่packresearch

**Interfaces:** ใช้buildจากversionตรึงและcontenthashเดียวที่ผ่านtests;ไม่publishออกบริการภายนอกโดยไม่มีคำสั่งผู้ใช้

- [x] รันsuiteทั้งหมดและheadlessimportต้อง0script/parsererrors;รันasset/referenceexclusioncheckและสรุปcontentcountsเทียบคำขอทั้ง6มิติ
- [x] exportmacOSพร้อมresourceครบ เปิดเกมจากbuildนอกeditor/newgame/load/ending/quitแล้วเปิดใหม่ ตรวจสิทธิ์เขียนsaveและไทย/เสียงจริง
- [ ] ทำWindowspresetและbuildแล้ว;คงงานตรวจบนWindowsจริง(window/fullscreen/input/audio/3slots+backup)ไว้โดยไม่รับรองจากเพียงexportสำเร็จ
- [x] ตรวจเซฟก่อนfinalconfirmและpostgameคงอุปกรณ์W26/questflags,unknownversion/backupdialogภาษาไทยชัดเจน
- [x] บันทึกผลที่ผ่าน/ไม่ผ่านพร้อมข้อจำกัดแพลตฟอร์มและส่งไฟล์ติดตั้งกับคำแนะนำเปิดเกม;ไม่เรียกdoneหากcountsลดหรือแพลตฟอร์มที่รับรองยังไม่เคยรัน

## ลำดับและขอบเขตการลงมือ

ทำ1→2→3→4→5→6→7→8→9→10โดยนำUIขั้นต่ำมาใช้ในsliceได้ แต่ความรับผิดชอบต้องตามไฟล์ข้างบน ไม่ต้องขนานหลายผู้สร้างในงานแรกเพราะstate/transactionพึ่งกันสูง ใช้freshreviewตอนจบsliceและก่อนreleaseเพื่อหาช่องที่ผู้สร้างมองข้าม

Checkpointหลังทุกtaskหมายถึงdeliverableทดสอบได้ ไม่ใช่แค่เพิ่มไฟล์ จุดทบทวนsliceต้องไม่ถูกใช้ยกเลิกจำนวนเต็มที่ผู้ใช้ระบุ หากแพลตฟอร์ม/assetlicense/สมดุลทำไม่ครบให้ระบุสิ่งค้างตรง ๆ ไม่เติมplaceholderแล้วนับเสร็จ

## Self-review

ตารางจำนวนผู้ใช้→task1/9/10;classes/skills/XP→task2/3;bosses/AI→task2/9;leveldesign/roomgates→task1/6/9;gear/economy→task4/9;training→task6;story/dialogue/ending→task5/9;save→task7;UI/input/audio/accessibility→task8/9/10 ทุกReviewFocusมีtestที่เจ้าของระบบ ไม่มีการติดตั้งengineหรือเขียนเกมในขั้นวางแผนนี้

ผลbuildercheck: เติมสัญญา4เรื่องตามแบบฉบับขยายและใส่testในtask2/5/6แล้ว ผู้ตรวจยืนยันว่าไม่ต้องหยุดวางแผนเพื่อถามรายละเอียดเหล่านี้ เพราะเป็นข้อเสนอที่ผู้สร้างตัดสินในแบบได้


Execution completed2026-10-28. Checkboxes reflect documented implementation/evidence in docs/release/desktop-checklist.md,including explicit Windowsruntime/IntelMac/notarization limits;they do not certify untested platforms.
