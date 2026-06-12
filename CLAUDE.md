# CLAUDE.md

## Version Control (Hybrid)

โปรเจกต์นี้ใช้ **2 systems** แยกตามโฟลเดอร์:

### 📦 TFS (Team Foundation Server) — Source Code

- **Path**: `D:\TFS\OAG Budget\*` (ยกเว้น `_brain_OAGBUDGET`)
- **Content**: C# source code, configuration, views, etc.
- **Commands**: `tf edit`, `tf add`, `tf checkin`
- ไม่มี `.git` directory ใน workspace
- Working directory: `.` (root of project)

### 📚 Git — Documentation & Data

- **Path**: `D:\TFS\OAG Budget\_brain_OAGBUDGET`
- **Content**: Project analysis, roadmaps, research notes, test data
- **Commands**: Standard git (`git add`, `git commit`, `git push`)
- Separate Git repository (or submodule)
- ใช้ Conventional Commits format เดียวกัน

### 📝 Commit Workflow

| สิ่งที่แก้ | System | Command |
|---|---|---|
| Source code (.cs, .cshtml, config) | TFS | `tf checkin` |
| Documentation, roadmap, notes | Git | `git commit` |
| Phase/project planning files | Git | `git commit` |

### ⚠️ TFS Checkin Rules (STRICT)

**BEFORE EVERY CHECKIN:**

1. **Always `tf get` (get latest) first**
   ```
   tf get D:\TFS\OAG Budget
   ```
   - รับ latest version ของไฟล์ทั้งหมดจาก server
   - ต้องทำก่อน checkin เสมอ ไม่มีข้อยกเว้น

2. **If conflict → ABORT checkin**
   - ถ้า `tf get` มี conflict: ให้ resolve ก่อน หรือ abort
   - ไม่ให้ checkin ถ้ายังมี conflict
   - นี่คือ **strict rule** — จะต้องปฏิบัติเสมอ

**Checkin Order:**
```
1. tf get (update from server)
2. [Resolve any conflicts if needed]
3. tf checkin (only if no conflicts)
```

## Commit Messages

Use **Conventional Commits** format:

```
<type>(<scope>): <short description>

[optional body]

[optional footer]
```

### Types

| Type | ใช้เมื่อ |
|------|----------|
| `feat` | เพิ่ม feature ใหม่ |
| `fix` | แก้ bug |
| `refactor` | ปรับโค้ดโดยไม่เปลี่ยน behavior |
| `perf` | ปรับปรุง performance |
| `style` | แก้ formatting, whitespace (ไม่เปลี่ยน logic) |
| `docs` | แก้เอกสาร |
| `test` | เพิ่ม/แก้ test |
| `chore` | งาน maintenance เช่น config, dependencies |

### Scope (optional)

ใส่ชื่อ module หรือ feature ที่เกี่ยวข้อง เช่น `report`, `budget`, `auth`

### Examples

```
feat(report): add E-Budgeting and sub-account columns to budget request overview Excel report

fix(budget): correct join key from Code to CategoryId for EBUDGETING lookup

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

```
refactor(service): extract subaccount query into shared helper

Extract common budget query logic into reusable helper method
to reduce duplication across BudgetAllocateTransfer* features.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

### Rules

- Subject line ไม่เกิน 72 ตัวอักษร
- ใช้ **imperative mood** — "add" ไม่ใช่ "added" หรือ "adds"
- ไม่ต้องจบด้วยจุด (.)
- Body อธิบาย **why** ไม่ใช่ **what**
- **REQUIRED**: Include footer `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>` เสมอ (ทั้ง TFS และ Git)
