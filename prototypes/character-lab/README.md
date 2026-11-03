# Character Atelier — ตัวต้นแบบ 01 (Blender 3D Toon + เส้นขอบ ตามหลักฐาน REA)

คำถาม: ท่าทาง น้ำหนักการเดิน การเข้าปากท่อ การเดินเข้าโจมตี และอุปกรณ์ 3D ที่เห็นบนตัว ไปในทิศทางที่ผู้ใช้ต้องการหรือไม่?

เปิด `Open-Character-Lab.command` บนเครื่องนี้ หรือเปิด `project.godot` ใน Godot 4.7 แล้วกด Run.
หากต้องการสร้างหรือแก้ไขโมเดล 3D ใน Blender 5.2 สามารถเปิด `vesper_warrior.blend` หรือรันสคริปต์สร้างโมเดลอัตโนมัติ:
```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python blender/build_vesper.py
```
ศัตรู N01 หนูกัดท่อ สร้างจากสคริปต์ (ส่งออก `game/art/characters/rat.glb` และภาพเทียบใน `blender/renders/rat_*.png`):
```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python blender/build_rat.py
```
ศัตรู N02 หมาควัน (ส่งออก `game/art/characters/dog.glb`, ใช้ฟังก์ชันร่วมใน `blender/creature_kit.py`):
```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python blender/build_dog.py
```
ศัตรู N03 ค้างคาวเอเธอร์ (ส่งออก `game/art/characters/bat.glb`):
```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python blender/build_bat.py
```
ศัตรู N04 ตะขาบทองแดง (ส่งออก `game/art/characters/centipede.glb`):
```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python blender/build_centipede.py
```
ศัตรู N05 ด้วงเกราะ (ส่งออก `game/art/characters/beetle.glb`):
```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python blender/build_beetle.py
```
ศัตรู N06 แมงมุมแก้ว (ส่งออก `game/art/characters/spider.glb`):
```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python blender/build_spider.py
```
ศัตรู N07 หมูป่า (ส่งออก `game/art/characters/boar.glb`):
```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python blender/build_boar.py
```
ศัตรู N08 นกกระสาทองเหลือง (ส่งออก `game/art/characters/heron.glb`):
```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python blender/build_heron.py
```
ศัตรู N09 หมาป่าป่าไม้ (ส่งออก `game/art/characters/wolf.glb`):
```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python blender/build_wolf.py
```
บอส B01 จระเข้หม้อไอน้ำ และ B03 กวางป่า (ส่งออก `game/art/characters/croc.glb` / `deer.glb`):
```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python blender/build_croc.py
```
```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python blender/build_deer.py
```

- **โครงสร้างโมเดล Blender 3D สไตล์ SD Steampunk (`vesper_warrior.blend` / `vesper_warrior.glb`)**:
  - ออกแบบสัดส่วนสไตล์ **SD (Super-Deformed ~2.2 หัว)** สำหรับตัวละคร Steampunk Warrior: ศีรษะและดวงตากลมโตอ่านอารมณ์ชัด ลำตัวกะทัดรัดพร้อมกระเป๋าคาดเอว ปลอกแขน/ปลอกขาทรงบาน (Flared Gauntlets & Greaves) ฝาครอบข้อเท้าทรงกลม รองเท้าบูทฐานกว้างมั่นคง และอาวุธ/ถังไอน้ำขนาดใหญ่พิเศษ (Oversized Silhouette)
  - เรนเดอร์ผ่าน `SubViewport` แบบ Orthographic พร้อมวัสดุ `DIFFUSE_TOON` + เส้นขอบหมึกดำ (`next_pass` GPU-skinned outline `grow`) เพื่อให้ได้ลุค 2.5D คมชัดเข้ากับฉาก
  - ใช้โครงกระดูก `Armature` ขั้นสูง (`VesperRoot` 31 bones พร้อม Facial Rig `Eye_R/L`, `Eyelid_R/L`, `Brow_R/L`, Secondary Motion `HairBack`, `Pouch_R/L`, Mechanical `SteamValve`, Toe-Roll `Toe_R/L`, Custom Control Shapes และ Joint Limit Constraints + `TargetDummyRoot` 3 bones)
  - มี Multi-Bone Skinned Joint Sleeves บริเวณเอว คอ ศอก และเข่า (`172` blended vertices) พร้อม Reusable Animation Actions 12 ท่าใน Blender 5.2 (`Idle`, `Walk`, `Run`, `Jump_Land`, `Turn_Look`, `Attack`, `Skill_Stab`, `Skill_Steam`, `Guard`, `Hit`, `Down`, `Enter_Pipe`)
  - มีชิ้นส่วนอุปกรณ์ 3D ครบในไฟล์เดียว เปิด/ปิดตามช่องสวมใส่แบบเรียลไทม์ (`Weapon_0..2`, `Headgear_0..2`, `Suit_0..2`, `Shield_1..2`)
