const fs = require('fs');
const path = require('path');

let admin = null;
let firestoreDb = null;
let supabase = null;

// 1. Supabase Cloud Database Client
try {
  const { createClient } = require('@supabase/supabase-js');
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY || process.env.SUPABASE_ANON_KEY;
  if (supabaseUrl && supabaseKey) {
    supabase = createClient(supabaseUrl, supabaseKey, {
      auth: { persistSession: false, autoRefreshToken: false }
    });
    console.log('⚡ Connected to Supabase Cloud Database:', supabaseUrl);
  }
} catch (e) {
  // Supabase not configured or package missing
}

// 2. Google Cloud Firestore Client
try {
  admin = require('firebase-admin');
  if (process.env.USE_FIRESTORE === 'true' || process.env.FUNCTION_TARGET || process.env.K_SERVICE || process.env.FIREBASE_CONFIG) {
    if (!admin.apps.length) {
      admin.initializeApp();
    }
    firestoreDb = admin.firestore();
    console.log('⚡ Connected to Google Cloud Firestore database.');
  }
} catch (e) {
  // Local mode without firebase-admin
}

const dataDir = path.join(__dirname, '../../data');
const dataFilePath = process.env.DATA_FILE 
  ? path.resolve(__dirname, '../../', process.env.DATA_FILE)
  : path.join(dataDir, 'db.json');

if (!fs.existsSync(dataDir)) {
  try { fs.mkdirSync(dataDir, { recursive: true }); } catch (_) {}
}

// Initial clean seed data structure for daily production use
const initialData = {
  organizations: [
    {
      id: 'org-default',
      name: 'My Hostel & Mess',
      code: 'HOSTEL',
      city: 'Main Campus',
      contactPhone: '',
      createdAt: '2026-01-01T00:00:00.000Z'
    }
  ],
  admins: [
    {
      id: 'admin-1',
      orgId: 'org-default',
      name: 'Chief Warden (Admin 1)',
      role: 'Chief Warden',
      phone: '9876543210',
      pin: '1111',
      createdAt: '2026-01-01T00:00:00.000Z'
    },
    {
      id: 'admin-2',
      orgId: 'org-default',
      name: 'Hostel In-charge (Admin 2)',
      role: 'Hostel In-charge',
      phone: '9876543211',
      pin: '2222',
      createdAt: '2026-01-01T00:00:00.000Z'
    },
    {
      id: 'admin-3',
      orgId: 'org-default',
      name: 'Mess In-charge (Admin 3)',
      role: 'Mess In-charge',
      phone: '9876543212',
      pin: '3333',
      createdAt: '2026-01-01T00:00:00.000Z'
    }
  ],
  rooms: [],
  students: [],
  payments: [],
  master_register: [],
  mess_expenses: [],
  vendors: [],
  leave_logs: [],
  audit_logs: [],
  notifications: []
};

class Database {
  constructor() {
    this.cache = JSON.parse(JSON.stringify(initialData));
    this.isInitialized = false;
    this.init();
  }

  async init() {
    try {
      // 1. Supabase Mode
      if (supabase) {
        const collections = Object.keys(initialData);
        for (const col of collections) {
          try {
            const { data, error } = await supabase
              .from('app_collections')
              .select('items')
              .eq('collection_name', col)
              .eq('org_id', 'org-default')
              .maybeSingle();

            if (data && data.items && Array.isArray(data.items)) {
              this.cache[col] = data.items;
            } else {
              this.cache[col] = initialData[col] || [];
              await supabase
                .from('app_collections')
                .upsert({
                  collection_name: col,
                  org_id: 'org-default',
                  items: this.cache[col],
                  updated_at: new Date().toISOString()
                });
            }
          } catch (colErr) {
            console.error(`Error loading Supabase collection ${col}:`, colErr.message);
          }
        }
        this.isInitialized = true;
        return;
      }

      // 2. Google Firestore Mode
      if (firestoreDb) {
        // Load collections from Firestore into memory cache
        const collections = Object.keys(initialData);
        for (const col of collections) {
          try {
            const docSnap = await firestoreDb.collection('app_data').doc(col).get();
            if (docSnap.exists && docSnap.data()?.items) {
              this.cache[col] = docSnap.data().items;
            } else {
              // Seed initial data for this collection in Firestore
              this.cache[col] = initialData[col] || [];
              await firestoreDb.collection('app_data').doc(col).set({ items: this.cache[col] });
            }
          } catch (colErr) {
            console.error(`Error loading Firestore collection ${col}:`, colErr.message);
          }
        }
        this.isInitialized = true;
        return;
      }

      // 3. Local JSON File Fallback
      if (!fs.existsSync(dataFilePath)) {
        this.save(initialData);
      } else {
        const raw = fs.readFileSync(dataFilePath, 'utf8');
        const data = JSON.parse(raw);
        let modified = false;

        for (const key of Object.keys(initialData)) {
          if (!data[key]) {
            data[key] = initialData[key];
            modified = true;
          }
        }

        if (!data.organizations || !Array.isArray(data.organizations) || data.organizations.length === 0) {
          data.organizations = initialData.organizations;
          modified = true;
        }

        this.cache = data;
        if (modified) {
          this.save(data);
        }
      }
      this.isInitialized = true;
    } catch (err) {
      console.error('Error during DB init, restoring initialData:', err);
      this.cache = JSON.parse(JSON.stringify(initialData));
      this.save(initialData);
    }
  }

