# วิเคราะห์ BudgetOverlapYearCentral — โค้ดปัจจุบัน vs. คำอธิบาย (2026-08-21)

> อ่านโค้ดอย่างเดียว **ยังไม่แก้ไข** / ยังไม่ได้ query DB (ไม่ได้ต่อ VPN)
> ไฟล์หลัก: `OAGBudget.API/Services/Repository/BudgetService.cs`, `OAGBudget/Controllers/BudgetController.cs`, `OAGBudget/Views/Budget/BudgetOverlapYearCentralDetail.cshtml`
>
> **rev.6 — ปิดคำถามครบทุกข้อ (Q-A ถึง Q-N) พร้อมลงมือได้** เพิ่มข้อสังเกตเรื่อง WEB_BATCH_NO ที่ไม่ตรงกับ EBS
> *rev.5 ปิด Q-K / Q-L / Q-M, เพิ่มหมวด 5.1 (รองรับ CR ตอนยกเลิก)*
> *rev.4 ปิด Q-H / Q-I, ระบุผลกระทบต่อเนื่องของการบันทึกแถว 0, สรุปการแก้ join ของ view*
> *rev.3 ปิด Q-A ถึง Q-G, ตัดงานที่ไม่ต้องทำออก, เพิ่มหมวด 5 (ตรวจ view เทียบโค้ด)*
> *rev.2 แก้ข้อสรุปหมวด 1/2 จากฉบับแรกตามตารางที่ถูกต้อง*

---

## 0. ผลตรวจสอบข้อสงสัยของคุณโดยตรง

> "เหมือนในโค้ดตอนนี้ผมเขียนให้ OAGWBG_BUDGETRESERVED.ROUNDINTERFACE นำค่ามาจาก OAGWBG_BUDGETRESERVEDITEM.overlapround อยู่ และตอน insert ใส่ -1 ไป"

**ตรวจแล้ว — ทิศทางกลับกัน และไม่พบ -1**

| ข้อสงสัย | สิ่งที่พบจริงในโค้ด |
|---|---|
| RESERVED.ROUNDINTERFACE ← ITEM.OVERLAPROUND | **ไม่ใช่** — `ROUNDINTERFACE` เพิ่มค่าเอง (`+1`) ใน `ConfirmBudgetReserved` (BudgetService.cs:26729, :26761) ไม่มีที่ไหนอ่านจาก `OVERLAPROUND` เลย |
| ทิศทางจริง | **ITEM.OVERLAPROUND ← RESERVED.ROUNDINTERFACE** ที่ `SynchronizeReservedItemsAsync` (BudgetService.cs:29802 `var currentRound = header.Roundinterface ?? 1;` → :29856, :29889, :29905) |
| insert -1 | **ไม่พบ** ในฝั่ง Central — `-1` ที่มีในไฟล์เป็นค่าคงที่ของ `APPS.OAG_GL_FUNDS_AVAILABLE_PKG_BYPASS` (`P_ENCUMBRANCE_TYPE_ID`, `P_REQ_ENCUMBRANCE_ID`, `P_PO_ENCUMBRANCE_ID`) คนละเรื่องกัน |
| ที่อาจทำให้สับสน | ฝั่ง **ส่วนภูมิภาค (region "P")** `Overlapround` **มาจาก payload ของ client** (`BudgetOverlapYearPO.cshtml:744, :1039, :1056` — JS toggle `1 ↔ 2` แล้ว post กลับ) ส่วน Central derive จาก server → คนละ model กันสองหน้า |

**⇒ ถ้าคุณเห็น `-1` จริงใน DB ให้บอกผมว่าเจอที่คอลัมน์ไหน / ใบไหน** — ผมจะได้ตามหาจาก data path นั้น

---

## 1. เรื่อง: ลำดับ ROUNDINTERFACE / OVERLAPROUND / RESERVEDNO / ปีงบ

### ✅ ข้อสรุป: **ตรงตามตารางทุกช่อง — ไม่ต้องแก้ ไม่ต้อง migrate**

| ยืนยันครั้งที่ | RI ก่อนเข้า confirm | RI หลัง | OVERLAPROUND ของ item ที่ save ในรอบนั้น | RESERVEDNO ที่ stamp | ปีงบ item | ส่ง Interface | ตรง spec |
|---|---|---|---|---|---|---|---|
| 0 | — | null | ยังไม่มี | ยังไม่มี | 2568 | — | ✅ |
| 1 กันเงิน | null | 1 | 1 | ยังไม่มี (ยังไม่มี EXPAND_PO ให้ stamp) | 2569 | ✅ | ✅ |
| 2 ขยายครึ่งปีแรก | 1 | 2 | 1 | `Transferno.1` | 2569 | ❌ | ✅ |
| 3 ขยาย 69→70 | 2 | 3 | 2 | `Transferno.2` | 2569 | ❌ | ✅ |
| 4 ขยายครึ่งปีแรก | 3 | 4 | 3 | `Transferno.3` | 2570 | ❌ | ✅ |
| 5 ขยาย 70→71 | 4 | 5 | 4 | `Transferno.4` | 2570 | ❌ | ✅ |
| 6 ขยายครึ่งปีแรก | 5 | 6 | 5 | `Transferno.5` | 2571 | ❌ | ✅ |

**กลไกที่ทำให้ตรง** (ใช้อ้างอิงเวลาแก้โค้ดอื่น — อย่าเผลอแก้):

1. `OVERLAPROUND` ตอน save = `header.Roundinterface ?? 1` = **RI ของรอบที่ยืนยันไปแล้ว** ⇒ item ที่กรอกก่อนยืนยันครั้งที่ N ได้ `Overlapround = N-1` (ยกเว้นครั้งที่ 1 ที่ `?? 1` ทำให้ได้ 1)
2. `RESERVEDNO` stamp ที่ :26679 อยู่ **ก่อน** `+1` ที่ :26729 ⇒ ใช้ค่า RI เดิม = เท่ากับ `Overlapround` พอดี
   ⇒ **กฎที่ได้: `RESERVEDNO = TRANSFERNO || '.' || OVERLAPROUND`**
3. ปีงบ: `advanceYear = (RI ?? 0) % 2 == 0` ประเมิน **ก่อน** `+1` ⇒ ครั้งที่ 1 (null→0, คู่) +1, ครั้งที่ 2 (RI=1, คี่) ไม่+, ครั้งที่ 3 (RI=2, คู่) +1, สลับไป
4. ครั้งที่ 1 ไม่ stamp `RESERVEDNO` เพราะ query :26618 กรอง `Budgetreservedtype == "EXPAND_PO"` ซึ่งยังไม่มี (แท็บขยายเพิ่งโผล่หลัง `Statusid == 20202` — `.cshtml:32`)

### จุดเปราะที่ควรกันไว้
ลำดับบรรทัด :26726 (`UpdateHeader...`) → :26729 (`+1`) เป็น **ความถูกต้องเชิงลำดับที่ไม่มีคอมเมนต์กำกับ** ใครสลับ 2 บรรทัดนี้ ทั้ง RESERVEDNO และปีงบพังทันที
**แนะนำ:** ใส่คอมเมนต์ล็อก + unit test ครอบ trace 6 รอบข้างบน (R2)

---

## 2. เรื่อง: สูตรป้ายกลุ่มบนหน้าจอผิด (พังตั้งแต่รอบ 3)

### ✅ ตัดสินใจแล้ว (Q-A, Q-B)
- **Q-A → `RESERVEDNO_ADD` เขียนตอน "ยืนยัน" เท่านั้น** ⇒ **ไม่ต้อง**ปลดคอมเมนต์ :29859 คงพฤติกรรมเดิม
- **Q-B → `CANCEL_PO` ไม่ต้องมี `RESERVEDNO_ADD`** ⇒ :26618 ที่ comment `CANCEL_PO` ออกไว้ **ถูกต้องแล้ว** ไม่ต้องแตะ

### ข้อที่ต่าง (ยังต้องแก้)
เพราะ `RESERVEDNO` เขียนตอนยืนยันเท่านั้น กลุ่มของ **รอบปัจจุบันที่ยังไม่ยืนยัน** จึงมี `Reservedno = NULL` เสมอ → ป้ายกลุ่ม fallback ไปสูตรคำนวณ และ **สูตรทั้งสองแบบผิด** เทียบกับกฎ `TRANSFERNO.OVERLAPROUND`:

| ตำแหน่ง | สูตร | rnd=1 | 2 | 3 | 4 | ควรได้ |
|---|---|---|---|---|---|---|
| :28178, :28417 | `$"{Transferno}.{rnd / 2}"` | **.0** ❌ | .1 ❌ | .1 ❌ | .2 ❌ | .1/.2/.3/.4 |
| :28199, :28219, :28438 | `$"{Transferno}.{(currentRound+2)/2}"` | .1 ✅ | .2 ✅ | **.2** ❌ | **.3** ❌ | .1/.2/.3/.4 |

⇒ สูตรที่สองบังเอิญถูกแค่รอบ 1-2 (รอบที่ทดสอบบ่อยที่สุด) **พังตั้งแต่รอบ 3**

### แนวทางปรับปรุง
1. แทนสูตรทั้ง 5 จุดด้วย helper เดียว `BuildReservedNo(transferno, round) => $"{transferno}.{round}"`
2. เนื่องจากเป็นเลข "คาดการณ์" (ยังไม่เขียน DB) แนะนำต่อท้ายป้ายว่า `(รอยืนยัน)` เพื่อไม่ให้ผู้ใช้เข้าใจว่าออกเลขแล้ว
3. **หมายเหตุ:** ป้ายกลุ่มใช้ `firstExpand?.Reservedno` ของ item ตัวแรกในกลุ่ม — แต่ item ในกลุ่มเดียวกัน **อาจมีเลขต่างกัน** ได้ เพราะ PO ที่ `Booknumber` เคยมีเลขแล้วจะ reuse เลขเดิม (:26658-26687 ตาม spec 2.1) ⇒ ถ้าต้องการความถูกต้อง 100% ควรแสดงเลขที่ระดับแถว ไม่ใช่ระดับกลุ่ม
- **R2** — เปลี่ยนเฉพาะค่าที่แสดง ไม่แตะแถวที่ stamp ไปแล้ว

