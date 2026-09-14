require('dotenv').config();
const express = require('express');
const cors = require('cors');

const { helmetMiddleware, apiLimiter, sanitizeInput } = require('./middleware/securityMiddleware');
const { verifyToken } = require('./middleware/authMiddleware');

const adminRoutes = require('./routes/adminRoutes');
const studentRoutes = require('./routes/studentRoutes');
const roomRoutes = require('./routes/roomRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const messRoutes = require('./routes/messRoutes');
const leaveRoutes = require('./routes/leaveRoutes');
const statsRoutes = require('./routes/statsRoutes');

const app = express();
const PORT = process.env.PORT || 5000;

// 1. Security Headers via Helmet
app.use(helmetMiddleware);

// 2. Secure CORS Configuration
const corsOptions = {
  origin: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept', 'x-org-id', 'X-Org-Id', 'x-org-code', 'X-Org-Code'],
  exposedHeaders: ['Authorization'],
  credentials: true,
  maxAge: 86400 // 24 hours preflight cache
};
app.use(cors(corsOptions));

// 3. Request Body Parsing & Sanitization
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(sanitizeInput);

// 4. Rate Limiting for all API routes
app.use('/api', apiLimiter);

// 5. Request Logging (Sanitized, no sensitive credentials)
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl}`);
  next();
});

// 6. Public Health Check & Status
app.get('/api/health', (req, res) => {
  res.json({
    status: 'online',
    secure: true,
    securityFeatures: ['Helmet', 'JWT-Bearer-Auth', 'Rate-Limiting', 'Input-Sanitization', 'XSS-Protection'],
    timestamp: new Date().toISOString(),
    service: 'Hostel & Mess 3-Admin Backend API'
  });
});

// 7. Mount Public / Auth Routes
app.use('/api/v1/admins', adminRoutes);

// 8. Mount Protected Routes (JWT Verification)
app.use('/api/v1/students', verifyToken, studentRoutes);
app.use('/api/v1/rooms', verifyToken, roomRoutes);
app.use('/api/v1/payments', verifyToken, paymentRoutes);
app.use('/api/v1/mess', verifyToken, messRoutes);
app.use('/api/v1/leaves', verifyToken, leaveRoutes);
app.use('/api/v1/stats', verifyToken, statsRoutes);

const path = require('path');
const fs = require('fs');

// 9. Direct Android APK Download Route
app.get('/download-apk', (req, res) => {
  const apkPath = path.join(__dirname, '../../Hostel_Mess_Admin_Pro.apk');
  if (fs.existsSync(apkPath)) {
    return res.download(apkPath, 'Hostel_Mess_Admin_Pro.apk');
  }
  const altApkPath = path.join(__dirname, '../../frontend/build/app/outputs/flutter-apk/app-release.apk');
  if (fs.existsSync(altApkPath)) {
    return res.download(altApkPath, 'Hostel_Mess_Admin_Pro.apk');
  }
  res.status(404).send('APK file not found on server.');
});

// 10. Serve Flutter Web Frontend (if built)
const frontendBuildPath = path.join(__dirname, '../../frontend/build/web');
if (fs.existsSync(frontendBuildPath)) {
  app.use(express.static(frontendBuildPath));
  app.get('*', (req, res, next) => {
    if (req.path.startsWith('/api') || req.path === '/download-apk') return next();
    res.sendFile(path.join(frontendBuildPath, 'index.html'));
  });
}

// 10. 404 Route Handler for API endpoints
app.use((req, res) => {
  res.status(404).json({ success: false, message: 'Resource not found' });
});

// 10. Centralized Secure Error Handler (No sensitive leaks)
app.use((err, req, res, next) => {
  console.error('[SECURITY ALERT] Server Error:', err);
  const isDev = process.env.NODE_ENV === 'development';
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal Server Error',
    ...(isDev && { errorStack: err.stack })
  });
});

// 11. Start Server
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`====================================================`);
  console.log(`🔒 3-Admin Hostel & Mess SECURE Backend Running!`);
  console.log(`📡 Local:    http://localhost:${PORT}`);
  console.log(`📡 Network:  http://0.0.0.0:${PORT}`);
  console.log(`🛡️  Security: Helmet | Rate-Limiter | JWT Bearer Auth`);
  console.log(`🔑 Admins:   3 Admin profiles loaded (PINs: 1111, 2222, 3333)`);
  console.log(`====================================================`);
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`\n❌ Port ${PORT} is already in use by another process.`);
    console.error(`👉 You can stop any existing node process or change PORT in .env\n`);
  } else {
    console.error('Server error:', err);
  }
});

// Crash prevention handlers
process.on('uncaughtException', (err) => {
  console.error('[UNCAUGHT EXCEPTION PREVENTED CRASH]:', err);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('[UNHANDLED REJECTION PREVENTED CRASH]:', reason);
});

module.exports = app;