  read() {
    if (supabase || firestoreDb) {
      return this.cache;
    }
    try {
      if (!fs.existsSync(dataFilePath)) {
        this.save(initialData);
      }
      const raw = fs.readFileSync(dataFilePath, 'utf8');
      this.cache = JSON.parse(raw);
      return this.cache;
    } catch (err) {
      console.error('Error reading database file:', err);
      return this.cache || initialData;
    }
  }

  save(data) {
    this.cache = data;
    if (supabase) {
      for (const [col, items] of Object.entries(data)) {
        supabase
          .from('app_collections')
          .upsert({
            collection_name: col,
            org_id: 'org-default',
            items,
            updated_at: new Date().toISOString()
          })
          .then(({ error }) => {
            if (error) console.error(`Supabase save error on ${col}:`, error.message);
          })
          .catch(e => {
            console.error(`Supabase save error on ${col}:`, e.message);
          });
      }
      return true;
    }

    if (firestoreDb) {
      // Asynchronously update all collections in Firestore
      for (const [col, items] of Object.entries(data)) {
        firestoreDb.collection('app_data').doc(col).set({ items }).catch(e => {
          console.error(`Firestore save error on ${col}:`, e.message);
        });
      }
      return true;
    }

    try {
      fs.writeFileSync(dataFilePath, JSON.stringify(data, null, 2), 'utf8');
      return true;
    } catch (err) {
      console.error('Error writing database file:', err);
      return false;
    }
  }

  getCollection(name) {
    const data = this.read();
    return data[name] || [];
  }

  saveCollection(name, items) {
    const data = this.read();
    data[name] = items;
    this.cache[name] = items;

    if (supabase) {
      supabase
        .from('app_collections')
        .upsert({
          collection_name: name,
          org_id: 'org-default',
          items,
          updated_at: new Date().toISOString()
        })
        .then(({ error }) => {
          if (error) console.error(`Supabase saveCollection error on ${name}:`, error.message);
        })
        .catch(e => {
          console.error(`Supabase saveCollection error on ${name}:`, e.message);
        });
      return true;
    }

    if (firestoreDb) {
      firestoreDb.collection('app_data').doc(name).set({ items }).catch(e => {
        console.error(`Firestore saveCollection error on ${name}:`, e.message);
      });
      return true;
    }

    return this.save(data);
  }

  // --- Multi-Tenant Organization Scoped Helpers ---
  getCollectionForOrg(name, orgId) {
    const targetOrgId = orgId || 'org-default';
    const allItems = this.getCollection(name);
    return allItems.filter(item => (item.orgId || 'org-default') === targetOrgId);
  }

  saveCollectionForOrg(name, orgId, orgItems) {
    const targetOrgId = orgId || 'org-default';
    const allItems = this.getCollection(name);
    const otherItems = allItems.filter(item => (item.orgId || 'org-default') !== targetOrgId);
    const stampedItems = orgItems.map(item => item.orgId ? item : { ...item, orgId: targetOrgId });
    return this.saveCollection(name, [...otherItems, ...stampedItems]);
  }