---

## 3. เรื่อง: กติกาช่วงเวลายืนยัน — สูตรใน API กลับด้าน (View ถูก)

### กติกาที่ถูกต้อง (จากคำตอบข้อ 3)

| กด | ช่วงเวลา | `GetReservePeriod` (:26520) | RI ที่ guard เห็น (ก่อน +1) |
|---|---|---|---|
| ยืนยันกันเงิน | ครึ่งปีหลัง (เม.ย.–ก.ย.) | `RESERVE` | **null** |
| ยืนยันขยายรอบแรก | ครึ่งปีแรก (ต.ค.–มี.ค.) | `EXPAND` | **คี่** (1, 3, 5) |
| ยืนยันขยายรอบสอง | ครึ่งปีหลัง (เม.ย.–ก.ย.) | `RESERVE` | **คู่** (2, 4, 6) |

> ที่คุณบอกว่า "ขยายรอบแรก = คู่ / รอบสอง = คี่" คือเลข RI **หลัง** confirm (ตามคอลัมน์ในตาราง) ส่วน guard ทำงานตอนต้น method จึงเห็นค่า **ก่อน** +1 → กลับกันพอดี **ระวังจุดนี้ตอนเขียนโค้ด**

**⇒ สูตรที่ถูก: `expectReserve = (RI == null) || (RI % 2 == 0)`**

| ชั้น | ตำแหน่ง | สูตร | ผล |
|---|---|---|---|
| API Confirm | `BudgetService.cs:26571` | `RI == null \|\| (RI % 2) != 0` | ❌ **กลับด้าน** |
| View | `BudgetOverlapYearCentralDetail.cshtml:40` | `RI == null \|\| (RI % 2) == 0` | ✅ **ถูกแล้ว** |

### ✅ ตัดสินใจแล้ว (Q-C): **ยังไม่เปิด guard จนกว่าทดสอบ flow ผ่าน**

### แนวทางปรับปรุง (ทำตอนนี้ได้ ไม่กระทบใคร)
1. **แก้สูตรที่ :26571 เป็น `== 0` เลยตอนนี้** — ปลอดภัย 100% เพราะตัวแปรยังไม่ถูกใช้ ทำไว้ก่อนกันลืมตอนเปิดจริง
2. ย้ายสูตรไป `OAGBudget.Global` เป็น helper `IsReservePeriodExpected(int? roundInterface)` ใช้ร่วม View/API
3. **ผูก guard เข้ากับ `FeatureFlags:BypassPeriodGuard`** (โครงมีอยู่แล้ว :26580) ตั้ง default = bypass ⇒ วันเปิดใช้จริงเป็นการแก้ **config** ไม่ใช่แก้โค้ด + ไม่ต้อง deploy
4. เลิก hardcode `canConfirmPeriod = true` ที่ `.cshtml:42` เปลี่ยนเป็นอ่านค่าจาก flag เดียวกัน
- **R2** (ตราบใดที่ flag ยัง bypass) → กลายเป็น **R1** ตอนสลับ flag เป็นเปิด

---

## 4. เรื่อง: เงินก้อนใหญ่ — กติกาที่ตอบมา **ขัดกับโค้ดปัจจุบัน 2 จุด**

### ✅ กติกาที่ต้องการ (Q-D)
> "ปิด แต่ก่อนหน้านี้อยากให้กรอก ไม่มีคือ 0 มีก็กรอกดักไว้"

⇒ RI ≥ 3 → **ปิดถาวร** / RI = 1, 2 → **ต้องกรอกให้ครบ ถ้าไม่มีให้ใส่ 0** และมี validation ดักเพดาน

### ข้อที่ต่าง

| # | ตำแหน่ง | ปัญหา | ระดับ |
|---|---|---|---|
| 4.1 | `.cshtml:654-672` `validateLumpSumRequired` | บังคับว่า RI=1 ต้องมีแถวที่ยอด **> 0 อย่างน้อย 1 แถว** (RI=2 เช่นกัน) ⇒ **ใบที่ไม่มีเงินก้อนใหญ่จริง (กรอก 0 ทุกช่อง) จะกดยืนยันไม่ได้เลย ค้างถาวร** ขัดกับ "ไม่มีคือ 0" โดยตรง | 🔴 |
| 4.2 | `BudgetService.cs:29877, :29879` | `.Where(i => i.Amount > 0)` ⇒ **แถวที่กรอก 0 ไม่ถูกบันทึกลง DB** | 🟠 |
| 4.3 | `BudgetService.cs:29876-29912` | **API ไม่มี guard รอบเลย** — รับ `ListExpandLump` / `ListCancelLump` ทุกรอบ ไม่เช็ค `Roundinterface` ⇒ ยิง API ตรง (Postman / แก้ JS) บันทึกรอบ 3, 4, 5 ได้ ทั้งที่ View ปิดไว้แล้ว (`.cshtml:53-54, :597`) | 🟠 |

### ✅ ตัดสินใจแล้ว (Q-H): **บันทึกแถว 0 ลง DB ด้วย**
> "บันทึกดีกว่าเพราะมีออกรายงาน จะได้ไม่ต้องเขียนเงื่อนไขเพิ่ม"

⇒ แก้ `.Where(i => i.Amount > 0)` ที่ :29877 และ :29879 เป็น `>= 0`

### ⚠️ ผลกระทบต่อเนื่องที่ต้องแก้พร้อมกัน (ไม่งั้นพัง)

| # | ตำแหน่ง | ผลกระทบเมื่อเริ่มบันทึกแถว 0 | ต้องทำ |
|---|---|---|---|
| 4.4 | `BudgetService.cs:29510-29515` | `hasAnyItems` ยังใช้ `ListExpandLump?.Any(i => i.Amount > 0)` ⇒ ใบที่กรอก **0 ล้วน** จะไม่เปลี่ยนสถานะเป็น 90102 แต่ **จะมี item row ที่ `Statusid = 90102/90109` อยู่ใต้ header ที่ยังเป็น 90101 (ร่าง)** — สถานะ header กับ item ไม่ตรงกัน | ✅ **Q-K ตอบแล้ว: ควรเป็น 90102** ⇒ แก้เป็น `>= 0` ทั้ง 2 บรรทัด |
| 4.5 | `GetBudgetOverlapConsiderList:30560-30566` | region C คำนวณ `maxOverlapround = reservedItems.Max(Overlapround)` แล้ว `Totalbalanceamount = Sum(Usageamount)` ของรอบนั้น ⇒ ถ้ารอบล่าสุดมีแต่แถว 0 คอลัมน์ **"เงินกันเหลื่อมปี" จะแสดง 0** ทั้งที่รอบก่อนมียอด | กรอง `Usageamount > 0` ตอน sum หรือหา max round ที่มียอดจริง |
| 4.6 | `GetBudgetOverlapConsiderList:30573` (= bug 6.5) | `lastRound.HasValue` ⇒ ใบที่มีแต่แถว 0 ก็จะขึ้น **"ขยายระยะเวลา"** ⇒ Q-H ทำให้ bug 6.5 **รุนแรงขึ้น** | แก้ 6.5 ให้ใช้ `RI > 1` (อยู่ในลิสต์อยู่แล้ว) |

### ✅ จุดที่ตรวจแล้ว **ไม่กระทบ**
- `GetBudgetReservedList:28827-28836` — `maxOverlapRound` คำนวณจาก `EXPAND_PR`/`EXPAND_PO` เท่านั้น ส่วน `ExpandAmount` sum `Usageamount` ⇒ แถว 0 ไม่เปลี่ยนผลรวม ✅
- `SavedExpandLumpAmounts` / `SavedCancelLumpAmounts` prefill (:27494-27506) ⇒ จะแสดง `0` แทนช่องว่าง **ดีขึ้น** ตรงกับ "ไม่มีคือ 0" ✅

### แนวทางปรับปรุงรวมของหมวด 4
1. **4.1** — เปลี่ยน `validateLumpSumRequired` (`.cshtml:654`) จาก "ต้องมีแถว > 0 อย่างน้อย 1" เป็น **"ทุกแถวที่แก้ไขได้ต้องมีค่า (0 ได้)"** — คือเช็คว่าไม่มีช่องว่าง ไม่ใช่เช็คผลรวม **(บังคับ ไม่งั้นใบ 0 ล้วนกดยืนยันไม่ได้)**
2. **4.2** — `.Where(Amount > 0)` → `>= 0` ที่ :29877, :29879
3. **4.3** — guard ฝั่ง API: `EXPAND_LUMP` รับเฉพาะ `RI == 1`, `CANCEL_LUMP` รับเฉพาะ `RI == 2`
4. **4.4** — `hasAnyItems` (:29513, :29514) เปลี่ยน `Amount > 0` → `>= 0` ให้ใบ 0 ล้วนเป็น 90102 **(Q-K)**
5. **4.5** — กรอง `Usageamount > 0` ตอน sum ที่ :30563
6. **4.6** — แก้พร้อม bug 6.5
- **R2** ทั้งหมด (4.2 เขียนข้อมูลเพิ่ม แต่เป็นแถวยอด 0 ไม่กระทบยอดใด)

### ✅ ปิดคำถามหมวดนี้ครบแล้ว (Q-K): **ใบที่กรอก 0 ล้วน → 90102**

---

## 5. เรื่อง: view `..._CENTRAL_DETAIL_INTERFACE` — ไม่ต้องทำ UI แต่ **ตัว view เองมี 5 จุดที่ไม่ตรงกับสิ่งที่โค้ดเขียนจริง**

### ✅ ตัดสินใจแล้ว (Q-E, Q-F)
- **Q-E → ไม่ต้องแสดงใน UI** คุณตรวจใน DB เอง เพราะระบบอื่นเอาไปใช้ต่อ ⇒ **ตัดงาน scaffold entity / wire หน้า Consider ออกทั้งหมด**
- **Q-F → แสดงทั้งใบ ไม่แยกรอบ** ⇒ `WHERE BRS.ROUNDINTERFACE IS NOT NULL` โดยไม่กรองรายรอบ **ถูกต้องแล้ว** ✅

