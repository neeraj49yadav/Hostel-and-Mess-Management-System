const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

// Pass Cloud Functions environment flag to express backend
process.env.USE_FIRESTORE = 'true';

// Import Express Server
const app = require('../backend/src/server');

// Export Express Application as a Firebase HTTPS Cloud Function
exports.api = functions.https.onRequest(app);
