const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const bcrypt = require('bcryptjs');

dotenv.config();

const { pool, initDb } = require('./db');

// Route modules
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const courseRoutes = require('./routes/courses');
const batchRoutes = require('./routes/batches');
const mentorRoutes = require('./routes/mentor');
const projectRoutes = require('./routes/projects');
const notificationRoutes = require('./routes/notifications');
const supportRoutes = require('./routes/support');
const taskRoutes = require('./routes/tasks');
const uploadRoutes = require('./routes/uploads');

// dotenv already loaded above

const app = express();

// ── Global middleware ──────────────────────────────────────────────────────────

// CORS — mobile apps send no Origin header, so null-origin is always allowed.
// In production, set ALLOWED_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map((o) => o.trim())
  : null; // null → allow all origins (dev / LAN mode)

app.use(
  cors({
    origin: (origin, callback) => {
      // No Origin header → mobile app, Postman, curl — always allow
      if (!origin) return callback(null, true);
      // If no whitelist is configured, allow everything (dev / LAN mode)
      if (!allowedOrigins) return callback(null, true);
      // Whitelist check
      if (allowedOrigins.includes(origin)) return callback(null, true);
      callback(new Error(`CORS: origin '${origin}' is not in the allowed list`));
    },
    credentials: true,
  }),
);

app.use(express.json({ limit: '25mb' }));

// ── API routes ─────────────────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/courses', courseRoutes);
app.use('/api/batches', batchRoutes);
app.use('/api/mentor', mentorRoutes);
app.use('/api/projects', projectRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/support', supportRoutes);
app.use('/api', taskRoutes);
app.use('/api/uploads', uploadRoutes);
app.use('/api', uploadRoutes);
app.use('/api/admin', userRoutes);

// ── 404 catch-all ─────────────────────────────────────────────────────────────
app.use((_req, res) => {
  res.status(404).json({ message: 'Route not found' });
});

// ── Startup helpers ────────────────────────────────────────────────────────────

/**
 * Idempotently ensures a super-admin user exists using credentials
 * supplied entirely via environment variables (no hard-coded values).
 */
async function ensureSuperAdmin() {
  const rawEmail =
    process.env.SUPER_ADMIN_EMAIL || process.env.DEFAULT_ADMIN_EMAIL;
  const password =
    process.env.SUPER_ADMIN_PASSWORD || process.env.DEFAULT_ADMIN_PASSWORD;
  const name =
    process.env.SUPER_ADMIN_NAME || process.env.DEFAULT_ADMIN_NAME || 'Super Admin';
  const username = process.env.SUPER_ADMIN_USERNAME || 'admin.super';
  const adminNo  = process.env.SUPER_ADMIN_NO       || 'ADM-2024-X99';

  if (!rawEmail || !password) {
    console.log('[ADMIN] No admin email/password in env — skipping admin seeding');
    return;
  }

  const email = rawEmail.trim().toLowerCase();
  const hash  = await bcrypt.hash(password, 10);

  console.log('[ADMIN] Ensuring super-admin:', email);

  try {
    const result = await pool.query(
      `INSERT INTO users (name, email, password_hash, role, username, admin_no)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (email)
       DO UPDATE SET
         name          = EXCLUDED.name,
         password_hash = EXCLUDED.password_hash,
         role          = EXCLUDED.role,
         username      = EXCLUDED.username,
         admin_no      = EXCLUDED.admin_no
       RETURNING id, email, role`,
      [name, email, hash, 'admin', username, adminNo],
    );
    console.log('[ADMIN] ✓ Super-admin ready:', result.rows[0]);
  } catch (err) {
    console.error('[ADMIN] ✗ Failed to seed admin:', err.message);
    throw err;
  }
}

// ── Start server ───────────────────────────────────────────────────────────────
const port = process.env.PORT || 5000;

(async () => {
  try {
    console.log('🚀 Starting Jenovate LMS Backend...');

    // ── Safety guards ─────────────────────────────────────────────────────────
    if (!process.env.JWT_SECRET) {
      console.error('❌ FATAL: JWT_SECRET environment variable is not set.');
      console.error('   Set it in your .env file and restart the server.');
      process.exit(1);
    }
    console.log('[INIT] ✓ JWT_SECRET is configured');

    console.log('[INIT] Step 1: Initializing database schema...');
    await initDb();
    console.log('[INIT] ✓ Database ready');

    console.log('[INIT] Step 2: Seeding super-admin...');
    await ensureSuperAdmin();
    console.log('[INIT] ✓ Super-admin ensured');

    console.log('[INIT] Step 3: Starting HTTP server...');
    // Bind to 0.0.0.0 so the server is reachable from LAN devices (e.g. Android phone).
    app.listen(port, '0.0.0.0', () => {
      console.log(`[INIT] ✓ API server listening on port ${port} (0.0.0.0)`);
      console.log('✅ Backend ready!\n');
    });
  } catch (err) {
    console.error('❌ Failed to start server:', err.message);
    process.exit(1);
  }
})();