### ⚠️ แต่เพราะระบบอื่นใช้ต่อ — ผมตรวจ DDL เทียบกับสิ่งที่โค้ดเขียนจริงให้ เจอ 5 จุด

> DDL: `_brain_OAGBUDGET/20260421_CREATE_VIEW_.../OAGWBG_V_BUDGET_OVERLAPYEAR_CENTRAL_DETAIL_INTERFACE.sql`

| # | จุด | ปัญหา | ระดับ |
|---|---|---|---|
| **V1** | `LEFT JOIN OAGWBG_RECEIVE_BATCH_NO RBN ... AND RBN.INTERFACETYPE = 'O'` | โค้ดเขียน `Interfacetype = "C"` สำหรับ region C (`BudgetService.cs:26829`) และ `"P"` สำหรับ region P (:26868) — **ไม่มีที่ไหนเขียน `'O'` ในโฟลว์นี้เลย** (`'O'` ถูกใช้ในฟีเจอร์ RECEIPT_RCV คนละเรื่อง :3258, :3313) ⇒ join **ไม่เคยติด** | 🔴 |
| **V2** | `AND (BATCHNAME LIKE 'ENC%' OR BATCHNAME LIKE 'BG%')` | `ConfirmBudgetReserved` region C เขียน `Batchname = $"CARRY_FORWARD_{year}_{ts}"` (:26834) — **ไม่มี prefix ENC/BG** ⇒ ต่อให้แก้ V1 แล้ว LIKE ก็ยังไม่ติด | 🔴 |
| **V3** | ผลลัพธ์ของ V1+V2 | `RBN.BATCHNAME` เป็น NULL เสมอ → `WEB_BATCH_NO` / `REFERENCE1` ตกไปใช้สูตร fallback `... \|\| TO_CHAR(NVL(B.TRANSFERDATE, SYSDATE),'YYMMDDHH24MISS')` ซึ่ง **ไม่ตรงกับ batch name ที่ส่งเข้า EBS จริง** (`SaveBudgetReserved:14003-14005` ใช้ `ENC_CARRY_FORWARD_{year}_{ts1}` / `BG_CARRY_FORWARD_{year}_{ts2}` โดย ts จาก `now` ตอน confirm) และถ้า `TRANSFERDATE` เป็น NULL จะ **เปลี่ยนค่าทุกครั้งที่ query** (SYSDATE) ⇒ **ระบบปลายทางกระทบ reconcile ตาม WEB_BATCH_NO ไม่ได้** | 🔴 |
| **V4** | `LEFT JOIN OAGWBG_BUDGETRESERVED_BANKACCOUNT BRB ON BRB.RESERVEDID = BRS.ID` | `SynchronizeCentralBankAccountsAsync` เขียน **1 แถวต่อ 1 EXPENSETYPEID** (:27057-27075 group by `ExpenseTypeId`) ⇒ ใบที่มี 3 ประเภทค่าใช้จ่าย จะทำให้ **ทุกแถว category คูณ 3** แต่ละแถวได้ GIVER/RECEIVER คนละอัน<br>**ควรเป็น:** `AND BRB.EXPENSETYPEID = CC.EXPENSE_TYPE_ID` (view มี `CC` = `OAGWBG_V_EXT_OAGINV_CATEGORY_CODES_V` อยู่แล้ว และมีคอลัมน์ `EXPENSE_TYPE_ID` — โค้ดใช้ที่ :27050-27060) | 🔴 |
| **V5** | `LEFT JOIN ..._EXPENSE_ACCOUNT_RULE_V EAR ON BRSC.CATEGORYID = EAR.CATEGORYID` | โค้ด C# query view นี้ด้วย **4 เงื่อนไข** (`Budgetyear + Categoryid + ProductId + ActivitycodeId`) แล้วค่อย fallback เป็น categoryid อย่างเดียว (:27510-27520) ⇒ แปลว่า **1 categoryid มีได้หลายแถว** → join ด้วย categoryid อย่างเดียวก็คูณแถวอีกชั้น และ `SEGMENT8/10/11` อาจได้ค่าผิด | 🟠 |

### จุดที่ตรวจแล้ว **ถูกต้อง** ✅
- `WHERE ROUNDINTERFACE IS NOT NULL` → แสดงทั้งรอบกันเงินและรอบขยาย ตรง spec ข้อ 5 + ข้อ 3 และตรง Q-F
- `RBN.ROUNDNO = B.TRANSFERNO` → โค้ดเขียน `Roundno = Convert.ToInt32(budget.Transferno)` (:26830) ตรงกัน
- `DEFAULT_EFFECTIVE_DATE` = `(BRS_BUDGETYEAR - 543) || '-SEP-30'` / `'-OCT-01'` → BE 2569 ได้ 2026-09-30 / 2026-10-01 ตรงกับที่โค้ดใช้

### ✅ ตัดสินใจแล้ว (Q-I): **ไม่เปลี่ยน prefix ของ batch name ในโค้ด C# — แก้ที่ view แทน**
> "ไม่เปลี่ยน Prefix แก้ join แทน — ใช้ 'C' / เอา join batchname ออก"

**DDL ที่ต้องแก้:**
```sql
-- เดิม
LEFT JOIN OAGWBG_RECEIVE_BATCH_NO RBN
  ON RBN.ROUNDNO = B.TRANSFERNO
 AND RBN.INTERFACETYPE = 'O'
 AND (
      (T.DOC_TYPE = 'ENC' AND RBN.BATCHNAME LIKE 'ENC%')
   OR (T.DOC_TYPE = 'BG'  AND RBN.BATCHNAME LIKE 'BG%')
 )

-- ใหม่
LEFT JOIN OAGWBG_RECEIVE_BATCH_NO RBN
  ON RBN.ROUNDNO = B.TRANSFERNO
 AND RBN.INTERFACETYPE = 'C'
```

**เหตุผลที่ต้องเป็น `'C'` ไม่ใช่ `'O'`/`'OR'`:**
- `'O'` / `'OR'` เขียนลง **`OAGWBG_OUTSIDE_BATCH_NO`** (ฟีเจอร์เงินนอกงบประมาณ — `BudgetService.cs:3258`, `:3528`) **คนละตารางกับที่ view join**
- ค่าที่เขียนลง **`OAGWBG_RECEIVE_BATCH_NO`** จริงในโฟลว์นี้: region C → `'C'` (:26829) / region P → `'P'` (:26868)
- ตัวกลับรายการของโฟลว์กันเงินคือ **`'RR'`** (`ReverseConfirmBudgetReserveTransfer` :25701) — **ไม่มีค่า `'CR'` ที่ไหนในโค้ดเลย**

### 🔴 คำเตือนสำคัญ: การเอา `BATCHNAME LIKE` ออกจะทำให้ **row คูณ**

`ConfirmBudgetReserved` region C เขียน RBN **1 แถวต่อ 1 `RECEIVEID`** (`:26847-26862` — `foreach (var id in receiveIds)`) ทุกแถวมี `BATCHNAME` เดียวกัน ต่างกันแค่ `RUNNING`
⇒ ใบที่มี 5 receive จะทำให้ทุกแถวของ view **คูณ 5**

**ต้องกัน row คูณ:**
```sql
LEFT JOIN (
  SELECT ROUNDNO, MIN(BATCHNAME) AS BATCHNAME
    FROM OAGWBG_RECEIVE_BATCH_NO
   WHERE INTERFACETYPE = 'C'
   GROUP BY ROUNDNO
) RBN ON RBN.ROUNDNO = B.TRANSFERNO
```

### ✅ Q-L: **แยก batch แต่ละรอบ "ไม่ได้" และ "ไม่จำเป็น"**
> "แยก Batch แต่ละรอบได้ไหม"

**ตอบ: ตอนนี้ทำไม่ได้ และไม่มีอะไรให้แยก — เพราะ region C มี batch เดียวต่อ 1 ใบอยู่แล้ว**

เหตุผล 2 ข้อ:

1. **โค้ดเขียน RBN แค่ครั้งเดียว ตอนยืนยันครั้งที่ 1 เท่านั้น**
   บล็อกที่สร้าง RBN (`:26847-26862`) อยู่ **หลัง** early return ของ `if (!wasNull)` ที่ `:26723-26745` ⇒ **เข้าถึงได้เฉพาะตอน `wasNull` (ยืนยันครั้งแรก)** เท่านั้น
   รอบขยาย (ครั้งที่ 2 ขึ้นไป) return ก่อน ไม่เคยแตะ RBN — **ซึ่งถูกต้องตาม spec** ("รอบขยายไม่ส่ง Interface")
   ⇒ 1 ใบ = 1 `BATCHNAME` (ซ้ำ N แถวตามจำนวน `RECEIVEID` ต่างกันแค่ `RUNNING`)

2. **ตาราง `OAGWBG_RECEIVE_BATCH_NO` ไม่มีคอลัมน์บอกรอบเลย**
   คอลัมน์ที่มี: `ID`, `RECEIVEID`, `INTERFACETYPE`, `CREATEON`, `BATCHNAME`, `ROUNDNO`, `RUNNING`
   > ⚠️ `ROUNDNO` **ไม่ใช่รอบขยาย** — โค้ดเก็บ `Convert.ToInt32(budget.Transferno)` ลงไป (`:26830`) คือ **เลขที่เงินกัน** ชื่อคอลัมน์ชวนเข้าใจผิด

⇒ `MIN` / `MAX` / `ROW_NUMBER` ให้ผลเหมือนกันหมด ใช้ `MIN(BATCHNAME)` ตามตัวอย่างข้างบนได้เลย

**ถ้าอนาคตอยากแยกจริง** ต้องทำ 2 อย่าง: (ก) เพิ่มคอลัมน์ `ROUNDINTERFACE` ใน `OAGWBG_RECEIVE_BATCH_NO` (ข) แก้ `ConfirmBudgetReserved` ให้เขียน RBN ทุกรอบ ไม่ใช่เฉพาะรอบแรก — เป็นงาน schema + code ไม่ใช่แก้ view อย่างเดียว

