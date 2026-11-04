# วิเคราะห์: หน้า "เบิกเงินจากกรมบัญชีกลาง" — ยกเลิก Interface แล้ว popup ไม่แสดงข้อมูล

> **วันที่:** 2026-09-04
> **หน้าจอ:** เบิกเงินจากกรมบัญชีกลาง (`BudgetPaymentGfDetail` งบประจำปี + `BudgetPaymentGfMoreDetail` งบเพิ่มเติม/งบกลาง)
> **ฟีเจอร์:** ยกเลิกการยืนยัน → กลับรายการ Interface ไป Oracle EBS (C → D) — ต่อยอดจาก `20260702_Cancel_Case`
> **ระดับความเสี่ยงของการแก้ (R):** **R2 — ย้อนกลับง่าย** (แก้ 1 method ฝั่ง MVC, ไม่แตะ DB / ไม่แตะ EBS / ไม่เปลี่ยน API contract)
> **สถานะการยืนยันสาเหตุ:** ✅ พิสูจน์ซ้ำได้จริงด้วย test harness (มีผลลัพธ์จริงแนบด้านล่าง) — ไม่ใช่การเดา

---

## 1. บทสรุปผู้บริหาร (TL;DR)

**อาการ:** กดยกเลิกการยืนยัน → popup แจ้งเตือนขึ้นมาปกติ ข้อความหลักอ่านได้ แต่ตารางสรุปในกล่องข้อความ คอลัมน์ **ชุดบัญชี / ยอดที่ต้องดึงคืน / งบคงเหลือที่ตรวจได้** เป็น `-` ทั้งหมด และทุกแถวขึ้น badge แดง "ไม่เพียงพอ" รวมทั้ง "ยอดรวมที่จะดึงคืน" ก็เป็น `-`

**สาเหตุ:** ไม่ใช่ปัญหาที่ Oracle / API / SQL — **API ส่งข้อมูลมาครบ** แต่ข้อมูลถูกทำลายระหว่างทางที่ชั้น MVC เพราะ:

> ฝั่ง MVC deserialize response ของ API ด้วย **Newtonsoft** → `ApiResultsModel.Data` (ชนิด `object?`) กลายเป็น **`JObject`**
> จากนั้น `return Json(result)` ของ MVC ใช้ **System.Text.Json** ซึ่ง **serialize `JObject`/`JToken` ออกมาเพี้ยน** — ทุกค่ากลายเป็น array ว่าง `[]`

