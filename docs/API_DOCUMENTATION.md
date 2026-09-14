# 📖 3-Admin Hostel & Mess Management REST API Documentation

Base URL: `http://localhost:5000/api/v1`

---

## 🛡️ 1. Admin & Authentication
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/admins/list` | Get profiles of the 3 admins (without PINs) |
| `POST` | `/admins/verify-pin` | Verify 4-digit PIN (`{ "pin": "1111" }`) |
| `POST` | `/admins/update-pin` | Update PIN (`{ "adminId", "currentPin", "newPin" }`) |
| `GET` | `/admins/audit-logs` | Get full activity history (Who did what) |

---

## 👥 2. Student Management
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/students` | List all students with query params (`?search=`, `?status=`, `?roomId=`) |
| `GET` | `/students/:id` | Student detail + payment history + in/out logs + WhatsApp reminder payload |
| `POST` | `/students` | Register new student (allocates room & bed) |
| `PUT` | `/students/:id` | Update profile, fee structure, notes |
| `POST` | `/students/:id/shift-bed`| Shift student to another room/bed |
| `POST` | `/students/:id/checkout` | Check out / archive student |

---

## 🛏️ 3. Rooms & Occupancy Grid
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/rooms` | Visual floor-by-floor room grid with occupants & vacancy counts |
| `POST` | `/rooms` | Add a new room (`{ "roomNumber", "floor", "totalBeds" }`) |

---

## 💳 4. Payments & Invoices
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/payments` | List fee payment records (`?month=2026-08`, `?studentId=`, `?feeType=`) |
| `POST` | `/payments` | Record fee payment, auto-extend plan expiry by 1 month, generate receipt & WhatsApp link |

---

## 🛒 5. Mess & Grocery Expenses
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/mess/expenses` | List daily kitchen expenses with category totals (`?month=2026-08`, `?category=`) |
| `POST` | `/mess/expenses` | Add daily grocery purchase (Vegetables, Milk, Gas, Ration, Spices) |
| `DELETE`| `/mess/expenses/:id` | Delete an expense entry |
| `GET` | `/mess/vendors` | List local vendors & pending credit/khata |
| `POST` | `/mess/vendors` | Add/update vendor contact & balance |

---

## 🚪 6. Leave / In-Out Register
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/leaves` | List departure/return logs (`?status=OUT` or `RETURNED`) |
| `POST` | `/leaves/departure` | Record student leaving hostel (Home Visit, Night Out) |
| `PUT` | `/leaves/:id/return` | Mark student checked back in |

---

## 📊 7. Dashboard & Expiry Alerts
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/stats/dashboard` | Main dashboard KPI cards (Students, Vacancy, Inflow, Outflow, Net Profit, Expiring Soon list) |
| `GET` | `/stats/dues-expiries` | Filtered lists for **Expiring Soon (1-5 Days)**, **Overdue**, and **Active** |
| `GET` | `/stats/cashbook` | Consolidated chronological Inflow vs Outflow statement |
