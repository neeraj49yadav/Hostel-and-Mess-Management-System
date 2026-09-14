# 📱 3-Admin Hostel & Mess Management Flutter Application

A modern, responsive Android application built for 3 admins to manage hostel rooms, resident profiles, fixed monthly mess subscriptions, kitchen grocery expenses, PDF receipts, and automated 1-tap WhatsApp reminders.

---

## ✨ Features Included

1. **🔒 4-Digit Security PIN Screen**: Quick PIN keypad for the 3 admins (`1111`, `2222`, `3333`).
2. **🔔 Dues & Plan Expiry Hub**:
   * Lists students expiring in the next **1–5 days**.
   * Lists overdue / expired accounts with outstanding balances.
   * **1-Tap WhatsApp Reminder button** launching WhatsApp with formatted payment notices.
3. **🏨 Hostel & Room Management**:
   * Searchable student directory with room/bed badges.
   * **Visual Floor-by-Floor Room Matrix** with occupied vs. vacant bed counters.
   * **1-Tap Bed Shift Modal** to move residents easily.
   * **Digital In/Out Leave Register** to track departures and returns.
4. **🍽️ Mess & Grocery Cashbook**:
   * Category-wise daily kitchen purchases (🥛 Milk, 🥬 Vegetables, 🌾 Ration, 🔥 Gas Cylinder, 🧂 Spices).
   * Supplier / Vendor directory with credit & pending khata tracking.
5. **💰 Financial Management & PDF Receipts**:
   * Unified Inflow vs Outflow Cashbook with net balance.
   * Fee collection form extending subscription dates automatically.
   * **Printable / Shareable PDF Fee Receipts** with authorization seals.

---

## 🚀 How to Run the App

### 1. Install Dependencies
```bash
cd frontend
flutter pub get
```

### 2. Run on Android Device / Emulator
Make sure the backend server is running (`cd ../backend && npm start`).
```bash
flutter run
```

### 3. Run on Chrome / Web (For quick preview)
```bash
flutter run -d chrome
```

---

## 📁 Directory Structure
```
frontend/lib/
├── core/                  # Theme, colors, formatters, WhatsApp launcher
├── models/                # Typed models (Student, Room, Payment, Expense, Admin)
├── providers/             # State management (Auth, Dashboard, Hostel, Mess)
├── services/              # REST API Service & PDF Receipt Generator
├── screens/
│   ├── auth/              # 4-Digit Admin PIN Unlock
│   ├── dashboard/         # KPIs, Alerts Carousel, Quick Actions
│   ├── dues_expiry/       # Expiry (1-5 Days) & Overdue Hub + WhatsApp
│   ├── hostel/            # Student Directory, Visual Room Matrix, Leave Register
│   ├── mess/              # Grocery Cashbook, Add Expense, Vendor Khata
│   └── finance/           # Combined Cashbook & PDF Receipts
└── main.dart              # MultiProvider & App Entry
```