**จุดที่ต้องแก้:** [BudgetService.cs:5879](OAGBudget/Services/Repository/BudgetService.cs#L5879) — method `PostBudgetPaymentGfCancelAction` ขาดการแปลง `JObject` → type จริง ก่อนส่งต่อให้หน้าจอ

**หลักฐานว่านี่คือสาเหตุ (precedent):** ฟีเจอร์ยกเลิกอีก 2 หน้าที่ทำก่อนหน้านี้ **เคยเจอบั๊กเดียวกันและแก้ด้วยวิธีนี้ไปแล้ว** พร้อมคอมเมนต์อธิบายไว้ในโค้ด

- [BudgetService.cs:3269](OAGBudget/Services/Repository/BudgetService.cs#L3269) — `CheckCancelBudgetRequestOutside`
  > *"แปลง JObject เป็น type จริงก่อนส่งต่อ ไม่งั้น System.Text.Json ฝั่ง MVC serialize JToken ออกมาเพี้ยน"*
- [BudgetService.cs:6966](OAGBudget/Services/Repository/BudgetService.cs#L6966) — `CheckCancelBudgetRequisition`

→ **หน้า "เบิกเงินจากกรมบัญชีกลาง" คือหน้าที่ตกหล่น ไม่ได้ทำ step นี้**

---

## 2. อาการที่พบ (Expected vs Actual)

| จุด | ที่ควรเป็น | ที่เกิดขึ้นจริง |
|---|---|---|
| ข้อความหลักใน popup | แสดงข้อความจาก API | ✅ แสดงถูกต้อง |
| จำนวนแถวในตาราง | เท่าจำนวนชุดบัญชี | ✅ ถูกต้อง (แถวขึ้นครบ) |
| คอลัมน์ **ชุดบัญชี** | `01.02.03...` (13 segment) | ❌ `-` |
| คอลัมน์ **ยอดที่ต้องดึงคืน** | `5,000.00` | ❌ `-` |
| คอลัมน์ **งบคงเหลือที่ตรวจได้** | `100.00` | ❌ `-` |
| คอลัมน์ **ผล** | เขียว "เพียงพอ" / แดง "ไม่เพียงพอ" | ❌ แดง "ไม่เพียงพอ" ทุกแถว |
| **ยอดรวมที่จะดึงคืน** | `12,345.00 บาท` | ❌ `-` |

> **⚠ ข้อสังเกตสำคัญ:** อาการ "ขึ้นแดงทุกแถว" ทำให้ดูเหมือนเป็นปัญหา *งบไม่พอ* ทั้งที่จริงเป็นปัญหา *ข้อมูลหาย* — ผู้ใช้อาจเข้าใจผิดว่างบใน EBS มีปัญหา

---

## 3. Flow ของฟีเจอร์ (UI → MVC → API → Oracle)

```
[Razor View] BudgetPaymentGfDetail.cshtml / BudgetPaymentGfMoreDetail.cshtml
   cancelConfirmBudgetPaymentGf(id)
        │  $.post  /Budget/CheckCancelBudgetPaymentGf
        ▼
[MVC Controller] OAGBudget/Controllers/BudgetController.cs:3036
   CheckCancelBudgetPaymentGf → return Json(result)        ◀── ❌ จุดที่ข้อมูลเพี้ยน (System.Text.Json)
        ▲
[MVC Service] OAGBudget/Services/Repository/BudgetService.cs:5866 → 5879
   PostBudgetPaymentGfCancelAction("CheckCancelBudgetPaymentGf", ...)
   JsonConvert.DeserializeObject<ApiResultsModel>(json)     ◀── ❌ Data กลายเป็น JObject แล้วไม่ถูกแปลงต่อ
        │  HTTP POST (Bearer token, timeout 10 นาที)
        ▼
[API Controller] OAGBudget.API/Controllers/BudgetController.cs:1267
        ▼
[API Service] OAGBudget.API/Services/Repository/BudgetService.cs:9522
   CheckCancelBudgetPaymentGf
     ด่าน 1: ตรวจการใช้งบต่อ (โอน / กันเงินเหลื่อมปี / เบิกจ่าย-ผูกพัน)
     ด่าน 2: GetPostedBudgetPaymentGfLines → รวมยอด ENTERED_DR ต่อ 1 ชุดบัญชี (13 segment)
             → GetTotalBudget(orgId, segment, OracleConnection) เทียบงบคงเหลือใน EBS
     Data = BudgetPaymentGfCancelCheckResult { Items[], TotalAmount, CanCancel, ... }   ◀── ✅ ข้อมูลครบถูกต้อง
```

**สรุป: ข้อมูลถูกต้องจนถึงชั้น API — พังตอน MVC ส่งต่อให้ browser เท่านั้น**

---

## 4. Root Cause แบบละเอียด

### 4.1 ต้นตอ: Serializer 2 ตัวปนกันในชั้นเดียว

| ชั้น | Serializer ที่ใช้ | อ้างอิง |
|---|---|---|
| OAGBudget.API (ตอบกลับ) | **System.Text.Json** (camelCase) | [Program.cs:109](OAGBudget.API/Program.cs#L109) |
| OAGBudget (MVC) อ่าน response | **Newtonsoft** `JsonConvert.DeserializeObject` | [BudgetService.cs:5847](OAGBudget/Services/Repository/BudgetService.cs#L5847) |
| OAGBudget (MVC) `Json(result)` ตอบ browser | **System.Text.Json** | [Program.cs:23](OAGBudget/Program.cs#L23) |

`ApiResultsModel.Data` ประกาศเป็น `object?` ([ApiResultsModel.cs:11](OAGBudget.Models/Common/ApiResultsModel.cs#L11)) → Newtonsoft ไม่รู้ type ปลายทาง จึงยัดเป็น **`Newtonsoft.Json.Linq.JObject`**

ต่อมา System.Text.Json ไม่รู้จัก `JObject` แต่ `JObject`/`JArray`/`JValue` ทั้งหมด implement `IEnumerable<JToken>` → STJ จึงมองเป็น **collection** แล้ว serialize ทุกอย่างเป็น array ซ้อน array จนค่าจริงหายหมด

### 4.2 หลักฐานจากการทดสอบซ้ำ (reproduce จริง)

รัน test harness (.NET 8 + Newtonsoft 13.0.3) จำลอง JSON ที่ API ตอบกลับ แล้วส่งผ่านเส้นทางเดียวกับโค้ดจริง ได้ผลดังนี้

**Input — JSON ที่ API ส่งมา (ถูกต้อง):**

```json
{"data":{"id":123,"budgetyear":2569,"canCancel":false,"isBudgetInsufficient":true,
 "blockedReason":null,"totalAmount":5000.00,
 "items":[{"accountSegment":"01.02.03","amount":5000.00,"availableBudget":100.00,
           "description":"test","canCancel":false,"reason":"งบไม่พอ"}]},
 "message":"ไม่สามารถทำรายการได้","type":"error","success":false}
```

**Output — สิ่งที่ browser ได้รับจริงหลังผ่าน MVC (ของเดิม / ยังไม่แก้):**

```
Data runtime type = Newtonsoft.Json.Linq.JObject

{"data":{"id":[],"budgetyear":[],"canCancel":[],"isBudgetInsufficient":[],
 "blockedReason":[],"totalAmount":[],
 "items":[[[[]],[[]],[[]],[[]],[[]],[[]]]]},
 "message":"ไม่สามารถทำรายการได้","type":"error","success":false}
```

**Output — หลังใส่ `ToObject<T>()` (วิธีแก้ที่เสนอ):**

```
{"data":{"id":123,"budgetyear":2569,"canCancel":false,"isBudgetInsufficient":true,
 "blockedReason":null,"totalAmount":5000,
 "items":[{"accountSegment":"01.02.03","amount":5000,"availableBudget":100,
           "description":"test","canCancel":false,"reason":"งบไม่พอ"}]},
 "message":"ไม่สามารถทำรายการได้","type":"error","success":false}
```

### 4.3 ทำไม "ข้อความขึ้น แต่ตารางว่าง" (อาการตรงกับที่พบ 100%)

- `message` / `success` / `type` เป็น `string`/`bool` ธรรมดา → Newtonsoft map เข้า property ได้ตรง ๆ (Newtonsoft ไม่สนตัวพิมพ์เล็ก-ใหญ่) → **ไม่เพี้ยน จึงยังแสดงผลได้**
- `data` เป็น `object?` → กลายเป็น JObject → **เพี้ยนทั้งก้อน**
- ฝั่ง JS ใน [BudgetPaymentGfDetail.cshtml:763](OAGBudget/Views/Budget/BudgetPaymentGfDetail.cshtml#L763) `gfBuildCancelCheckTable()`:

| โค้ด JS | ค่าที่ได้จริง | ผลบนจอ |
|---|---|---|
| `items` | `[ [ [[]],[[]],... ] ]` → length = 1 | จำนวนแถว**ถูก** (นับตาม JArray) |
| `gfCancelProp(it,'AccountSegment')` | `undefined` | fallback เป็น **`-`** |
| `gfCancelMoney(gfCancelProp(it,'Amount'))` | `parseFloat(undefined)` = `NaN` | **`-`** |
| `gfCancelProp(it,'AvailableBudget')` | `undefined` | **`-`** |
| `gfCancelProp(it,'CanCancel') === true` | `undefined === true` → `false` | badge **แดง "ไม่เพียงพอ"** ทุกแถว |
| `total = gfCancelProp(checkData,'TotalAmount')` | `[]` (ไม่ใช่ null/undefined) | `gfCancelMoney([])` → `NaN` → **`-`** |

> ตรงกับอาการที่รายงานมาทุกข้อ — ยืนยันว่าไม่ต้องไปไล่หา bug ฝั่ง Oracle หรือ SQL

### 4.4 สิ่งที่ **ไม่ใช่** สาเหตุ (ตัดออกแล้ว)

- ❌ Oracle / `GetTotalBudget` ตอบค่าไม่มา — ถ้าเป็นแบบนั้น `AvailableBudget` จะเป็น `null` แต่ `AccountSegment` กับ `Amount` ต้องยังแสดงได้
- ❌ ชื่อ property camelCase/PascalCase ไม่ตรง — `gfCancelProp()` รองรับทั้งสองแบบอยู่แล้ว
- ❌ `isConnection = false` (โหมดไม่ต่อ EBS) — เคสนั้น `Items` ว่าง ตารางจะ**ไม่ขึ้นเลย** ไม่ใช่ขึ้นแถวเปล่า
- ❌ สิทธิ์ / token หมดอายุ — จะได้ HTTP error แล้ว JS เข้า `catch` ขึ้น "ไม่สามารถติดต่อระบบได้"

---

## 5. วิธีแก้ไข

### 5.1 แก้หลัก (บังคับ) — แปลง `JObject` เป็น type จริงก่อนส่งต่อ

**ไฟล์:** [OAGBudget/Services/Repository/BudgetService.cs](OAGBudget/Services/Repository/BudgetService.cs#L5879)
**Method:** `PostBudgetPaymentGfCancelAction` (ใช้ร่วมกันทั้ง `CheckCancelBudgetPaymentGf` และ `CancelConfirmBudgetPaymentGf` → แก้จุดเดียวได้ทั้ง 2 action และครอบคลุมทั้งหน้างบประจำปี + งบเพิ่มเติม)

**ก่อนแก้:**

```csharp
if (response.IsSuccessStatusCode)
{
    var json = await response.Content.ReadAsStringAsync();
    var apiResult = JsonConvert.DeserializeObject<ApiResultsModel>(json);

    if (apiResult != null)
    {
        return apiResult;
    }
}
```

**หลังแก้:**

```csharp
if (response.IsSuccessStatusCode)
{
    var json = await response.Content.ReadAsStringAsync();
    var apiResult = JsonConvert.DeserializeObject<ApiResultsModel>(json);

    if (apiResult != null)
    {
        // แปลง JObject เป็น type จริงก่อนส่งต่อ ไม่งั้น System.Text.Json ฝั่ง MVC
        // จะ serialize JToken ออกมาเป็น array ว่าง ทำให้ตารางในหน้าจอไม่มีข้อมูล
        // (เหมือน CheckCancelBudgetRequestOutside / CheckCancelBudgetRequisition)
        if (apiResult.Data is JObject jObject)
        {
            apiResult.Data = jObject.ToObject<BudgetPaymentGfCancelCheckResult>();
        }
        return apiResult;
    }
}
```

**หมายเหตุการ compile:** `using Newtonsoft.Json.Linq;` และ `using OAGBudget.Models.ViewModel;` มีอยู่แล้วที่หัวไฟล์ (บรรทัด 8 และ 16) — **ไม่ต้องเพิ่ม using**
คลาส `BudgetPaymentGfCancelCheckResult` อยู่ที่ [BudgetPaymentGfDetailViewModel.cs:36](OAGBudget.Models/ViewModel/BudgetPaymentGfDetailViewModel.cs#L36)

### 5.2 แก้เสริม (แนะนำ) — กันพลาดฝั่งหน้าจอ

ปัจจุบัน `gfCancelMoney()` เจอค่าเพี้ยนแล้วคืน `-` เงียบ ๆ ทำให้ debug ยาก ถ้าต้องการให้ error ครั้งหน้า "ดังกว่านี้" ให้ log ไว้ด้วย (แก้ทั้ง 2 ไฟล์ view):

```javascript
function gfCancelMoney(value) {
    const n = parseFloat(value);
    if (isNaN(n)) {
        if (value !== null && value !== undefined) console.warn('gfCancelMoney: ค่าไม่ใช่ตัวเลข', value);
        return '-';
    }
    return n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}
```

> ข้อนี้เป็น **nice-to-have** ไม่ใช่ must-have — ถ้าต้องการคุม scope ให้แคบ ทำเฉพาะข้อ 5.1 ก็จบปัญหาแล้ว

### 5.3 ไฟล์ที่ต้องแก้ (สรุป)

| ไฟล์ | System | จำเป็น |
|---|---|---|
| `OAGBudget\Services\Repository\BudgetService.cs` | TFS | ✅ บังคับ |
| `OAGBudget\Views\Budget\BudgetPaymentGfDetail.cshtml` | TFS | ⬜ เสริม (5.2) |
| `OAGBudget\Views\Budget\BudgetPaymentGfMoreDetail.cshtml` | TFS | ⬜ เสริม (5.2) |

**ไม่ต้องแก้:** OAGBudget.API, OAGBudget.Models, OAGBudget.DAL, Oracle (view / package / table) — ข้อมูลฝั่งนั้นถูกต้องอยู่แล้ว

---

## 6. ขั้นตอนดำเนินการ (ตาม TFS Checkin Rules)

```powershell
# 1) get latest ก่อนเสมอ — ถ้ามี conflict ให้ ABORT
tf get "D:\TFS\OAG Budget" /recursive 2>&1 | Select-Object -Last 10

# 2) checkout ไฟล์
tf edit "D:\TFS\OAG Budget\OAGBudget\Services\Repository\BudgetService.cs"

# 3) แก้ไขตามข้อ 5.1

# 4) build ต้องผ่าน 0 Error ก่อน checkin เสมอ
dotnet build "D:\TFS\OAG Budget\OAGBudget.sln" 2>&1 | Select-Object -Last 20

# 5) checkin
tf checkin "D:\TFS\OAG Budget\OAGBudget\Services\Repository\BudgetService.cs" /noprompt /comment:"fix(budget): convert JObject to typed result before returning cancel check data"
```

**Commit message ที่แนะนำ:**

```
fix(budget): convert JObject to typed result in BudgetPaymentGf cancel check

MVC deserializes the API response with Newtonsoft so ApiResultsModel.Data
becomes a JObject, which System.Text.Json then serializes as empty arrays.
The cancel confirmation dialog therefore rendered empty rows for account
segment, amount to reclaim and available budget. Same fix already applied
to CheckCancelBudgetRequestOutside and CheckCancelBudgetRequisition.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

---

## 7. แผนทดสอบ (Test Cases)

> ⚠ ต้องต่อ **VPN F5 BIG-IP Edge Client** ก่อนทดสอบ เพราะขั้นตอนตรวจงบต้อง query Oracle PREPROD

| # | เงื่อนไข | ผลที่คาดหวังหลังแก้ |
|---|---|---|
| 1 | ใบสถานะ "บันทึกรับเงินจากคลังแล้ว" งบใน EBS **พอ** | popup ยืนยัน แสดง ชุดบัญชี / ยอดที่ต้องดึงคืน / งบคงเหลือ ครบทุกคอลัมน์ + badge เขียว "เพียงพอ" + ยอดรวมเป็นตัวเลข |
| 2 | งบใน EBS **ไม่พอ** อย่างน้อย 1 ชุดบัญชี | popup "ไม่สามารถทำรายการได้" + ตารางแสดงเฉพาะแถวที่ไม่ผ่าน พร้อมตัวเลขจริง |
| 3 | ใบมีหลายชุดบัญชี (หลาย segment) | แถวครบตามจำนวนชุดบัญชี ยอดรวมต่อชุดบัญชีถูกต้อง (รวม `ENTERED_DR` แล้ว) |
| 4 | ใบถูกใช้ต่อแล้ว (โอน / กันเงินเหลื่อมปี / เบิกจ่าย) | ขึ้นข้อความ blocked reason ตามด่าน 1 — ไม่มีตาราง (ปกติ เพราะ `Items` ว่าง) |
| 5 | ใบสถานะอื่นที่ยกเลิกไม่ได้ | ขึ้นข้อความสถานะไม่ถูกต้อง — ไม่มีตาราง |
| 6 | ทดสอบซ้ำบนหน้า **งบเพิ่มเติม/งบกลาง** (`BudgetPaymentGfMoreDetail`) | ผลเหมือนกันทุกเคส (ใช้ endpoint เดียวกัน) |
| 7 | กดยืนยันยกเลิกจริง → ตรวจ `OAGGL_JOURNAL_INTERFACE` | มีบรรทัด batch `REVERSE_BUDGET_WD_...` `REVERSE_FLAG='Y'` และสถานะใบเป็น D |

**วิธีตรวจเร็ว (ไม่ต้องรันแอป):** เปิด DevTools → Network → ดู response ของ `/Budget/CheckCancelBudgetPaymentGf`

- ผิด: `"items":[[[[]],[[]],...]]`
- ถูก: `"items":[{"accountSegment":"...","amount":...}]`

---

## 8. ความเสี่ยง / สิ่งที่ควรระวังต่อ (Blast Radius & Related Risk)

**Blast radius ของการแก้:** แคบมาก — เป็น method `private` ที่ถูกเรียกจาก 2 action ของหน้าเบิกเงินจากกรมบัญชีกลางเท่านั้น ไม่กระทบหน้าอื่น ไม่แตะ DB/EBS ถอยกลับได้ด้วยการ undo checkin เดียว

**ความเสี่ยงเชิงระบบที่ยังเหลืออยู่ (นอก scope งานนี้):**
ในไฟล์ [OAGBudget/Services/Repository/BudgetService.cs](OAGBudget/Services/Repository/BudgetService.cs) มี `JsonConvert.DeserializeObject<ApiResultsModel>(...)` รวม **62 จุด** แต่มีเพียง **7 จุด** ที่ทำ `ToObject<T>()` ต่อ
→ ทุกจุดที่ (ก) API ใส่ object ลง `Data` **และ** (ข) หน้าจออ่านค่าใน `Data` ต่อ จะเจอบั๊กนี้เหมือนกัน

**แนวทางป้องกันถาวร (เสนอเป็นงานแยก ไม่ทำในรอบนี้):**

1. ลง `Microsoft.AspNetCore.Mvc.NewtonsoftJson` แล้วเรียก `.AddNewtonsoftJson()` ฝั่ง MVC → `JObject` จะ serialize ถูกต้องเองทุกจุด (แต่กระทบ serialization ทั้งเว็บ = **R1** ต้องทำ regression ทั้งระบบ)
2. หรือเปลี่ยน endpoint ที่มี `Data` เป็น object ให้ใช้ `ApiResultsModel<TData>` (generic) แทน `ApiResultsModel` → Newtonsoft deserialize เป็น type จริงตั้งแต่แรก ไม่ต้องพึ่ง `ToObject<T>()` — ปลอดภัยกว่าและทยอยทำทีละหน้าได้
3. ระหว่างยังไม่ทำ 1/2 → ตั้งเป็นกฎ review: **ทุกครั้งที่ MVC ส่ง `Data` ที่เป็น object ต่อให้หน้าจอ ต้องมี `ToObject<T>()`**

---

## 9. อ้างอิงไฟล์ที่เกี่ยวข้อง

| เรื่อง | ไฟล์:บรรทัด |
|---|---|
| JS สร้างตารางใน popup | [BudgetPaymentGfDetail.cshtml:763](OAGBudget/Views/Budget/BudgetPaymentGfDetail.cshtml#L763) |
| JS flow ยกเลิก | [BudgetPaymentGfDetail.cshtml:800](OAGBudget/Views/Budget/BudgetPaymentGfDetail.cshtml#L800) |
| JS หน้างบเพิ่มเติม | [BudgetPaymentGfMoreDetail.cshtml:1136](OAGBudget/Views/Budget/BudgetPaymentGfMoreDetail.cshtml#L1136) |
| MVC Controller | [BudgetController.cs:3036](OAGBudget/Controllers/BudgetController.cs#L3036) |
| **MVC Service (จุดที่ต้องแก้)** | **[BudgetService.cs:5879](OAGBudget/Services/Repository/BudgetService.cs#L5879)** |
| ตัวอย่างที่แก้ถูกแล้ว #1 | [BudgetService.cs:3269](OAGBudget/Services/Repository/BudgetService.cs#L3269) |
| ตัวอย่างที่แก้ถูกแล้ว #2 | [BudgetService.cs:6966](OAGBudget/Services/Repository/BudgetService.cs#L6966) |
| API Controller | [BudgetController.cs:1267](OAGBudget.API/Controllers/BudgetController.cs#L1267) |
| API Service (ตรรกะตรวจงบ) | [BudgetService.cs:9522](OAGBudget.API/Services/Repository/BudgetService.cs#L9522) |
| Model ผลตรวจ | [BudgetPaymentGfDetailViewModel.cs:15-54](OAGBudget.Models/ViewModel/BudgetPaymentGfDetailViewModel.cs#L15-L54) |
| `ApiResultsModel.Data` เป็น `object?` | [ApiResultsModel.cs:11](OAGBudget.Models/Common/ApiResultsModel.cs#L11) |
| งานต้นทางของฟีเจอร์ | `_brain_OAGBUDGET/20260702_Cancel_Case/` |
