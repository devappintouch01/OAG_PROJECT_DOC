# CLAUDE.md

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

refactor(service): extract subaccount query into shared helper
```

### Rules

- Subject line ไม่เกิน 72 ตัวอักษร
- ใช้ **imperative mood** — "add" ไม่ใช่ "added" หรือ "adds"
- ไม่ต้องจบด้วยจุด (.)
- Body อธิบาย **why** ไม่ใช่ **what**