  // --- 📜 Permanent Master Register Helpers (Hostel & Mess Archive) ---
  upsertMasterRegister(item, orgId, extraInfo = {}) {
    const targetOrgId = orgId || item.orgId || 'org-default';
    const masterList = this.getCollection('master_register');
    
    const index = masterList.findIndex(m => 
      (m.originalId && item.id && m.originalId === item.id) ||
      (m.id && item.id && m.id === item.id) ||
      (m.phone && item.phone && m.phone === item.phone && (m.orgId || 'org-default') === targetOrgId)
    );

    const nowIso = new Date().toISOString();
    const isLeft = extraInfo.status === 'LEFT' || item.status === 'ARCHIVED' || extraInfo.status === 'ARCHIVED';

    if (index !== -1) {
      const existing = masterList[index];
      const updated = {
        ...existing,
        orgId: targetOrgId,
        name: item.name !== undefined ? item.name : existing.name,
        phone: item.phone !== undefined ? item.phone : existing.phone,
        parentName: item.parentName !== undefined ? item.parentName : existing.parentName,
        parentPhone: item.parentPhone !== undefined ? item.parentPhone : existing.parentPhone,
        photoUrl: item.photoUrl !== undefined ? item.photoUrl : existing.photoUrl,
        memberType: item.memberType !== undefined ? item.memberType : existing.memberType,
        enrolledInMess: item.enrolledInMess !== undefined ? item.enrolledInMess : existing.enrolledInMess,
        roomId: item.roomId !== undefined ? item.roomId : existing.roomId,
        roomNumber: item.roomNumber !== undefined ? item.roomNumber : existing.roomNumber,
        bedNo: item.bedNo !== undefined ? item.bedNo : existing.bedNo,
        monthlyMessFee: item.monthlyMessFee !== undefined ? parseFloat(item.monthlyMessFee) : existing.monthlyMessFee,
        totalRentAgreed: (item.totalRentAgreed !== undefined || item.rentAmountPerTerm !== undefined)
          ? parseFloat(item.totalRentAgreed || item.rentAmountPerTerm)
          : existing.totalRentAgreed,
        rentTermMonths: item.rentTermMonths !== undefined ? parseInt(item.rentTermMonths) : existing.rentTermMonths,
        notes: item.notes !== undefined ? item.notes : existing.notes,
        status: extraInfo.status || (isLeft ? 'LEFT' : existing.status || 'ACTIVE'),
        leftDate: extraInfo.leftDate !== undefined ? extraInfo.leftDate : (isLeft ? (existing.leftDate || nowIso) : existing.leftDate),
        exitReason: extraInfo.exitReason !== undefined ? extraInfo.exitReason : (existing.exitReason || item.checkoutReason || ''),
        updatedAt: nowIso
      };
      masterList[index] = updated;
      this.saveCollection('master_register', masterList);
      return updated;
    } else {
      const newEntry = {
        id: `master-${item.id || Date.now()}`,
        originalId: item.id || '',
        orgId: targetOrgId,
        name: item.name || '',
        phone: item.phone || '',
        parentName: item.parentName || '',
        parentPhone: item.parentPhone || '',
        photoUrl: item.photoUrl || '',
        memberType: item.memberType || (item.roomId ? 'HOSTEL_RESIDENT' : 'MESS_ONLY'),
        enrolledInMess: item.enrolledInMess !== false,
        roomId: item.roomId || null,
        roomNumber: item.roomNumber || (item.memberType === 'MESS_ONLY' ? 'External / Day Scholar' : ''),
        bedNo: item.bedNo || (item.memberType === 'MESS_ONLY' ? '-' : ''),
        admissionDate: item.admissionDate || (item.createdAt ? item.createdAt.split('T')[0] : nowIso.split('T')[0]),
        leftDate: extraInfo.leftDate || (isLeft ? nowIso : null),
        status: extraInfo.status || (isLeft ? 'LEFT' : 'ACTIVE'),
        exitReason: extraInfo.exitReason || item.checkoutReason || '',
        monthlyMessFee: parseFloat(item.monthlyMessFee) || 0,
        totalRentAgreed: parseFloat(item.totalRentAgreed || item.rentAmountPerTerm) || 0,
        rentTermMonths: parseInt(item.rentTermMonths) || 6,
        notes: item.notes || '',
        createdAt: item.createdAt || nowIso,
        updatedAt: nowIso
      };
      masterList.push(newEntry);
      this.saveCollection('master_register', masterList);
      return newEntry;
    }
  }

  getMasterRegisterForOrg(orgId, filters = {}) {
    const targetOrgId = orgId || 'org-default';
    const allRecords = this.getCollectionForOrg('master_register', targetOrgId);

    const totalLifetimeCount = allRecords.length;
    const activeCount = allRecords.filter(r => r.status === 'ACTIVE').length;
    const leftCount = allRecords.filter(r => r.status === 'LEFT').length;
    const hostelCount = allRecords.filter(r => r.memberType === 'HOSTEL_RESIDENT').length;
    const messCount = allRecords.filter(r => r.memberType === 'MESS_ONLY' || r.enrolledInMess).length;

    let filtered = [...allRecords];

    if (filters.status && filters.status.toUpperCase() !== 'ALL') {
      filtered = filtered.filter(r => (r.status || 'ACTIVE').toUpperCase() === filters.status.toUpperCase());
    }

    if (filters.type && filters.type.toUpperCase() !== 'ALL') {
      if (filters.type.toUpperCase() === 'HOSTEL_RESIDENT' || filters.type.toUpperCase() === 'HOSTEL_ONLY') {
        filtered = filtered.filter(r => r.memberType === 'HOSTEL_RESIDENT');
      } else if (filters.type.toUpperCase() === 'MESS_ONLY') {
        filtered = filtered.filter(r => r.memberType === 'MESS_ONLY');
      }
    }

    if (filters.search && filters.search.trim()) {
      const q = filters.search.trim().toLowerCase();
      filtered = filtered.filter(r =>
        (r.name && r.name.toLowerCase().includes(q)) ||
        (r.phone && r.phone.includes(q)) ||
        (r.parentPhone && r.parentPhone.includes(q)) ||
        (r.parentName && r.parentName.toLowerCase().includes(q)) ||
        (r.roomNumber && r.roomNumber.toLowerCase().includes(q)) ||
        (r.notes && r.notes.toLowerCase().includes(q))
      );
    }

    filtered.sort((a, b) => {
      const dateA = new Date(a.admissionDate || a.createdAt || 0);
      const dateB = new Date(b.admissionDate || b.createdAt || 0);
      return dateB - dateA;
    });

    return {
      stats: {
        totalLifetimeCount,
        activeCount,
        leftCount,
        hostelCount,
        messCount
      },
      records: filtered
    };
  }
}

module.exports = new Database();
