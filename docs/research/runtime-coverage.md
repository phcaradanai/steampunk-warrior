# Sinjid — ขอบเขตการตรวจพฤติกรรมด้วย REA

27 ตุลาคม 2026 · อ่านร่วมกับ[รายงานหลัก](sinjid-comprehensive-audit.md) และ[การทบทวนอิสระ](coverage-review.md)

## แยกวิธีตรวจและระดับข้อสรุป

ไฟล์เดิมจาก Archive ถูกเก็บโดยไม่แก้ไข SHA-256 `e258423f2a5887ff236a67eb6eaf674a8d573a5cdb721c20b79c831da4d9e008` การเล่นปกติยืนยันบทนำ เลือกWarrior เดินArena0→1→2 ชนะThief รับXP30/เงิน30 กลับฐาน และอีกรอบยืนยันพัก10→9 กดSave โหลดกลับจากเมนู แล้วคุยElderเห็นพักเหลือ9 ดู[ภาพและหลักฐาน](runtime/)

การตรวจส่วนที่ต้องเข้าถึงเลเวลสูงใช้สำเนาSWF6ที่เพิ่มเครื่องมือวัดไว้ในroot DoActionเพียงหนึ่งแท็กที่frame17 ไม่แก้สูตรเกมเดิม ตัวรันตรวจจำนวน/ตำแหน่งแท็กที่เปลี่ยนทุกครั้ง และเก็บสำเนาตามhashใน `reference/sinjid/probe-versions/` ค่าHP/MP/สกิล/counter/ตำแหน่งที่ตั้งไว้ถูกบันทึกในinputsของผลแต่ละชุด จึงไม่ใช่หลักฐานว่าเล่นตามความก้าวหน้าปกติจนถึงทุกฉาก

REA capture-process บันทึกการทำงานของตัวรันที่กดปุ่มFlashผ่านPlaywright รวมทั้งhashของต้นฉบับ สำเนาวัดค่า และผลลัพธ์ JSON ที่เสร็จแล้ว ตัวตรวจ[verify_runtime_evidence.py](verify_runtime_evidence.py) ยืนยันการเชื่อมโยงนี้และรุ่นของเครื่องมือวัด/ตัวรัน ไม่ถือว่ารูปหน้าจออย่างเดียวพิสูจน์สูตรคำนวณ

## สิ่งที่ตรวจในแต่ละชุด

| ชุด | ขอบเขตที่ผ่าน | สิ่งที่ไม่ได้อ้าง |
| --- | --- | --- |
| census | เปิด11ห้องและ35ไฟต์หลัก+3ฝึกด้วยค่าเริ่มที่ตั้งไว้ ตรวจframe/ศัตรูมีชีวิต รวมไฟต์คู่/5Darkbosses;callbackตัวเลขและลำดับ4ความเร็วเท่ากัน | ไม่ได้ชนะ38ไฟต์ตามเส้นทางปกติ ไม่ได้เดินชนทุกcell ไม่รวมWASP/WASP2เป็นเนื้อหาเข้าถึงได้ |
| skills | เริ่มครบ4คลาส;กด16activeผ่านปุ่มและanimationเดิม ตรวจmana/ผล;สองparentปฏิเสธ0/1และรับ2,rank10cap,level4ปฏิเสธ/5รับ;ShadowStrikeพึ่งShurikensrankจริง | ไม่ครบ190คู่node/rank หรือทุกผลสุ่ม;passiveและทุกlevelgateมีบัญชีsourceแต่ไม่ได้ทดสอบทุกชุดผสม |
| quests | กระเป๋าเต็มปฏิเสธแหวน/รับดรอปไม่ได้,รับแหวน→moonใช้แหวนให้แต้ม,leaves→medicine;Darkgateและทางออกเรื่องปฏิเสธ/ยอมตามHumancounter | counterและไอเทมบางจุดตั้งไว้ ไม่ได้ฟาร์มHuman20เพื่อจบ;ยืนยันendingโดยMonster/Darkยังไม่ครบ |
| economy | ซื้อSilverKnife30/ถือที่cursor/สลับอาวุธโบนัสสุทธิ/ขายIronKnife7/ถอด/Strengthไม่พอ/เงินไม่พอ/ปิดขณะถือของ/วางbag/MedicineTrade3 | ไม่ใช่ซื้อขายทุกชิ้นหรือสุ่มlootทุกตาราง |
| progression | level4XP99/100+pending1000→level5XP249/250,skillpts2/statpts1;WarriorเลือกStrength+3และenergy+2;Continueฟื้นพลัง | เป็นfixtureสำหรับboundary ไม่ใช่เส้นXPที่เล่นจริงครบ;95ยังไม่ใช่capที่ยืนยัน |
| recovery | เข้าประตูHumanจริงcounter1→2;ตั้งHP1แล้วโจมตีให้enemycounterattackเดิมทำให้แพ้;Retryย้อนcounter2→1และกลับห้องประตูพร้อมHP/MP5/energy≤5 | ไม่ครอบคลุมทุกตัวเลือกแพ้หรือทุกsavevariant |
| training | เข้าBasicเดิม;ตีโล่ปกติXP+3/energy−2,โล่แตก+0/−0,ตีตัวที่รอด+6/−2;ออกเก็บXP9;energyหมดเดินช้าและHP/MPลด;เปิดเมนูหยุดลด | Intermediate/Advancedยืนยันโหลดและparametersร่วมกับsource;ไม่ได้ยืนยันรางวัลlethalbodyhitหรือทุกสกิลฝึก |
| options | เมนูOptions,qualityLOW→HIGH,SoundOff→Onเปลี่ยนสถานะ | การวัดPCMได้ศูนย์ทั้งOn/Off จึงยืนยันเสียงที่ได้ยิน เพลงเปลี่ยน และactioncueไม่ได้ ไม่แปลว่าเกมต้นฉบับไม่มีเสียง |

