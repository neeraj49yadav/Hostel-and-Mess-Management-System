# 🏢 3-Admin Hostel & Mess Management System

A production-ready management platform designed specifically for **3 Admins** to collaboratively manage rooms, student residents, fixed monthly mess subscriptions, kitchen grocery cashbook, real-time multi-device sync, and automated dues/expiry tracking.

The project features a **cleanly separated Frontend and Backend** architecture.

---

## 🏗️ Project Architecture

```
Hostel/
├── backend/                       # REST API Server (Node.js / Express)
│   ├── src/
│   │   ├── config/                # Database engine & seed data
│   │   ├── controllers/           # Business logic handlers
│   │   ├── routes/                # Clean API endpoints (/api/v1/...)
│   │   ├── services/              # Expiry engine, WhatsApp builder, audit logs
│   │   └── server.js              # Server entry point
│   ├── data/                      # Local JSON/SQLite storage for zero-hassle instant setup
│   └── package.json
│
├── frontend/                      # Flutter Android Application
│   ├── lib/
│   │   ├── core/                  # Theme, colors, formatters, WhatsApp launcher
│   │   ├── models/                # Typed models (Student, Room, Payment, Expense, Admin)
│   │   ├── services/              # REST API Service & PDF Receipt Generator
│   │   ├── providers/             # State management (Auth, Hostel, Mess, Finance)
│   │   ├── screens/               # Modular UI screens (Dashboard, Expiry Hub, Room Grid...)
│   │   └── main.dart
│   └── pubspec.yaml
│
└── docs/                          # API documentation, setup instructions & schemas
    └── API_DOCUMENTATION.md
```

---

## ⚡ Quick Start

### 1. Launch Backend Server
```bash
cd backend
npm install
npm start
```
* Backend starts at `http://localhost:5000`
* Default Admin PINs: **1111**, **2222**, **3333**

### 2. Launch Frontend Android App
```bash
cd frontend
flutter pub get
flutter run
```

---

## 🎯 Key Capabilities
* **Option A Monthly Billing**: Fixed monthly mess fee per student with custom billing cycles (no attendance tracking or rebate).
* **Automated Expiry Alerts**: Real-time identification of students whose plans expire in **1 to 5 days** or are **overdue**.
* **1-Tap WhatsApp Reminders**: Direct WhatsApp launch with pre-formatted reminder texts and receipt links.
* **Visual Room Matrix**: Real-time room and bed allocation grid showing vacant vs occupied beds.
* **Mess Grocery Cashbook**: Daily kitchen expenditure tracker categorized by Milk, Vegetables, Ration, Gas, Spices.
* **PDF Receipt Generator**: Instant generation of shareable/printable fee receipts with authorization seals.
* **Multi-Admin Audit Log**: Complete history of transactions and bed reallocations.