### ⚠️ จุดที่ควรตรวจเพิ่มตอนคุณเข้า DB
- **`SEGMENT3 = MOD(B.BUDGETYEAR,100)`** ใช้ปีจาก `BUDGETRESERVED_CATEGORY` แต่ `DEFAULT_EFFECTIVE_DATE` ใช้ `BRS_BUDGETYEAR` จาก header — **สองค่านี้แยกจากกันหลังยืนยันรอบแรก** (header +1 แต่ category คงปีเดิม) ต้องยืนยันว่าตั้งใจ
- `SaveBudgetReserved:13999-14000` **hardcode `new DateTime(2026, 9, 30)` / `(2026, 10, 1)`** — ไม่เลื่อนตามปีงบ จะผิดในปีถัดไป (view คำนวณจากปีให้ถูกอยู่แล้ว ⇒ **โค้ดต่างจาก view**) 🟠

### 📌 Q-J — อธิบายใหม่ให้ชัด

**คำถามคืออะไร:** ใน GL journal 1 บรรทัดต้องระบุว่าเป็นฝั่ง **เดบิต (DR)** หรือ **เครดิต (CR)** — view มีคอลัมน์ให้ทั้ง 4 ช่อง: `ENTERED_DR`, `ACCOUNTED_DR`, `ENTERED_CR`, `ACCOUNTED_CR`

**สิ่งที่ view ทำอยู่ตอนนี้** (บรรทัด 117-120 ของ DDL) — ใส่ยอดที่ฝั่ง DR อย่างเดียว ทั้ง ENC และ BG:
```sql
B.TOTALRESERVEDAMOUNT AS ENTERED_DR,
B.TOTALRESERVEDAMOUNT AS ACCOUNTED_DR,
NULL AS ENTERED_CR,
NULL AS ACCOUNTED_CR,
```

**ที่ทำให้สงสัย:** ตอนต้น view ประกาศ `TYPE_MAP` ไว้แบบนี้
```sql
SELECT 'ENC' AS DOC_TYPE, 'E' AS ACTUAL_FLAG, 'C' AS DRCR_FLAG FROM DUAL
UNION ALL
SELECT 'BG',              'B',               'D'              FROM DUAL
```
⇒ `DRCR_FLAG` บอกว่า **ENC = ฝั่ง Credit, BG = ฝั่ง Debit** แต่ **คอลัมน์ `DRCR_FLAG` ไม่ถูกใช้ใน SELECT เลยแม้แต่ที่เดียว** — เหมือนตั้งใจไว้แล้วไม่ได้เขียนต่อ

**หมายเหตุ:** view ฝั่งภูมิภาค `OAGWBG_V_BUDGET_OVERLAPYEAR_DETAIL_INTERFACE` (บรรทัด 97-100) ใช้ pattern เดียวกันเป๊ะ — DR อย่างเดียว, CR เป็น NULL ⇒ ทั้งสอง view สอดคล้องกันสำหรับ **กรณีปกติ**

---

## 5.1 เรื่อง: รองรับ CR ตอนยกเลิก (Q-M)

### ✅ ตัดสินใจแล้ว (Q-M)
> "CR เผื่อไว้ตอนยกเลิก"

⇒ ต้องการให้ view **มีแถวฝั่ง CR สำหรับกรณียกเลิก/กลับรายการ** ด้วย ไม่ใช่แค่ DR

### สถานะปัจจุบัน: โฟลว์ยกเลิก **มีอยู่แล้วในโค้ด C# แต่ view ไม่มีเลย**

`SaveBudgetReserved` region C มี **Step 3/4 (กลับรายการ)** ที่เขียนลง `OAGWBG_LOG_INTERFACE` ตรงๆ (`BudgetService.cs:14089-14230`):

| | Step 3 — Reverse Old Encumbrance | Step 4 — Create New Budget |
|---|---|---|
| Batch name | `REVERSE_ENC_CARRY_FORWARD_{ปีงบ}_{ts}` (:14096) | `REVERSE_ENC_CARRY_FORWARD_{ปีงบ}_{ts+3s}` (:14098) |
| Journal | `กลับรายการบัญชี_เงินกันเหลื่อมปี {ปีงบ} - {dept}` | เหมือนกัน |
| `ACTUAL_FLAG` | `'E'` | `'B'` |
| `BUDGET_ENCUMBRANCE_NAME` | `''` | `'OAG_BG_FINAL'` |
| **`SEGMENT4`** | **`'100'`** (ปีปัจจุบัน) | **`'400'`** (ปีถัดไป) |
| **ฝั่งยอด** | **`ENTERED_CR` / `ACCOUNTED_CR`** ✅ | `ENTERED_DR` / `ACCOUNTED_DR` |
| แหล่งข้อมูล | `itemsToReverse` (:14087) | เหมือนกัน |
| เงื่อนไข | `item.Statusid == 90109 \|\| == 90110` (:14004-14007) และ `Totalbalanceamount > 0` | เหมือนกัน |
| ยอด | `item.Totalbalanceamount` | เหมือนกัน |

⇒ **นี่คือ blueprint ที่ต้องเอาไปเขียนใน view** — ค่าทุกช่องมีครบแล้ว ไม่ต้องเดา

### 🔴 อุปสรรคหลัก: **grain ไม่ตรงกัน**

| | แหล่งข้อมูล | ระดับข้อมูล |
|---|---|---|
| view ปัจจุบัน (`BASE`) | `OAGWBG_BUDGETRESERVED_CATEGORY` | 1 แถวต่อ **หมวดงบประมาณ** |
| โฟลว์ยกเลิก (`itemsToReverse`) | `OAGWBG_BUDGETRESERVEDITEM` | 1 แถวต่อ **PO/PR ที่ถูกยกเลิก** |

⇒ **เพิ่ม CR เข้า view ไม่ใช่การแก้ `CASE WHEN` ธรรมดา** ต้องเพิ่ม **branch ที่สองทั้งก้อน** ที่ `UNION ALL` มาจาก `BUDGETRESERVEDITEM` และ split `ACCOUNTCODE` (13 segment) เอง — โค้ด C# ทำแบบนี้ที่ :14108-14112 (`rawCode.Split('.')` แล้วเช็ค `parts.Length != 13`)

### โครงที่แนะนำ
```sql
-- BASE เดิม (DR / กันเงินปกติ) คงไว้ทั้งหมด
-- แล้ว UNION ALL ด้วย branch ใหม่:
, REVERSE_BASE AS (
  SELECT BRI.*, BRS.TRANSFERNO, BRS.BUDGETYEAR AS BRS_BUDGETYEAR,
         BRS.DEPARTMENTID, BRS.TRANSFERDATE
    FROM OAGWBG_BUDGETRESERVEDITEM BRI
    JOIN OAGWBG_BUDGETRESERVED BRS ON BRI.BUDGETREVERSEDID = BRS.ID
   WHERE BRS.ROUNDINTERFACE IS NOT NULL
     AND BRI.STATUSID IN (90109, 90110)          -- ตรงกับ :14004-14007
     AND NVL(BRI.TOTALBALANCEAMOUNT,0) > 0       -- ตรงกับ :14114
     AND REGEXP_COUNT(BRI.ACCOUNTCODE,'\.') = 12 -- 13 segment
)
-- ENC (CR): SEGMENT4='100', ENTERED_CR = TOTALBALANCEAMOUNT, ACTUAL_FLAG='E'
-- BG  (DR): SEGMENT4='400', ENTERED_DR = TOTALBALANCEAMOUNT, ACTUAL_FLAG='B'
--           SEGMENT1..13 มาจาก REGEXP_SUBSTR(ACCOUNTCODE,'[^.]+',1,n)
```

### ✅ ตัดสินใจแล้ว (Q-N): **ระบบปลายทางแยกด้วย `WEB_BATCH_NO` ที่ขึ้นต้น `REVERSE_`**

⇒ **ไม่ต้อง**เพิ่มค่าใหม่ใน `TRANSFERTYPE` — คงเป็น `'CARRYFWD'` ทั้งสอง branch
⇒ branch ยกเลิกต้องตั้ง `WEB_BATCH_NO` ให้ขึ้นต้น `REVERSE_` **เสมอ** และ branch ปกติต้อง **ไม่มี** prefix นี้เด็ดขาด

**ชื่อ batch ที่ branch ยกเลิกควรใช้** (ตามที่โค้ดใช้อยู่ `:14096`, `:14098`):
```sql
CASE WHEN T.DOC_TYPE = 'ENC'
     THEN 'REVERSE_ENC_CARRY_FORWARD_' || R.BRS_BUDGETYEAR || '_' ||
          TO_CHAR(NVL(R.TRANSFERDATE, SYSDATE),'YYMMDDHH24MISS')
     ELSE 'REVERSE_BG_CARRY_FORWARD_'  || R.BRS_BUDGETYEAR || '_' ||
          TO_CHAR(NVL(R.TRANSFERDATE, SYSDATE),'YYMMDDHH24MISS')
END AS WEB_BATCH_NO
```

> 🟡 **หมายเหตุ:** โค้ด C# ตั้งชื่อ batch ฝั่ง BG ของรอบยกเลิกเป็น **`REVERSE_ENC_`** เหมือนกันทั้งคู่ (`:14096` และ `:14098` เป็นสตริงเดียวกัน ต่างแค่ timestamp) ทั้งที่ Step 4 เป็นฝั่ง BG (`ActualFlag = "B"`, `BudgetEncumbranceName = "OAG_BG_FINAL"`) — **น่าจะ copy-paste** ไม่กระทบการแยกด้วย `REVERSE_` (ยังแยกได้) และแยก ENC/BG ได้จาก `ACTUAL_FLAG` อยู่แล้ว แต่ถ้าจะให้สะอาดควรแก้ `:14098` เป็น `REVERSE_BG_CARRY_FORWARD_`

**R1** — เพิ่มแถวใหม่เข้า view ที่ระบบอื่นใช้อยู่ ⇒ ต้องแจ้งเจ้าของระบบปลายทางก่อน deploy ไม่งั้นเขาจะได้แถวเพิ่มโดยไม่ตั้งตัว

---

## 5.2 ⚠️ ข้อสังเกตที่เกิดจากการตัดสินใจ Q-I — `WEB_BATCH_NO` จะไม่ตรงกับที่ส่ง EBS

