const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const db = require('../config/db');

const BUCKET_NAME = 'hostel-photos';
const LOCAL_UPLOADS_DIR = path.join(__dirname, '../../public/uploads');

let bucketEnsured = false;

// Ensure local uploads directory exists as fallback
if (!fs.existsSync(LOCAL_UPLOADS_DIR)) {
  try {
    fs.mkdirSync(LOCAL_UPLOADS_DIR, { recursive: true });
  } catch (_) {}
}

/**
 * Ensure the Supabase Storage public bucket exists
 */
async function ensureBucket(supabase) {
  if (bucketEnsured || !supabase) return;
  try {
    const { data: buckets, error } = await supabase.storage.listBuckets();
    if (!error && buckets) {
      const exists = buckets.some(b => b.name === BUCKET_NAME);
      if (!exists) {
        await supabase.storage.createBucket(BUCKET_NAME, {
          public: true,
          fileSizeLimit: 5 * 1024 * 1024 // 5MB limit
        });
        console.log(`⚡ Supabase Storage bucket "${BUCKET_NAME}" created successfully.`);
      }
      bucketEnsured = true;
    }
  } catch (err) {
    console.warn(`[Storage Warning] Could not ensure Supabase bucket "${BUCKET_NAME}":`, err.message);
  }
}

/**
 * Parses a Base64 string into a Buffer, MimeType, and File Extension
 */
function parseBase64(base64Str) {
  let mimeType = 'image/jpeg';
  let cleanBase64 = base64Str.trim();

  if (cleanBase64.startsWith('data:')) {
    const parts = cleanBase64.split(';base64,');
    if (parts.length === 2) {
      mimeType = parts[0].replace('data:', '');
      cleanBase64 = parts[1];
    }
  }

  // Strip all whitespaces and newlines
  cleanBase64 = cleanBase64.replace(/[\r\n\s]/g, '');

  let ext = 'jpg';
  if (mimeType.includes('png')) ext = 'png';
  else if (mimeType.includes('webp')) ext = 'webp';
  else if (mimeType.includes('pdf')) ext = 'pdf';

  const buffer = Buffer.from(cleanBase64, 'base64');
  return { buffer, mimeType, ext };
}

/**
 * Detects if a string is a Base64 image payload
 */
function isBase64Image(str) {
  if (!str || typeof str !== 'string') return false;
  const s = str.trim();
  if (s.startsWith('data:image/')) return true;
  if (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('/uploads/') || s.startsWith('blob:') || s.startsWith('file://')) {
    return false;
  }
  const cleaned = s.replace(/[\r\n\s]/g, '');
  if (cleaned.length > 80 && /^[A-Za-z0-9+/=]+$/.test(cleaned)) {
    return true;
  }
  return false;
}

/**
 * Uploads a buffer either to Supabase Storage or to local disk fallback
 */
async function uploadBuffer(buffer, mimeType, ext, subfolder = 'general', customName = null) {
  const supabase = db.getSupabaseClient();
  const safeSubfolder = subfolder.replace(/[^a-zA-Z0-9_-]/g, '');
  const filename = `${customName ? customName + '-' : ''}${Date.now()}-${uuidv4().substring(0, 8)}.${ext}`;
  const filePath = `${safeSubfolder}/${filename}`;

  // 1. Try Supabase Storage (Preferred)
  if (supabase) {
    try {
      await ensureBucket(supabase);
      const { data, error } = await supabase.storage.from(BUCKET_NAME).upload(filePath, buffer, {
        contentType: mimeType,
        upsert: true
      });

      if (!error) {
        const { data: publicData } = supabase.storage.from(BUCKET_NAME).getPublicUrl(filePath);
        if (publicData && publicData.publicUrl) {
          console.log(`☁️ [Supabase Storage] Uploaded: ${publicData.publicUrl}`);
          return publicData.publicUrl;
        }
      } else {
        console.warn('[Supabase Storage Upload Error]:', error.message);
      }
    } catch (sbErr) {
      console.warn('[Supabase Storage Upload Exception]:', sbErr.message);
    }
  }

  // 2. Local Disk Fallback
  try {
    const targetDir = path.join(LOCAL_UPLOADS_DIR, safeSubfolder);
    if (!fs.existsSync(targetDir)) {
      fs.mkdirSync(targetDir, { recursive: true });
    }
    const localFilePath = path.join(targetDir, filename);
    fs.writeFileSync(localFilePath, buffer);
    const localUrl = `/uploads/${safeSubfolder}/${filename}`;
    console.log(`💾 [Local Storage Fallback] Saved: ${localUrl}`);
    return localUrl;
  } catch (fsErr) {
    console.error('Failed to save file locally:', fsErr);
    return null;
  }
}

/**
 * Processes an incoming photo field.
 * If Base64, uploads to Supabase Storage and returns the public CDN URL.
 * If already an HTTP/HTTPS URL or local path, returns it untouched.
 */
async function processImage(imageInput, subfolder = 'students', customName = null) {
  if (!imageInput || typeof imageInput !== 'string') return imageInput || '';
  const trimmed = imageInput.trim();

  // If already an HTTP or local path, don't re-upload
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://') || trimmed.startsWith('/uploads/')) {
    return trimmed;
  }

  // If Base64 string detected
  if (isBase64Image(trimmed)) {
    try {
      const { buffer, mimeType, ext } = parseBase64(trimmed);
      const publicUrl = await uploadBuffer(buffer, mimeType, ext, subfolder, customName);
      return publicUrl || trimmed;
    } catch (err) {
      console.error('Error processing Base64 image:', err);
      return trimmed;
    }
  }

  return trimmed;
}

module.exports = {
  processImage,
  uploadBuffer,
  isBase64Image,
  parseBase64,
  BUCKET_NAME
};
