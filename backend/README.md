# 🚀 3-Admin Hostel & Mess Management REST API Backend

A dedicated Node.js/Express backend server designed specifically for a 3-Admin hostel & mess operation.

---

## 🛠️ Tech Stack & Features
* **Runtime**: Node.js & Express
* **Database**: Zero-configuration JSON file database with auto-seeding (`data/db.json`)
* **Real-time Synchronization**: REST API syncing all 3 admin devices instantly
* **Plan Expiry Engine**: Auto-computes **1–5 Days Upcoming Expiries**, overdue dues, and generates 1-tap WhatsApp reminder links
* **Financial Cashbook**: Inflows (Hostel Rent + Fixed Mess Fees) vs Outflows (Daily Groceries, Milk, Gas, Vegetables)
* **Multi-Admin Audit Log**: Logs who collected fee, shifted beds, or recorded kitchen expenses

---

## 🚀 Quick Start

### 1. Install Dependencies
```bash
cd backend
npm install
```

### 2. Start the Server
```bash
npm start
# or development mode with auto-reload:
npm run dev
```

The server will start at:
* **Local**: `http://localhost:5000`
* **Network**: `http://0.0.0.0:5000`
* **Health Check**: `http://localhost:5000/api/health`

---

## 🛡️ Default 3 Admin Profiles & PINs
| Admin | Role | Phone | PIN |
| :--- | :--- | :--- | :--- |
| **Warden 1** | Chief Warden | `9876543210` | `1111` |
| **Warden 2** | Hostel In-charge | `9876543211` | `2222` |
| **Warden 3** | Mess In-charge | `9876543212` | `3333` |

---

## 📖 API Documentation
Full API documentation with all parameters and response formats is available in [`../docs/API_DOCUMENTATION.md`](../docs/API_DOCUMENTATION.md).