เมื่อแก้ join เป็น `INTERFACETYPE = 'C'` แล้ว join จะติดจริง แต่ค่าที่ได้ยัง**ไม่ตรงกับ batch ที่ส่งเข้า EBS**:

| แหล่ง | ค่า | timestamp |
|---|---|---|
| ส่ง EBS จริง — ENC | `ENC_CARRY_FORWARD_{ปีงบ}_{ts1}` (`:14004`) | `ts1` (คำนวณใน `SaveBudgetReserved`) |
| ส่ง EBS จริง — BG | `BG_CARRY_FORWARD_{ปีงบ}_{ts2}` (`:14006`) | `ts2 = now + 3 วินาที` |
| เก็บใน `RECEIVE_BATCH_NO` | `CARRY_FORWARD_{ปีงบ}_{ts}` (`:26834`) | `ts` (คำนวณใน `ConfirmBudgetReserved` — **คนละตัวกับ ts1/ts2**) |

**ผลที่ตามมา 2 ข้อ:**
1. ชื่อที่ RBN เก็บ **ไม่มี prefix `ENC_`/`BG_`** ⇒ หลังแก้ join แถว ENC และ BG จะได้ `WEB_BATCH_NO` **ค่าเดียวกัน** (เดิม fallback ให้คนละค่า) — ถ้าระบบปลายทาง group เป็น journal batch ตาม `WEB_BATCH_NO` จะรวมแถว `ACTUAL_FLAG='E'` กับ `'B'` เข้า batch เดียวกัน ซึ่งปกติ EBS ไม่ให้ปน
2. timestamp คนละตัว ⇒ **ไม่มีทางที่ค่าใน view จะเท่ากับ batch ที่ EBS ได้รับจริง** ไม่ว่าจะ join หรือใช้ fallback

**ทางเลือก** (เลือกได้ภายหลัง ไม่บล็อกงานอื่น):
- **(ก) ใส่ prefix ใน view** — `CASE WHEN T.DOC_TYPE='ENC' THEN 'ENC_' ELSE 'BG_' END || RBN.BATCHNAME` แก้ปัญหาข้อ 1 แต่ข้อ 2 ยังอยู่
- **(ข) ไม่ join RBN เลย** ใช้สูตร fallback อย่างเดียว (เหมือน view ฝั่งภูมิภาค) — ได้ prefix ถูก แต่ timestamp ยังไม่ตรง
- **(ค) join `OAGWBG_LOG_INTERFACE`** ซึ่งเก็บ `WEB_BATCH_NO` ตัวจริงที่ส่ง EBS — **ตรง 100%** แต่ต้อง join ผ่าน `REFERENCE4`/`REFERENCE5` (มี `TRANSFERNO` อยู่ในข้อความ) ยุ่งกว่า
- **ผมแนะนำ (ก)** ถ้าเป้าหมายคือให้ระบบปลายทางแยก ENC/BG ได้ถูก / เลือก **(ค)** ถ้าต้องการ reconcile กับ EBS จริงๆ

---

## 6. เรื่อง: Bug ที่เจอระหว่างทาง — **ของจริงที่ควรแก้ก่อน**

| # | ตำแหน่ง | อาการ | ระดับ |
|---|---|---|---|
| 6.1 | `BudgetService.cs:28067` | `cancelPOFromSaved.Max(x => x.Overlapround == header.Roundinterface)` — **วงเล็บผิดที่** กลายเป็น `Max<bool>` = "มีสักตัวไหม" แทนที่จะเป็น `.Max(x => x.Overlapround) == header.Roundinterface` (อีก 3 จุด :27931, :27977, :28105 เขียนถูก) ⇒ แท็บ **ส่งคืนมีหนี้ ไม่ append รายการใหม่** | 🔴 |
| 6.2 | `BudgetService.cs:29830-29841` | `filteredExpandTuples` คำนวณแล้ว **ไม่ถูกใช้** — :29840 ใช้ `expandTuples` ดิบ ⇒ PO ที่ติ๊กทั้งแท็บ "ขยาย" และ "ส่งคืน" ถูก insert **2 แถว** การกันซ้ำที่ตั้งใจไว้ไม่ทำงาน | 🔴 |
| 6.3 | `BudgetService.cs:26695-26698` | **`!isConnection` ไม่ +1 `Roundinterface` เลย** — return ทันทีหลัง `UpdateHeaderAndItemsStatusAsync` ⇒ ถ้า `EBSConnection=false` ใบค้าง RI=null ตลอด แท็บขยายไม่โผล่ **ทดสอบ flow ไม่ได้** (ซึ่ง Q-C บอกว่าต้องทดสอบ flow ให้ผ่านก่อน) และ view หมวด 5 ก็จะว่างเปล่า เพราะกรอง `ROUNDINTERFACE IS NOT NULL` | 🔴 |
| 6.4 | `BudgetService.cs:26640-26690` vs :26630 | region "C" **ไม่เคย set `Approve = 1`** (มีแต่ region "P") ⇒ เงื่อนไข `x.Approve == null` ที่ :29810 ไร้ผลกับ Central — กันประวัติได้ด้วย `Overlapround` อย่างเดียว ถ้า Confirm พังกลางทางแล้ว RI ไม่ขยับ save ครั้งถัดไปจะ **ลบข้อมูลรอบที่ยืนยันแล้วทิ้ง** | 🟠 |
| 6.5 | `GetBudgetOverlapConsiderList:30573` | ป้าย `OverlapStatus` ใช้ `lastRound.HasValue` ⇒ **ทุกใบที่มี item ขึ้น "ขยายระยะเวลา"** รวมใบที่ RI=1 (ยังเป็นกันเงิน) ส่วน `GetBudgetReservedList:28841` ใช้ `currentRound > 1` ซึ่ง **ถูกต้อง** ตามตารางหมวด 1 ⇒ **แก้ที่ :30573** (หน้า Consider = หน้าอนุมัติ กระทบผู้อนุมัติโดยตรง) | 🟠 |
| 6.6 | `BudgetService.cs:27509` | `header.Departmentid` ใช้โดยไม่เช็ค null (มาจาก `FirstOrDefaultAsync` :27030) ⇒ NRE ถ้าส่ง id ที่ไม่มีจริง | 🟡 |
| 6.7 | `BudgetService.cs:27524-27530` | `AccountRule.Budgettypeid` ใช้ต่อทันทีโดยไม่มี `if (AccountRule == null) continue;` ทั้งที่ block ถัดไป :27561 มี ⇒ NRE เมื่อไม่เจอ rule | 🟡 |
| 6.8 | `BudgetService.cs:26714, :26746` | `isOdd` ประกาศแล้วไม่ใช้ + `else` ที่ :26746 **unreachable** — dead code ทำให้อ่านผิดว่ามีทางแยก | 🟡 |
| 6.9 | `GetBudgetOverlapYearCentralDetail` | มีทั้ง API (:2575) และ frontend service (`OAGBudget/Services/Repository/BudgetService.cs:7426`) แต่ **ไม่มี caller** — หน้า Detail จริงเรียก `GetBudgetOverlapYearCentralList` (:3228) ⇒ dead endpoint + ชื่อชวนสับสน | 🟡 |

---

## 7. เรื่อง: Performance ของ `GetBudgetOverlapYearCentralList`

### ✅ ตัดสินใจแล้ว (Q-G)
> "มีแค่เวอร์ชันเดียว ไม่เป็นไรตอนนี้ Preprod"

⇒ **ลดระดับ** ประเด็น DELETE/INSERT บน `APPS.OAG_GL_FUNDS_AVAILABLE_PKG_BYPASS` เป็น **known risk** — บันทึกไว้เฉยๆ ไม่ต้องแก้ตอนนี้
⚠️ แต่ยังเป็นความเสี่ยงจริงตอนขึ้น production: ผู้ใช้ 2 คนเปิดใบที่มี `code_combination_id` ซ้ำกันพร้อมกัน **จะลบแถวของกันและกัน** ได้ค่าผิดหรือ null (:27266)

### ที่ยังควรทำ (ไม่เกี่ยวกับ DBA)
1. **N+1 queries** — :27512, :27564 query `OagwbgVExtOagpoExpenseAccountRuleVs` ทีละ item ใน loop (2 loop), :27093 query `OagwbgVBudgetreceives` ทีละ item ⇒ ดึงทั้งชุดครั้งเดียวแล้ว lookup ใน memory (pattern เดียวกับ :27141 `rules` ที่ทำถูกแล้ว)
2. `NormalizeAccountCode()` :27568 **ประกาศแล้วไม่ถูกเรียกเลย** — `normalizedAccountCodes = AccountCodeList` (:27591) คือ list ดิบ ⇒ ลบทิ้ง หรือเรียกใช้ให้ถูก (ต้องรู้ก่อนว่าตั้งใจอันไหน)
3. method ยาว **~1,900 บรรทัด** (:26954–28850) มี pattern ซ้ำ 6 ชุด (ExpandPO / CancelPO / ExpandPR / CancelPR / ExpandLump / CancelLump) โค้ดเกือบเหมือนกันทุกตัวอักษร ⇒ แยกเป็น private helper
- **R1** — refactor ก้อนใหญ่ ควรทำหลังปิด bug หมวด 6

---

## สรุปลำดับความสำคัญ (rev.6) — ✅ ไม่มีคำถามค้างแล้ว

### 🟢 ทำได้ทันที — ไม่ต้องรอคำตอบใคร (R2)