จำนวนrecordsคือภาพค่าระหว่างทาง ไม่ใช่จำนวนการทดสอบอิสระ ผลตรวจhashและEvidenceIDของแต่ละชุดอยู่ใน[ตารางหลักฐาน](runtime-evidence-table.md) และ[JSONที่ตรวจได้ซ้ำ](runtime-evidence-verification.json)

## ผลสำคัญที่ใช้ตัดสินการออกแบบ

- SWF6ให้ `undefined+1 == 1`;ละrandomargumentในcallbackเดิมยังได้damage20ในfixture ไม่ใช่NaN
- ความเร็วเท่ากันทั้ง4เรียงenemy2→hero2→enemy1→hero1;การทดสอบนี้แยกจากduplicatecontrollerของWASP2ที่ยังไม่ยืนยันเส้นทางเล่น
- shieldรับdamageก่อนและแตกแล้วไม่ส่งส่วนเกินเข้าร่างในhitเดียว;Shieldbreakระหว่างฝึกไม่ใช่doubleXP
- ShadowStrikeคงrank10แต่เปลี่ยนShurikens10→1ทำให้damage333→142ในfixtureเดียวกัน จึงเป็นrankdependencyที่ไม่ควรคัดลอก
- เลเวลขึ้นครั้งเดียวแล้วหนีบXPใต้thresholdถัดไปเมื่อรับXPก้อนใหญ่;อย่านำ95จากloopโบนัสไปประกาศเป็นmaxlevel
- Humancompletionพอสำหรับจบเรื่อง/เปิดทางDark;Monster/Darkเป็นทางเลือกในbuildนี้

## ข้อจำกัดและการเก็บรอบที่ไม่ผ่าน

MuseumSWFตอบ403 จึงไม่มีหลักฐานเทียบไบต์MuseumกับArchive;ข้อสรุปทั้งหมดผูกกับArchivebuildที่ระบุhash ไม่รับรองAdobeFlashแท้ทุกเวอร์ชันเพราะruntimeใช้Ruffle0.7.1

REAบางชุดมีprocesssamplingpartialระหว่างจบงาน เก็บflagจริงไว้ ไม่ลบทิ้ง แต่ผลexit0และhashของไฟล์ทั้งสามต้องครบจึงผ่านการตรวจเชื่อมโยง ไม่ตีความว่ารู้processทุกตัวจากsampling

เก็บรอบล้มเหลวและบันทึกวิเคราะห์ไว้: การรอanimationสั้นเกิน,การseekฉากที่ยังไม่ล้างNPC,การคลิกก่อนหน้าต่างเลเวลพร้อม และตัววัดเสียงไม่ให้สัญญาณ เป็นข้อจำกัดของfixture/การวัด ไม่ใช่หลักฐานบั๊กเกม ดู[skills](shurikens-runtime-investigation.md),[training](training-runtime-investigation.md),ไฟล์attemptและcleanup-attempt ผลสรุปอ้างเฉพาะรอบสำเร็จที่ผูกhashแล้ว

ยังไม่ได้เล่นชนะทุกด่านตามปกติ ตรวจทุกrank/RNG ทดสอบsaveเสียหายหรือทุกvariant/ทุกfield ฟังเสียงจริง วัดระยะเล่น/ความสนุก/สมดุลปลายเกม หรือพิสูจน์ทางได้ของBloodRazor/ทางเข้าWASP/WASP2/Blacksmith ส่วนเหล่านี้ระบุแยกจากการจัดบัญชีระบบครบ ไม่ใช้คำว่า100%behaviorverified

งานGodotยังไม่เริ่ม: เป้าหมายเนื้อหาที่เพิ่มในรายงานหลักเป็นข้อเสนอสำหรับออกแบบเกมใหม่ ไม่มีการนำassets/บทคุยของต้นฉบับไปใช้ในเกมใหม่
