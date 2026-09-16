const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

let admin = null;
let firestoreDb = null;
let supabase = null;

// 1. Supabase Cloud Database Client Initializer
function initSupabaseClient() {
  if (supabase) return supabase;
  try {
    let supabaseUrl = process.env.SUPABASE_URL;
    if (supabaseUrl) {
      supabaseUrl = supabaseUrl.replace(/\/rest\/v1\/?$/, '').replace(/\/+$/, '');
    }
    const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY || process.env.SUPABASE_ANON_KEY;
    if (supabaseUrl && supabaseKey) {
      supabase = createClient(supabaseUrl, supabaseKey, {
        auth: { persistSession: false, autoRefreshToken: false }
      });
      console.log('⚡ Connected to Supabase Cloud Database:', supabaseUrl);
    }
  } catch (e) {
    console.warn('Supabase initialization warning:', e.message);
  }
  return supabase;
}

initSupabaseClient();

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

const CLOUD_STORAGE_BUCKET = 'hostel-photos';
const CLOUD_STORAGE_FILE = 'system/cloud_db.json';

// Initial clean seed data structure for daily production use
const initialData = {
  organizations: [],
  admins: [],
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
    this._cloudSyncTimeout = null;
    this.init();
  }

  async init() {
    try {
      // 1. Always read existing local db.json first
      let hasLocalRecords = false;
      if (fs.existsSync(dataFilePath)) {
        try {
          const raw = fs.readFileSync(dataFilePath, 'utf8');
          const localData = JSON.parse(raw);
          if (localData && typeof localData === 'object') {
            for (const key of Object.keys(initialData)) {
              if (Array.isArray(localData[key])) {
                this.cache[key] = localData[key];
                if (localData[key].length > 0) hasLocalRecords = true;
              }
            }
          }
        } catch (readErr) {
          console.error('Error reading local data file on init:', readErr);
        }
      }

      // 2. ⚡ Autonomous Supabase Storage Cloud Persistence (Survives Render spin-downs & reboots!)
      if (supabase) {
        try {
          console.log('🔄 Checking Supabase Cloud Storage for persistent snapshot...');
          const { data: cloudBlob, error: cloudErr } = await supabase.storage
            .from(CLOUD_STORAGE_BUCKET)
            .download(CLOUD_STORAGE_FILE);

          if (!cloudErr && cloudBlob) {
            const cloudText = await cloudBlob.text();
            const cloudData = JSON.parse(cloudText);
            if (cloudData && typeof cloudData === 'object') {
              console.log('⚡ Successfully restored database snapshot from Supabase Cloud Storage!');
              for (const key of Object.keys(initialData)) {
                const cloudItems = Array.isArray(cloudData[key]) ? cloudData[key] : [];
                const localItems = Array.isArray(this.cache[key]) ? this.cache[key] : [];

                if (cloudItems.length > 0 && localItems.length === 0) {
                  this.cache[key] = cloudItems;
                } else if (cloudItems.length > 0 && localItems.length > 0) {
                  // Merge items by id
                  const itemMap = new Map();
                  localItems.forEach(item => item && item.id && itemMap.set(item.id, item));
                  cloudItems.forEach(item => item && item.id && itemMap.set(item.id, item));
                  this.cache[key] = Array.from(itemMap.values());
                }
              }

              // Persist consolidated cloud state to local disk
              try {
                fs.writeFileSync(dataFilePath, JSON.stringify(this.cache, null, 2), 'utf8');
              } catch (_) {}
            }
          } else {
            console.log('ℹ️ No cloud snapshot found yet in Supabase Storage. Will upload on first write.');
            if (hasLocalRecords) {
              this.syncToCloudStorage();
            }
          }
        } catch (storageErr) {
          console.warn('⚠️ Supabase Storage cloud restore warning:', storageErr.message);
        }

        // 3. Optional Supabase Cloud Table Sync (if table permissions are available)
        const collections = Object.keys(initialData);
        for (const col of collections) {
          try {
            const { data, error } = await supabase
              .from('app_collections')
              .select('items')
              .eq('collection_name', col)
              .eq('org_id', 'org-default')
              .maybeSingle();

            if (!error && data && data.items && Array.isArray(data.items)) {
              if (col === 'organizations') {
                const localOrgs = Array.isArray(this.cache.organizations) ? this.cache.organizations : [];
                const remoteOrgs = data.items;
                const orgMap = new Map();
                localOrgs.forEach(o => o && o.id && orgMap.set(o.id, o));
                remoteOrgs.forEach(o => o && o.id && orgMap.set(o.id, o));
                this.cache.organizations = Array.from(orgMap.values());
              } else if (col === 'admins') {
                const localAdmins = Array.isArray(this.cache.admins) ? this.cache.admins : [];
                const remoteAdmins = data.items;
                const adminMap = new Map();
                localAdmins.forEach(a => a && a.id && adminMap.set(a.id, a));
                remoteAdmins.forEach(a => a && a.id && adminMap.set(a.id, a));
                this.cache.admins = Array.from(adminMap.values());
              } else {
                if (data.items.length > 0 && (!this.cache[col] || this.cache[col].length === 0)) {
                  this.cache[col] = data.items;
                }
              }
            } else if (!error) {
              await supabase
                .from('app_collections')
                .upsert({
                  collection_name: col,
                  org_id: 'org-default',
                  items: this.cache[col] || [],
                  updated_at: new Date().toISOString()
                });
            }
          } catch (colErr) {
            // Silently ignore table permission warnings as storage persistence handles it
          }
        }

        // Cap audit logs on startup
        if (this.cache.audit_logs && this.cache.audit_logs.length > 2000) {
          this.cache.audit_logs = this.cache.audit_logs.slice(-2000);
        }

        // Persist consolidated state to local disk
        try {
          fs.writeFileSync(dataFilePath, JSON.stringify(this.cache, null, 2), 'utf8');
        } catch (_) {}

        this.isInitialized = true;
        return;
      }

      // 4. Fallback without Supabase
      if (!fs.existsSync(dataFilePath)) {
        this.save(initialData);
      } else {
        if (this.cache.audit_logs && this.cache.audit_logs.length > 2000) {
          this.cache.audit_logs = this.cache.audit_logs.slice(-2000);
        }
        this.save(this.cache);
      }
      this.isInitialized = true;
    } catch (err) {
      console.error('Error during DB init:', err);
      this.isInitialized = true;
    }
  }

  read() {
    return this.cache;
  }

  syncToCloudStorage(immediate = false) {
    if (!supabase) return;
    if (this._cloudSyncTimeout) {
      clearTimeout(this._cloudSyncTimeout);
      this._cloudSyncTimeout = null;
    }

    const performUpload = () => {
      try {
        const payload = Buffer.from(JSON.stringify(this.cache, null, 2), 'utf8');
        supabase.storage
          .from(CLOUD_STORAGE_BUCKET)
          .upload(CLOUD_STORAGE_FILE, payload, {
            upsert: true,
            contentType: 'application/json'
          })
          .then(({ error }) => {
            if (error) {
              console.warn('⚠️ Supabase Storage cloud sync warning:', error.message);
            }
          })
          .catch(e => {
            console.warn('⚠️ Supabase Storage cloud sync error:', e.message);
          });
      } catch (err) {
        console.warn('⚠️ Exception in performUpload:', err.message);
      }
    };

    if (immediate) {
      performUpload();
    } else {
      this._cloudSyncTimeout = setTimeout(performUpload, 300);
    }
  }

  save(data) {
    this.cache = data;

    // 1. ALWAYS write to local disk synchronously first
    try {
      fs.writeFileSync(dataFilePath, JSON.stringify(data, null, 2), 'utf8');
    } catch (err) {
      console.error('Error writing database file:', err);
    }

    // 2. ⚡ Persist full snapshot to Supabase Cloud Storage (Guaranteed survival across Render restarts)
    this.syncToCloudStorage();

    // 2. Sync to Supabase
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
    }

    // 3. Sync to Firestore if enabled
    if (firestoreDb) {
      for (const [col, items] of Object.entries(data)) {
        firestoreDb.collection('app_data').doc(col).set({ items }).catch(e => {
          console.error(`Firestore save error on ${col}:`, e.message);
        });
      }
    }

    return true;
  }

  getCollection(name) {
    const data = this.read();
    return data[name] || [];
  }

  saveCollection(name, items) {
    this.cache[name] = items;

    // 1. ALWAYS write to local disk synchronously first
    try {
      fs.writeFileSync(dataFilePath, JSON.stringify(this.cache, null, 2), 'utf8');
    } catch (err) {
      console.error('Error writing database file:', err);
    }

    // 2. ⚡ Persist full snapshot to Supabase Cloud Storage (Survives Render restarts)
    this.syncToCloudStorage();

    // 3. Sync to Supabase
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
    }

    // 4. Sync to Firestore if enabled
    if (firestoreDb) {
      firestoreDb.collection('app_data').doc(name).set({ items }).catch(e => {
        console.error(`Firestore saveCollection error on ${name}:`, e.message);
      });
    }

    return true;
  }

  clearEntireDatabase() {
    console.log('🧹 Clearing entire database to fresh slate...');
    const freshData = JSON.parse(JSON.stringify(initialData));
    this.cache = freshData;
    this.save(freshData);
    this.syncToCloudStorage(true);
    console.log('✅ Database completely cleared and reset to fresh state.');
    return true;
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

  // Supabase Client Getter for services & keep-alive ping
  getSupabaseClient() {
    return initSupabaseClient();
  }
}

module.exports = new Database();