| ลำดับ | งาน | หัวข้อ |
|---|---|---|
| 1 | `!isConnection` ต้อง `+1` Roundinterface — **บล็อกการทดสอบ flow ทั้งหมด** | 6.3 |
| 2 | แก้วงเล็บ `Max()` ของ CANCEL_PO | 6.1 |
| 3 | ใช้ `filteredExpandTuples` แทน `expandTuples` | 6.2 |
| 4 | แก้ `OverlapStatus` หน้า Consider ให้ใช้ `RI > 1` (**จำเป็นขึ้นเพราะ Q-H**) | 6.5 / 4.6 |
| 5 | ปลดเงื่อนไข "ต้องมีแถว > 0" ของเงินก้อนใหญ่ → "ทุกแถวต้องมีค่า (0 ได้)" | 4.1 |
| 6 | `.Where(Amount > 0)` → `>= 0` ที่ :29877, :29879 (บันทึกแถว 0) | 4.2 |
| 7 | `hasAnyItems` :29513, :29514 → `>= 0` ให้ใบ 0 ล้วนเป็น 90102 | 4.4 |
| 8 | กรอง `Usageamount > 0` ตอน sum ที่ :30563 กัน "เงินกันเหลื่อมปี" แสดง 0 | 4.5 |
| 9 | server guard เงินก้อนใหญ่: EXPAND_LUMP เฉพาะ RI=1, CANCEL_LUMP เฉพาะ RI=2 | 4.3 |
| 10 | รวมสูตร ReservedNo เป็น `BuildReservedNo(transferno, round)` ทั้ง 5 จุด | 2 |
| 11 | แก้สูตร period guard :26571 (`!= 0` → `== 0`) + ย้ายเป็น helper + ผูก feature flag (ยังไม่เปิด) | 3 |
| 12 | ใส่คอมเมนต์ล็อกลำดับ :26726 → :26729 + unit test ครอบ 6 รอบ | 1 |

> **ลำดับ 4-8 ต้องทำพร้อมกันเป็นชุดเดียว** — แก้ 6 อย่างเดียวโดยไม่แก้ 5 จะยังกดยืนยันไม่ได้ / ไม่แก้ 7 สถานะ header กับ item จะไม่ตรงกัน / ไม่แก้ 4, 8 ยอดกับป้ายสถานะในหน้า Consider จะเพี้ยน

### 🔵 งาน DDL (ฝั่ง DB — คุณทำเอง)

| ลำดับ | งาน | หัวข้อ | R |
|---|---|---|---|
| 1 | แก้ join เป็น `INTERFACETYPE = 'C'` + เอา `BATCHNAME LIKE` ออก | 5 (V1-V3) | R2 |
| 2 | **กัน row คูณ** จาก RBN หลายแถวต่อใบ — `GROUP BY ROUNDNO` + `MIN(BATCHNAME)` | 5 (Q-L) | R2 |
| 3 | แก้ `BRB` join ให้เพิ่ม `AND BRB.EXPENSETYPEID = CC.EXPENSE_TYPE_ID` | 5 (V4) | R2 |
| 4 | ทบทวน `EAR` join ที่ใช้ `CATEGORYID` อย่างเดียว | 5 (V5) | R2 |
| 5 | **เพิ่ม branch CR สำหรับกรณียกเลิก** (`UNION ALL` จาก `BUDGETRESERVEDITEM`) — `WEB_BATCH_NO` ขึ้นต้น `REVERSE_`, `TRANSFERTYPE` คงเป็น `'CARRYFWD'` | 5.1 | **R1** |
| 6 | เลือกทางเลือก (ก)/(ข)/(ค) เรื่อง `WEB_BATCH_NO` ที่ไม่ตรงกับ EBS | 5.2 | R2 |

> ลำดับ 5 กระทบระบบปลายทาง — **แจ้งเจ้าของระบบก่อน deploy**
> ลำดับ 6 ไม่บล็อกงานอื่น ค่อยตัดสินใจได้

### ⚪ Backlog

| งาน | หัวข้อ |
|---|---|
| N+1 queries + ลบ `NormalizeAccountCode` ที่ตายแล้ว | 7 |
| แยก method 1,900 บรรทัดเป็น helper 6 ชุด | 7 |
| set `Approve = 1` ให้ region C | 6.4 |
| null guard :27509, :27524 / ลบ dead code :26714, :26746 / ลบ endpoint กำพร้า 6.9 | 6.6-6.9 |
| แก้ชื่อ batch ฝั่ง BG ของรอบยกเลิก :14098 `REVERSE_ENC_` → `REVERSE_BG_` | 5.1 |
| แก้ hardcode `new DateTime(2026, 9, 30)` / `(2026, 10, 1)` :13999-14000 ให้เลื่อนตามปีงบ | 5 |

### ❌ ไม่ต้องทำ (ปิดแล้ว)

| เรื่อง | เหตุผล |
|---|---|
| OVERLAPROUND / RESERVEDNO / ปีงบ | ถูกต้องแล้วทุกช่อง ไม่ต้อง migrate — หมวด 1 |
| ปลดคอมเมนต์ :29859 (เขียน Reservedno ตอน save) | Q-A: เขียนตอนยืนยันเท่านั้น |
| `RESERVEDNO_ADD` สำหรับ `CANCEL_PO` | Q-B: ไม่ต้องมี — :26618 ถูกแล้ว |
| scaffold entity + wire view เข้าหน้า Consider | Q-E: ตรวจใน DB เอง |
| กรอง view รายรอบ `ROUNDINTERFACE` | Q-F: แสดงทั้งใบ — view ถูกแล้ว |
| หา procedure ทดแทน `OAG_GL_FUNDS_AVAILABLE_PKG_BYPASS` | Q-G: มีเวอร์ชันเดียว PREPROD ยอมรับได้ |
| เปลี่ยน prefix batch name ในโค้ด C# ให้เป็น `ENC_`/`BG_` | Q-I: ไม่เปลี่ยน prefix แก้ที่ view แทน |
| แยก batch ตามรอบใน view / เลือก MIN vs MAX | Q-L: region C มี batch เดียวต่อใบ (เขียนแค่รอบแรก) ไม่มีอะไรให้แยก |
| แก้ `ENTERED_CR` ของ **กรณีปกติ** | Q-M: กรณีปกติเป็น DR ถูกแล้ว — CR ใช้เฉพาะกรณียกเลิก ดูหมวด 5.1 |

---

# 8. วิเคราะห์ "แผนการยกเลิก" (เพิ่ม rev.7)

## 8.1 คำว่า "ยกเลิก" ในหน้านี้มี 3 ความหมาย — ต้องแยกก่อนวางแผน

| # | ความหมาย | มีในระบบไหม |
|---|---|---|
| **A** | **ส่งคืนเงิน** — แท็บ "ส่งคืนมีหนี้ / ไม่มีหนี้ / เงินก้อนใหญ่" → `CANCEL_PO` / `CANCEL_PR` / `CANCEL_LUMP` | ✅ มี (แต่ไม่ครบ — ดู 8.3) |
| **B** | **ยกเลิกการยืนยัน** (undo confirm — ถอยรอบกลับ) | ❌ **ไม่มีเลย** |
| **C** | **ลบรายการ / ลบใบ** | ❌ ไม่มีบนหน้า Central |

**หลักฐานของ B และ C:**
- ฟีเจอร์อื่นมี "ยกเลิกการยืนยัน" ครบ (`CancelConfirmBudgetAllocateItems`, `CancelConfirmBudgetRequestOutside`, `ReverseConfirmBudgetReserveTransfer`) แต่ **ไม่มีตัวไหนทำงานบน `OAGWBG_BUDGETRESERVED`** — `ReverseConfirmBudgetReserveTransfer` ทำงานบน `OagwbgBudgettransfers` (โอนจัดสรร) คนละตาราง
- ปุ่มบนหน้า `BudgetOverlapYearCentralDetail.cshtml` มีแค่ `btnSearch` / `btnSave` / `btnSendBack` / `btnSubmit` / `btnConfirm` — **ไม่มีปุ่มลบหรือยกเลิก**
- `DeleteBudgetReservedItem` ถูกเรียกจาก `BudgetOverlapYearPO.cshtml:3308` (ภูมิภาค) เท่านั้น ไม่ผูกกับหน้า Central

## 8.2 โฟลว์ A (ส่งคืนเงิน) ที่มีอยู่จริง

```
1. ติ๊กรายการในแท็บส่งคืน → กดบันทึก
2. SynchronizeReservedItemsAsync เขียน item:
     Budgetreservedtype = CANCEL_PO / CANCEL_PR / CANCEL_LUMP   (:29849-29850, :29948)
     Statusid = 90109
     Overlapround = currentRound
3. กดส่งเรื่อง → หน้าอนุมัติ BudgetOverlapYearConsider
4. อนุมัติ → UpdateBudgetOverlapStatus(StatusId = 90201)
     → items 90109 กลายเป็น 90110 "ยกเลิก(ยืนยัน)"   (:30050-30056)
5. ConfirmBudgetReserved → itemToCancel (90109/90110, Approve == null) → Approve = 1
     ⚠️ แต่บรรทัด :26636-26638 อยู่ใน "บล็อก region P" เท่านั้น — region C ไม่เคยรัน (bug 6.4)
```

## 8.3 🔴 ช่องว่างที่ใหญ่ที่สุด: เงินที่ส่งคืน **ไม่ถูกส่งกลับไปไหนเลย**

ไล่ปลายทางของ `CANCEL_*` ทุกทางแล้ว:

| ปลายทาง | สถานะ |
|---|---|
| ส่ง interface กลับ EBS (ฝั่ง CR) | ❌ **ไม่เคยทำงาน** — ดู 8.4 |
| คืนยอดเข้า `OAGWBG_BUDGETRECEIVE` | ❌ ไม่มีโค้ด — `SaveBudgetReservedCentrall` คืนยอดเฉพาะ `existingCats` (หมวดงบใน `BUDGETRESERVED_CATEGORY`) ไม่แตะ CANCEL item เลย |
| view `..._CENTRAL_DETAIL_INTERFACE` | ❌ ไม่มี branch ยกเลิก (หมวด 5.1) |
| แสดงผลบนหน้าจอ / รายงาน Excel | ✅ มี (`ReportService.cs:3609, :3661`, `GetBudgetOverlapYearCentralList:27506, :27534`) |

⇒ **ตอนนี้ "ส่งคืน" = บันทึกความตั้งใจไว้เฉย ๆ** เงินไม่ขยับจริงทั้งใน OAGWBG และ EBS มีผลแค่กับหน้าจอและรายงาน

## 8.4 🔴 `Part 2: Reversal Processing` เป็น dead code

`SaveBudgetReserved(int? id)` region C มี **Part 2** (`:14086` เป็นต้นไป) ที่สร้างแถว CR ส่ง EBS จาก
`itemsToReverse` = items ที่ `Statusid == 90109 || == 90110` (`:13991`)