- ปุ่มด้านล่าง: ยืน เดิน เข้าท่อ โจมตี สกิล รับแรง ป้องกัน ล้ม กลับด้าน หยุด/เล่น
- ด้านขวา: อาวุธ 3 แบบ ศีรษะ 3 แบบ ชุด 3 แบบ โล่ 3 แบบ บุคลิก 3 แบบ และท่าสกิล 2 แบบ (แทงทะลวง / พ่นไอแรงดัน)
- การขยับที่ปรับตาม `docs/research/2026-10-28-visual-feel-rea.md`:
  - **ยืน**: น้ำหนักลงเท้า ขยับอกและแขนเล็กน้อย อุปกรณ์ยึดตามข้อต่อ 3D จริง
  - **เดิน**: เดินเคลื่อนที่จริงบนพื้นด้วย `WASD`/ปุ่มลูกศร (หรือกดปุ่มเดินเพื่อเดินไปกลับ) ขางอและก้าวสลับ เท้าที่แตะพื้นไม่ไถล ปลายเท้ากดลงจังหวะยกขา แขนและโล่แกว่งสวนทางกับขา ลำตัวบิดและถ่ายน้ำหนักขึ้นลง เมื่อปล่อยปุ่มกลับท่ายืนทันที
  - **เข้าท่อ**: มีพื้นลาดและลูกศรนำทางหน้าปากท่อ พร้อมวาล์วข้างท่อและแสงภายใน เมื่อเดินเข้าใกล้ปากท่อจะมีคำใบ้ให้กด `Space` (หรือกดปุ่ม `เข้าท่อ`) ตัวละคร 3D จะเดินไปหน้าทางลาด หมุนตัว 3D หันหลังเข้าปากท่อจริง (เห็นถังแรงดันไอน้ำด้านหลัง) ก้าวเข้าไปด้านใน และถูกขอบท่อด้านหน้าบังตามลำดับก่อนเปลี่ยนฉาก
  - **โจมตี**: ก้าวเดินเข้าหาหุ่นซ้อมจริง (`approach`) ก่อนบิดไหล่ง้างยกอาวุธขึ้นเหนือศีรษะ (`windup`) โน้มตัวฟันลงจนสุดแขน (`cleave`) แสดงตัวเลขความเสียหายและแรงสะท้อนที่หุ่น 3D ตรงจังหวะปะทะ แล้วก้าวถอยกลับตำแหน่งยืน (`retreat`) ระหว่างออกท่ามีป้ายแจ้งสถานะรอ (`Please Wait`) โดยแถบปุ่มด้านล่างไม่กระโดด
  - **ใช้สกิล**: เลือกได้ทั้งท่าแทงทะลวงและท่าพ่นไอแรงดัน อาวุธไม่หลุดมือ เอฟเฟกต์เริ่มจากจุดปล่อยที่ปลายอาวุธ
  - **รับการโจมตี / ป้องกัน / ล้ม**: มีแรงถอยและทิศทางชัด ยกโล่ 3D ขึ้นตั้งรับด้านหน้าลำตัวเมื่อป้องกัน ไม่ใช้การกระพริบทั้งตัวแทนท่าทาง

ตรวจด้วย `check.gd`: เปลี่ยนทุกตัวเลือกอุปกรณ์ การเดินเคลื่อนที่จริง การก้าวเข้าโจมตีและถอยกลับ การใช้สกิล การเข้าปากท่อพร้อมลำดับการบังของขอบท่อ และการคืนท่าหลังรับแรง ผ่านบน Godot 4.7.2 / Apple M1.
