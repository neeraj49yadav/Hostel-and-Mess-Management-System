-- ==============================================================================
-- 🏨 HOSTEL & MESS MANAGEMENT SYSTEM - SUPABASE DATABASE SCHEMA
-- ==============================================================================
-- Run this complete script in Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ==============================================================================

-- 1. Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Organizations Table
CREATE TABLE IF NOT EXISTS organizations (
    id TEXT PRIMARY KEY DEFAULT ('org-' || uuid_generate_v4()),
    name TEXT NOT NULL,
    code TEXT DEFAULT 'HOSTEL',
    city TEXT DEFAULT 'Main Campus',
    contact_phone TEXT DEFAULT '',
    settings JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Admins Table (3 Distinct Roles: Chief Warden, Hostel In-charge, Mess In-charge)
CREATE TABLE IF NOT EXISTS admins (
    id TEXT PRIMARY KEY DEFAULT ('admin-' || uuid_generate_v4()),
    org_id TEXT REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    role TEXT NOT NULL,
    phone TEXT NOT NULL,
    pin TEXT NOT NULL,
    photo_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    permissions JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Rooms Table
CREATE TABLE IF NOT EXISTS rooms (
    id TEXT PRIMARY KEY DEFAULT ('room-' || uuid_generate_v4()),
    org_id TEXT REFERENCES organizations(id) ON DELETE CASCADE,
    room_number TEXT NOT NULL,
    floor INTEGER DEFAULT 1,
    capacity INTEGER NOT NULL DEFAULT 2,
    occupancy INTEGER NOT NULL DEFAULT 0,
    monthly_rent NUMERIC(10, 2) NOT NULL DEFAULT 0,
    room_type TEXT DEFAULT 'NON_AC',
    amenities JSONB DEFAULT '[]'::jsonb,
    status TEXT DEFAULT 'AVAILABLE',
    notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Students & Mess Members Table
CREATE TABLE IF NOT EXISTS students (
    id TEXT PRIMARY KEY DEFAULT ('stud-' || uuid_generate_v4()),
    org_id TEXT REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    email TEXT DEFAULT '',
    parent_name TEXT DEFAULT '',
    parent_phone TEXT DEFAULT '',
    address TEXT DEFAULT '',
    photo_url TEXT,
    member_type TEXT NOT NULL DEFAULT 'HOSTEL_RESIDENT',
    
    room_id TEXT REFERENCES rooms(id) ON DELETE SET NULL,
    room_number TEXT DEFAULT '',
    monthly_rent NUMERIC(10, 2) DEFAULT 0,
    deposit_amount NUMERIC(10, 2) DEFAULT 0,
    
    enrolled_in_mess BOOLEAN DEFAULT TRUE,
    mess_plan_type TEXT DEFAULT 'MONTHLY',
    monthly_mess_fee NUMERIC(10, 2) DEFAULT 0,
    mess_start_date DATE DEFAULT CURRENT_DATE,
    mess_expiry_date DATE,
    cycle_day INTEGER DEFAULT 1,
    
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    admission_date DATE DEFAULT CURRENT_DATE,
    checkout_date TIMESTAMPTZ,
    checkout_reason TEXT,
    notes TEXT DEFAULT '',
    raw_data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Payments & Dues Ledger Table
CREATE TABLE IF NOT EXISTS payments (
    id TEXT PRIMARY KEY DEFAULT ('pay-' || uuid_generate_v4()),
    org_id TEXT REFERENCES organizations(id) ON DELETE CASCADE,
    student_id TEXT REFERENCES students(id) ON DELETE SET NULL,
    student_name TEXT NOT NULL,
    room_number TEXT DEFAULT '',
    type TEXT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    payment_mode TEXT NOT NULL DEFAULT 'CASH',
    transaction_ref TEXT DEFAULT '',
    status TEXT NOT NULL DEFAULT 'PAID',
    billing_cycle TEXT,
    receipt_number TEXT,
    collected_by TEXT DEFAULT 'Admin',
    notes TEXT DEFAULT '',
    payment_date TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Master Register (Non-deletable Permanent Student & Member Archive)
CREATE TABLE IF NOT EXISTS master_register (
    id TEXT PRIMARY KEY,
    org_id TEXT REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    parent_name TEXT DEFAULT '',
    parent_phone TEXT DEFAULT '',
    member_type TEXT NOT NULL,
    room_number TEXT DEFAULT '',
    monthly_fee NUMERIC(10, 2) DEFAULT 0,
    admission_date TIMESTAMPTZ,
    left_date TIMESTAMPTZ,
    status TEXT DEFAULT 'ACTIVE',
    exit_reason TEXT DEFAULT '',
    details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Mess Daily Grocery & Operational Expenses Table
CREATE TABLE IF NOT EXISTS mess_expenses (
    id TEXT PRIMARY KEY DEFAULT ('exp-' || uuid_generate_v4()),
    org_id TEXT REFERENCES organizations(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    vendor_name TEXT DEFAULT '',
    vendor_phone TEXT DEFAULT '',
    payment_mode TEXT DEFAULT 'CASH',
    invoice_url TEXT,
    recorded_by TEXT DEFAULT 'Admin',
    notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Suppliers & Vendor Khata Table
CREATE TABLE IF NOT EXISTS vendors (
    id TEXT PRIMARY KEY DEFAULT ('vend-' || uuid_generate_v4()),
    org_id TEXT REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    category TEXT DEFAULT 'GROCERY',
    address TEXT DEFAULT '',
    total_billed NUMERIC(10, 2) DEFAULT 0,
    total_paid NUMERIC(10, 2) DEFAULT 0,
    current_balance NUMERIC(10, 2) DEFAULT 0,
    transactions JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Student Leave Register Table
CREATE TABLE IF NOT EXISTS leave_logs (
    id TEXT PRIMARY KEY DEFAULT ('leave-' || uuid_generate_v4()),
    org_id TEXT REFERENCES organizations(id) ON DELETE CASCADE,
    student_id TEXT REFERENCES students(id) ON DELETE CASCADE,
    student_name TEXT NOT NULL,
    room_number TEXT DEFAULT '',
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT NOT NULL,
    parent_informed BOOLEAN DEFAULT FALSE,
    approved_by TEXT DEFAULT 'Admin',
    status TEXT DEFAULT 'APPROVED',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. Security Audit Logs Table
CREATE TABLE IF NOT EXISTS audit_logs (
    id TEXT PRIMARY KEY DEFAULT ('audit-' || uuid_generate_v4()),
    org_id TEXT REFERENCES organizations(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    details TEXT NOT NULL,
    admin_name TEXT NOT NULL,
    admin_id TEXT,
    ip_address TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- 12. App Collections Table (High-Speed Cloud Sync & Cache)
CREATE TABLE IF NOT EXISTS app_collections (
    collection_name TEXT NOT NULL,
    org_id TEXT NOT NULL DEFAULT 'org-default',
    items JSONB NOT NULL DEFAULT '[]'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (collection_name, org_id)
);

-- ==============================================================================
-- 🌟 SEED DEFAULT DATA
-- ==============================================================================

-- 1. Insert Default Organization
INSERT INTO organizations (id, name, code, city)
VALUES ('org-default', 'Hostel and Mess Management System', 'HOSTEL', 'Main Campus')
ON CONFLICT (id) DO NOTHING;

-- 2. Insert Default 3 Admins (PINs: 1111, 2222, 3333)
INSERT INTO admins (id, org_id, name, role, phone, pin) VALUES
('admin-1', 'org-default', 'Chief Warden (Admin 1)', 'Chief Warden', '9876543210', '1111'),
('admin-2', 'org-default', 'Hostel In-charge (Admin 2)', 'Hostel In-charge', '9876543211', '2222'),
('admin-3', 'org-default', 'Mess In-charge (Admin 3)', 'Mess In-charge', '9876543212', '3333')
ON CONFLICT (id) DO NOTHING;

-- Disable Row Level Security or allow public service role access
ALTER TABLE organizations DISABLE ROW LEVEL SECURITY;
ALTER TABLE admins DISABLE ROW LEVEL SECURITY;
ALTER TABLE rooms DISABLE ROW LEVEL SECURITY;
ALTER TABLE students DISABLE ROW LEVEL SECURITY;
ALTER TABLE payments DISABLE ROW LEVEL SECURITY;
ALTER TABLE master_register DISABLE ROW LEVEL SECURITY;
ALTER TABLE mess_expenses DISABLE ROW LEVEL SECURITY;
ALTER TABLE vendors DISABLE ROW LEVEL SECURITY;
ALTER TABLE leave_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE app_collections DISABLE ROW LEVEL SECURITY;