**แต่ไม่มีทางถูกเรียกในจังหวะที่มี CANCEL item อยู่:**

| ขั้น | สถานะ |
|---|---|
| ผู้เรียกเดียวในโฟลว์กันเงิน | `ConfirmBudgetReserved:26773` |
| :26773 อยู่ในกิ่งไหน | กิ่ง **`wasNull`** (ยืนยันครั้งที่ 1) เท่านั้น |
| ยืนยันครั้งที่ 2 ขึ้นไป | `if (!wasNull)` ที่ `:26738` **return ก่อน** → ไม่เคยไปถึง :26773 |
| ตอนยืนยันครั้งที่ 1 มี CANCEL item ไหม | **ไม่มี** — แท็บส่งคืนโผล่หลัง `Roundinterface != null` หรือ `Statusid == 20202` ซึ่งเกิดหลัง confirm ครั้งแรก |

⇒ `itemsToReverse.Any()` เป็น **false เสมอ** → Part 2 ไม่เคยรันแม้แต่ครั้งเดียว
(อีกผู้เรียกหนึ่งที่ `:26450` อยู่ใน `ConfirmBudgetRequestOutside` — คนละฟีเจอร์ เงินนอกงบประมาณ)

## 8.5 ทำไมคำตอบ Q-M ("CR เผื่อไว้ตอนยกเลิก") ถึงเป็นทางออกที่ถูก

spec ข้อ 3 ระบุ **"รอบขยายไม่ส่ง Interface แต่แสดงใน view"**
⇒ ช่องทางเดียวที่รอบขยาย/ส่งคืนจะไปถึงระบบปลายทางคือ **view** ไม่ใช่โค้ด C#

⇒ การเพิ่ม branch CR เข้า view (หมวด 5.1) **ไม่ใช่ nice-to-have** แต่เป็น**ช่องทางเดียวที่ทำให้การส่งคืนมีผลจริง**
และ Part 2 ใน C# ที่ตายอยู่ ก็คือความพยายามเดิมที่จะทำสิ่งเดียวกันผ่านอีกช่องทาง

## 8.6 ⚠️ ความเสี่ยง: ถ้าเปิดใช้ทั้งสองทางพร้อมกัน = กลับรายการ 2 เท่า

ถ้าวันหนึ่งมีคนแก้ให้ `SaveBudgetReserved` ถูกเรียกในรอบขยายด้วย (เช่น แก้ early return ที่ :26738)
Part 2 จะเริ่มทำงาน **พร้อมกับ** branch CR ใน view ⇒ EBS จะได้รายการกลับรายการ **2 ชุด**

⇒ ต้องเลือกช่องทางเดียวแล้ว**ปิดอีกช่องทางให้ชัด** ไม่ปล่อยให้ dead code ค้างไว้เฉย ๆ

## 8.7 แผนที่แนะนำ — เรียงตาม dependency

### Phase 1 — ทำให้ "ส่งคืน" มีผลจริง (ต้องเสร็จก่อน UAT)
| # | งาน | R |
|---|---|---|
| 1 | DDL: เพิ่ม branch CR เข้า view ตามโครงในหมวด 5.1 (`WEB_BATCH_NO` ขึ้นต้น `REVERSE_`) | R1 |
| 2 | ตัดสินใจชะตากรรมของ Part 2 — **ลบทิ้ง** หรือ **คอมเมนต์พร้อมเหตุผล** (ดู Q-P) | R2 |
| 3 | แก้ bug 6.4 — region C ตั้ง `Approve = 1` ให้ item ที่ยืนยันแล้ว ไม่งั้นไม่มีตัวแยก "ส่งคืนที่ยืนยันแล้ว" ออกจาก "ที่ยังแก้ได้" | R2 |
| 4 | ทดสอบ end-to-end: กันเงิน → ขยาย → ส่งคืน → ตรวจแถว CR ใน view | — |

### Phase 2 — คืนยอดในฝั่ง OAGWBG (ถ้าธุรกิจต้องการ)
| # | งาน | R |
|---|---|---|
| 5 | ถ้าต้องคืนยอดเข้า `OAGWBG_BUDGETRECEIVE` ต้องเขียนใหม่ทั้งหมด — ตอนนี้ไม่มีโค้ดเลย (ดู Q-O) | R1 |

### Phase 3 — "ยกเลิกการยืนยัน" (B) — **แนะนำอย่าเพิ่งทำ**
ประเมินแล้วยากและเสี่ยงสูงมาก เพราะต้องถอยหลังทั้งหมดนี้พร้อมกัน:
- `Roundinterface` -1, `Budgetyear` -1 (เฉพาะรอบที่ +1 ไป), `Reservedno` ที่ stamp แล้ว, `Overlapround`
- ลบแถว `OAGWBG_BUDGETRECEIVE` ที่สร้างตอน confirm ครั้งที่ 1
- ลบแถว `OAGWBG_RECEIVE_BATCH_NO`
- กลับรายการที่ส่ง EBS ไปแล้ว

**อุปสรรคหลัก:** ไม่มี audit trail ว่า confirm รอบไหนสร้างอะไร — `OAGWBG_BUDGETRECEIVE` ไม่มีคอลัมน์บอกรอบ และ `RECEIVE_BATCH_NO` ก็ไม่มี (ดู Q-L) ⇒ **ถอยแบบแม่นยำไม่ได้**

⇒ ถ้าจำเป็นต้องมีจริง ควรทำ **audit trail ก่อน** (เพิ่มคอลัมน์ `ROUNDINTERFACE` ในตารางที่เกี่ยวข้อง) แล้วค่อยทำ undo

## 8.8 คำถามที่ต้องตอบก่อนเริ่ม Phase 1-2

- **Q-O:** "ส่งคืน" ต้องคืนยอดเข้า `OAGWBG_BUDGETRECEIVE` ด้วยไหม หรือส่ง CR ให้ EBS อย่างเดียวพอ (ให้ EBS เป็นแหล่งความจริง)?
- **Q-P:** `Part 2: Reversal Processing` (`:14086-14230`) — **ลบทิ้ง** หรือ **เก็บไว้เผื่ออนาคต**? ถ้าเก็บต้องใส่คอมเมนต์ชัดว่ายังไม่ถูกเรียก กันคนมาแก้แล้วเกิดกลับรายการซ้ำ
- **Q-Q:** ต้องมี "ยกเลิกการยืนยัน" (ข้อ B) ในหน้านี้ไหม หรือถ้าผิดให้แก้ด้วยการส่งคืนแทน?

---

# 9. แผนงาน "ส่งคืนเงิน" ให้มีผลจริง (Q-O = ทำทั้งสองอย่าง)

## 9.1 ยืนยันความหมายของ "ทั้งสองอย่าง"

| ช่องทาง | ทำผ่านอะไร | อ้างอิงมติ |
|---|---|---|
| **(1) ส่ง CR ให้ EBS** | branch CR ใน `..._CENTRAL_DETAIL_INTERFACE` (หมวด 5.1) | Q-M + Q-N |
| **(2) คืนยอดใน OAGWBG** | โค้ด C# ใหม่ — คืนเข้า `OAGWBG_BUDGETRECEIVE` | Q-O |

> ⚠️ **ไม่ใช่**การเปิด `Part 2` ใน C# — Q-P สั่งให้เก็บไว้เป็นโค้ดที่ไม่ทำงาน (ใส่คอมเมนต์เตือนไว้แล้วที่ `:14086`)
> ถ้าเปิด Part 2 พร้อมกับ branch CR ในview EBS จะได้รายการกลับรายการ **2 ชุด**

## 9.2 ✅ ข่าวดี: หาแถวปลายทางได้ ไม่ต้องเดา

`OAGWBG_BUDGETRECEIVE` ที่ใบนี้สร้างไว้ ผูกกลับมาหาใบกันเงินอยู่แล้ว (`:26817-26818`)
```csharp
Budgetreservedid       = item.Budgetreservedid,   // = OAGWBG_BUDGETRESERVED.ID
Budgetreservedcategoryid = item.Id,               // = OAGWBG_BUDGETRESERVED_CATEGORY.ID
```
⇒ ชุดแถวที่ต้องคืนยอด = `WHERE Budgetreservedid = header.Id` ได้ทันที

## 9.3 🔴 ปัญหา: จับคู่ CANCEL_PO / CANCEL_PR กับแถว BUDGETRECEIVE ไม่ตรงตัว

| ประเภท | ตัวเชื่อม | จับคู่ได้ไหม |
|---|---|---|
| `CANCEL_LUMP` | **`Headerid` = `OAGWBG_BUDGETRECEIVE.ID`** (set ที่ `:29948` ฝั่ง lump) | ✅ **ตรงตัว 1:1** |
| `CANCEL_PO` / `CANCEL_PR` | มีแค่ `Accountcode` (13 segment) + `Booknumber` — **ไม่มี `Headerid`** (ดู `:29878-29900`) | ⚠️ ต้อง map ผ่าน segment |

**วิธี map ที่เป็นไปได้** — แตก `Accountcode` แล้วเทียบภายในขอบเขต `Budgetreservedid = header.Id`:

| Segment | ความหมาย | คอลัมน์ใน BUDGETRECEIVE |
|---|---|---|
| 1 | Department | `Departmentid` |
| 2 | Cost center | `Costcenterid` |
| 3 | ปี 2 หลัก | `Budgetyear` (mod 100) |
| 4 | Budget source | `Budgetsourceid` |
| 5 | Budget plan | `Budgetplanid` |
| 6 | Product | `Productid` |
| 7 | Activity | `Activityid` |
| 9 | Budget code | *(ไม่มีคอลัมน์ตรง — อยู่ใน CATEGORY)* |

⚠️ `Categoryid` **ไม่อยู่ใน account code** (ได้มาทางอ้อมผ่าน `EXPENSE_ACCOUNT_RULE`) และฟิลด์ `Categorycode` บน item ก็เชื่อไม่ได้ — ตอน map จาก PO/PR ดิบมันเก็บ `Segment10` (เลขบัญชี) ไม่ใช่ category id (`GetBudgetOverlapYearCentralList` ตอน map `poItemsMapped`)

⇒ **มีโอกาสที่ 1 account code จะ match หลายแถว** ต้องมีกติกาตัดสิน

## 9.4 จังหวะที่ควรคืนยอด — แนะนำ "ตอนยืนยัน" พร้อมตั้ง `Approve = 1`

```
บันทึก  → item CANCEL_* Statusid 90109, Approve = null   ← ยังไม่คืนยอด (ยังแก้ได้)
ส่งเรื่อง → หน้า Consider
อนุมัติ  → UpdateBudgetOverlapStatus(90201) → 90110
ยืนยัน   → ConfirmBudgetReserved → UpdateHeaderAndItemsStatusAsync (กิ่ง region "C")
              ├─ ตั้ง Approve = 1 ให้ item ที่ Approve == null   ← แก้ bug 6.4 ไปในตัว
              └─ คืนยอดเข้า BUDGETRECEIVE เฉพาะ item ที่เพิ่งเปลี่ยนเป็น Approve = 1
```

**ทำไมจังหวะนี้:**
- `Approve == null → 1` เป็น **กันคืนซ้ำในตัว** (idempotent) ใช้กลไกเดียวกับที่ region P ใช้อยู่แล้ว (`:26636-26638`)
- ก่อนยืนยันผู้ใช้ยังแก้ยอดส่งคืนได้ ถ้าคืนยอดตั้งแต่ตอนบันทึกจะต้องเขียน logic หักกลับทุกครั้งที่แก้
- ทำให้ bug 6.4 (region C ไม่เคยตั้ง `Approve`) หายไปพร้อมกัน

**ยอดที่คืน:** `Usageamount` ของ item (ยอดที่ผู้ใช้กรอกในช่องส่งคืน)
**คืนอย่างไร:** `Totalbalanceamount += Usageamount` และ `Totalreservedamount -= Usageamount` (กลับทางกับตอนหักใน `SaveBudgetReservedCentrall`)

## 9.5 ❓ คำถามที่ต้องตอบก่อนเขียนโค้ด

- **Q-R:** ถ้า account code ของ `CANCEL_PO`/`CANCEL_PR` match แถว `BUDGETRECEIVE` **ได้หลายแถว** จะให้ทำอย่างไร?
  - (ก) คืนเข้าแถวที่ `Totalreservedamount` มากสุดก่อน แล้วไล่ลง (แพทเทิร์นเดียวกับตอนหักใน `SaveBudgetReservedCentrall`)
  - (ข) เฉลี่ยตามสัดส่วน
  - (ค) เพิ่มคอลัมน์ `HEADERID` ให้ `CANCEL_PO`/`CANCEL_PR` ตอนบันทึก (แก้ที่ต้นทาง — สะอาดสุดแต่ต้องแก้หน้าจอให้ส่ง receive id มาด้วย)
  - **ผมแนะนำ (ก)** เพราะเข้ากับโค้ดเดิมที่สุด และ **(ค) เป็นเป้าหมายระยะยาว**
- **Q-S:** ถ้ายอดส่งคืนรวม **มากกว่า** `Totalreservedamount` ที่เหลืออยู่ ให้ทำอย่างไร — ปฏิเสธ (throw) หรือคืนเท่าที่มี?

---

# 10. แผนงาน "ยกเลิกการยืนยัน" (Q-Q)

## 10.1 ✅ ขอบเขตที่ตกลง
> "มี แต่ต้องยกเลิกและส่งเรื่องใหม่ได้ภายในรอบปีงบประมาณเดียวกันกับที่ส่งตอนแรก"

⇒ undo confirm ได้ **เฉพาะเมื่อยังอยู่ในปีงบประมาณเดียวกับตอนที่ยืนยัน** แล้วส่งเรื่องใหม่ได้
ข้อจำกัดนี้ทำให้ scope เล็กลงมาก — ไม่ต้องรองรับการถอยข้ามปีงบ

## 10.2 🔴 ตัวบล็อกหลัก: ไม่มี audit trail ว่า "ยืนยันรอบไหน เมื่อไหร่ เปลี่ยนอะไรไป"

| รอบ | มีร่องรอยเวลาที่ยืนยันไหม |
|---|---|
| ยืนยันครั้งที่ 1 | ✅ `OAGWBG_RECEIVE_BATCH_NO.CREATEON` (region C เขียนแถวตอน confirm แรก `:26847-26862`) |
| ยืนยันครั้งที่ 2 ขึ้นไป | ❌ **ไม่มีเลย** — ไม่เขียน batch, ไม่ส่ง interface เหลือแค่ `BUDGETRESERVED.UPDATEON` ซึ่งถูกทับทุกครั้งที่กดบันทึก |

⇒ **เช็คเงื่อนไข "ภายในปีงบประมาณเดียวกัน" สำหรับรอบ 2+ ไม่ได้** ถ้าไม่เพิ่ม audit trail ก่อน

**ตารางที่มีอยู่แล้วแต่ยังไม่ถูกใช้:** `OAGWBG_CANCELREASONLOG` (`Referencetable`, `Referenceid`, `Remark`, `Createby`, `Createon`) — ไม่มีโค้ดอ้างถึงเลยทั้งโปรเจกต์ ใช้เก็บ**เหตุผลการยกเลิก**ได้ทันที แต่**ไม่ช่วยเรื่องเวลาที่ยืนยัน**

## 10.3 แผนที่แนะนำ — 2 ขั้น

### ขั้น A — สร้าง audit trail ก่อน (ต้องทำก่อน ไม่มีทางลัด)

ตารางใหม่ `OAGWBG_BUDGETRESERVED_CONFIRMLOG`:

| คอลัมน์ | ใช้ทำอะไรตอน undo |
|---|---|
| `ID` | PK |
| `BUDGETRESERVEDID` | ใบไหน |
| `ROUNDINTERFACE` | ยืนยันรอบที่เท่าไหร่ |
| `BUDGETYEAR_BEFORE` / `BUDGETYEAR_AFTER` | คืนปีงบกลับให้ถูก (รอบคี่เท่านั้นที่ +1) |
| `CONFIRMEDON` / `CONFIRMEDBY` | ใช้เช็คกติกา "ปีงบประมาณเดียวกัน" |
| `BATCHNAME` | รอบแรกที่ส่ง interface — ใช้อ้างอิงตอนกลับรายการ |
| `INTERFACESENT` (Y/N) | บอกว่ารอบนี้ส่ง EBS ไปหรือเปล่า |

เขียน 1 แถวทุกครั้งที่ `ConfirmBudgetReserved` สำเร็จ ⇒ undo = อ่านแถวล่าสุด ย้อนตามที่บันทึกไว้ แล้วลบแถวนั้น

### ขั้น B — เขียน `ReverseConfirmBudgetReserved`

**ด่านตรวจก่อนทำ:**
1. มีแถว confirmlog หรือไม่ (ถ้าไม่มี = ยังไม่เคยยืนยัน)
2. `GetThaiFiscalYear(DateTime.Now) == GetThaiFiscalYear(log.Confirmedon)` ← กติกาจาก Q-Q
3. สถานะปัจจุบันยกเลิกได้ (20202 / 90201)
4. ยังไม่มีรอบถัดไปยืนยันทับ (undo ได้เฉพาะรอบล่าสุด)

**ขั้นตอนย้อน (ใน transaction เดียว):**

| # | ย้อนอะไร | หมายเหตุ |
|---|---|---|
| 1 | `Roundinterface -= 1` | |
| 2 | `Budgetyear = log.Budgetyear_before` | |
| 3 | `Statusid` กลับเป็น 90102 | |
| 4 | `Reservedno = null` เฉพาะ item ที่ `Reservedno == BuildReservedNo(transferno, undoRound)` | ⚠️ ห้ามล้างของรอบก่อนหน้าที่ PO ตัวเดิม reuse เลขอยู่ |
| 5 | `Approve = null` เฉพาะ item ที่ `Overlapround == undoRound` | |
| 6 | ถ้า Q-O ทำแล้ว — **หักยอดที่คืนไปกลับคืน** | ต้องกลับทางกับ 9.4 |
| 7 | **ถ้าเป็นรอบที่ 1:** ลบ `OAGWBG_BUDGETRECEIVE` ที่ `Budgetreservedid = id` + ลบ `RECEIVE_BATCH_NO` + ส่ง REVERSE ให้ EBS | **R1** — จุดเสี่ยงสูงสุด |
| 8 | บันทึกเหตุผลลง `OAGWBG_CANCELREASONLOG` (`Referencetable = 'BudgetReserved'`) | |
| 9 | ลบแถว confirmlog ของรอบนั้น | |

## 10.4 ประเมินความเสี่ยง

| กรณี | ระดับ | เหตุผล |
|---|---|---|
| undo รอบ 2 ขึ้นไป | **R2** | ไม่เคยส่ง interface ย้อนเฉพาะข้อมูลใน OAGWBG |
| undo รอบ 1 | **R1** | ต้องลบ `BUDGETRECEIVE` ที่ระบบอื่นอาจอ้างถึงแล้ว + กลับรายการ EBS |

**ข้อควรระวัง:** ถ้า `BUDGETRECEIVE` ของรอบ 1 ถูกเอาไปโอนจัดสรรต่อแล้ว (`OAGWBG_BUDGETALLOCATETRANSFER` — แท็บโอนจัดสรรตามสเปกข้อ 2.4) การลบจะทำให้ข้อมูลปลายทางกำพร้า
⇒ **ต้องมีด่านตรวจเพิ่ม:** ถ้าใบนี้ถูกโอนจัดสรรไปแล้ว ห้าม undo รอบ 1

## 10.5 ❓ คำถาม

- **Q-T:** "ปีงบประมาณเดียวกัน" นับจาก **ปฏิทินปีงบไทย (1 ต.ค. – 30 ก.ย.)** ใช่ไหม? และเทียบกับ **วันที่ยืนยัน** หรือ **`TRANSFERDATE` บนใบ**?
- **Q-U:** undo ได้เฉพาะ **รอบล่าสุด 1 รอบ** หรือย้อนได้หลายรอบติดกัน?
- **Q-V:** ถ้าใบถูกโอนจัดสรรต่อไปแล้ว ให้ **บล็อกไม่ให้ undo** ใช่ไหม?
