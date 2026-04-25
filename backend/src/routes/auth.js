const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { rateLimit } = require('../middleware/security');
const { pool } = require('../db');

const router = express.Router();

/**
 * POST /api/auth/login
 *
 * Public endpoint — no JWT required.
 * Verifies credentials and returns a signed JWT + user profile.
 *
 * Response: { token, id, name, email, role, username, admin_no }
 */
router.post('/login', rateLimit(10, 60000), async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    console.log('[LOGIN] ✗ Missing email or password');
    return res.status(400).json({ message: 'Email and password are required' });
  }

  try {
    const normalizedEmail = email.trim().toLowerCase();
    console.log('[LOGIN] Attempting login for:', normalizedEmail);

    const result = await pool.query(
      `
      SELECT
        u.*,
        COALESCE(ucm.course_ids, ARRAY[]::uuid[]) AS course_ids,
        COALESCE(u.batch_id, ub.batch_id) AS resolved_batch_id
      FROM users u
      LEFT JOIN LATERAL (
        SELECT ARRAY_AGG(uc.course_id ORDER BY uc.created_at DESC) AS course_ids
        FROM user_courses uc
        WHERE uc.user_id = u.id
      ) ucm ON TRUE
      LEFT JOIN LATERAL (
        SELECT b.id AS batch_id
        FROM user_courses uc
        JOIN batches b ON b.course_id = uc.course_id
        WHERE uc.user_id = u.id
        ORDER BY uc.created_at DESC
        LIMIT 1
      ) ub ON TRUE
      WHERE u.email = $1
      LIMIT 1
      `,
      [normalizedEmail],
    );

    if (result.rows.length === 0) {
      console.log('[LOGIN] ✗ User not found:', normalizedEmail);
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    const user = result.rows[0];
    console.log('[LOGIN] ✓ User found:', { id: user.id, email: user.email, role: user.role });

    if (!user.password_hash) {
      console.log('[LOGIN] ✗ No password_hash for:', normalizedEmail);
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    const match = await bcrypt.compare(password, user.password_hash);
    if (!match) {
      console.log('[LOGIN] ✗ Wrong password for:', normalizedEmail);
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    // Sign a JWT containing just enough info for middleware to verify identity
    // without hitting the database on every request.
    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' },
    );

    console.log('[LOGIN] ✓ Login successful, token issued for:', normalizedEmail);
    
    // Process streak and rewards on login
    const { processLogin } = require('../services/streak_service');
    const streakInfo = await processLogin(user.id, {
      source: 'api_login',
      client: req.headers['user-agent'] || 'api',
    });

    return res.json({
      token,
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      username: user.username,
      admin_no: user.admin_no,
      batch_id: user.resolved_batch_id,
      course_ids: user.course_ids || [],
      coins: streakInfo.coins,
      streak_count: streakInfo.streak_count,
      weekly_logins: streakInfo.weekly_logins,
      last_active_date: streakInfo.last_active_date,
    });
  } catch (err) {
    console.error('[LOGIN] ✗ Server error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * POST /api/auth/forgot-password
 *
 * Public endpoint — no JWT required.
 * Accepts { email }. Generates a reset token, stores it, and sends an email
 * (or logs the link if SMTP is not configured).
 * Always returns 200 to avoid leaking whether the email exists.
 */
router.post('/forgot-password', rateLimit(5, 60000), async (req, res) => {
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ message: 'Email is required' });
  }

  try {
    const normalizedEmail = email.trim().toLowerCase();
    console.log('[FORGOT-PW] Request for:', normalizedEmail);

    // Look up user
    const userResult = await pool.query(
      `SELECT id, name, email FROM users WHERE email = $1 LIMIT 1`,
      [normalizedEmail],
    );

    if (userResult.rows.length === 0) {
      console.log('[FORGOT-PW] User not found (responding 200 anyway):', normalizedEmail);
      // Always return success to avoid email enumeration
      return res.json({ message: 'If that email is registered, a reset link has been sent.' });
    }

    const user = userResult.rows[0];

    // Invalidate any existing unused tokens for this user
    await pool.query(
      `UPDATE password_reset_tokens SET used = TRUE WHERE user_id = $1 AND used = FALSE`,
      [user.id],
    );

    // Generate secure token
    const crypto = require('crypto');
    const token = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

    await pool.query(
      `INSERT INTO password_reset_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)`,
      [user.id, token, expiresAt.toISOString()],
    );

    // Build reset URL
    const baseUrl = process.env.APP_BASE_URL || process.env.LMS_BASE_URL || `http://localhost:${process.env.PORT || 5000}`;
    const resetUrl = `${baseUrl}/api/auth/reset-password?token=${token}`;

    // Try to send email; fall back to console log
    try {
      const { isEmailServiceConfigured, sendPasswordResetEmail } = require('../services/email_service');
      if (isEmailServiceConfigured()) {
        await sendPasswordResetEmail({ email: user.email, userName: user.name, resetUrl });
        console.log('[FORGOT-PW] ✓ Reset email sent to:', normalizedEmail);
      } else {
        console.log('[FORGOT-PW] ⚠ SMTP not configured. Reset link:');
        console.log(`   ${resetUrl}`);
      }
    } catch (emailErr) {
      console.error('[FORGOT-PW] ⚠ Email send failed:', emailErr.message);
      console.log('[FORGOT-PW] Reset link (fallback):');
      console.log(`   ${resetUrl}`);
    }

    return res.json({ message: 'If that email is registered, a reset link has been sent.' });
  } catch (err) {
    console.error('[FORGOT-PW] ✗ Server error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * GET /api/auth/reset-password?token=XYZ
 *
 * Serves a self-contained HTML page with a password reset form.
 */
router.get('/reset-password', async (req, res) => {
  const { token } = req.query;

  if (!token) {
    return res.status(400).send('<h2>Missing reset token.</h2>');
  }

  // Validate token exists and is not expired/used
  try {
    const result = await pool.query(
      `SELECT id, expires_at, used FROM password_reset_tokens WHERE token = $1 LIMIT 1`,
      [token],
    );

    if (result.rows.length === 0 || result.rows[0].used) {
      return res.send(resetPageHtml({ error: 'This reset link is invalid or has already been used.' }));
    }

    if (new Date(result.rows[0].expires_at) < new Date()) {
      return res.send(resetPageHtml({ error: 'This reset link has expired. Please request a new one.' }));
    }
  } catch (err) {
    console.error('[RESET-PW] Token validation error:', err.message);
    return res.send(resetPageHtml({ error: 'Something went wrong. Please try again.' }));
  }

  return res.send(resetPageHtml({ token }));
});

/**
 * POST /api/auth/reset-password
 *
 * Accepts { token, password } (JSON or form-urlencoded).
 * Validates token, hashes new password, updates user.
 */
router.post('/reset-password', async (req, res) => {
  // Support both JSON and URL-encoded form data
  const token = req.body?.token;
  const password = req.body?.password;
  const confirmPassword = req.body?.confirmPassword;

  if (!token || !password) {
    // If it's a browser form submission, send HTML
    if (req.headers['content-type']?.includes('urlencoded')) {
      return res.send(resetPageHtml({ token, error: 'Password is required.' }));
    }
    return res.status(400).json({ message: 'Token and password are required' });
  }

  if (password.length < 6) {
    if (req.headers['content-type']?.includes('urlencoded')) {
      return res.send(resetPageHtml({ token, error: 'Password must be at least 6 characters.' }));
    }
    return res.status(400).json({ message: 'Password must be at least 6 characters' });
  }

  if (confirmPassword && password !== confirmPassword) {
    if (req.headers['content-type']?.includes('urlencoded')) {
      return res.send(resetPageHtml({ token, error: 'Passwords do not match.' }));
    }
    return res.status(400).json({ message: 'Passwords do not match' });
  }

  try {
    // Validate token
    const tokenResult = await pool.query(
      `SELECT id, user_id, expires_at, used FROM password_reset_tokens WHERE token = $1 LIMIT 1`,
      [token],
    );

    if (tokenResult.rows.length === 0 || tokenResult.rows[0].used) {
      const msg = 'Invalid or already-used reset token.';
      if (req.headers['content-type']?.includes('urlencoded')) {
        return res.send(resetPageHtml({ error: msg }));
      }
      return res.status(400).json({ message: msg });
    }

    const resetToken = tokenResult.rows[0];

    if (new Date(resetToken.expires_at) < new Date()) {
      const msg = 'Reset token has expired. Please request a new one.';
      if (req.headers['content-type']?.includes('urlencoded')) {
        return res.send(resetPageHtml({ error: msg }));
      }
      return res.status(400).json({ message: msg });
    }

    // Hash new password and update user
    const hash = await bcrypt.hash(password, 10);
    await pool.query(`UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2`, [
      hash,
      resetToken.user_id,
    ]);

    // Mark token as used
    await pool.query(`UPDATE password_reset_tokens SET used = TRUE WHERE id = $1`, [resetToken.id]);

    console.log('[RESET-PW] ✓ Password reset successful for user:', resetToken.user_id);

    if (req.headers['content-type']?.includes('urlencoded')) {
      return res.send(resetPageHtml({ success: true }));
    }
    return res.json({ message: 'Password reset successful. You can now log in.' });
  } catch (err) {
    console.error('[RESET-PW] ✗ Server error:', err);
    if (req.headers['content-type']?.includes('urlencoded')) {
      return res.send(resetPageHtml({ token, error: 'Server error. Please try again.' }));
    }
    return res.status(500).json({ message: 'Server error' });
  }
});

// ── HTML template for the self-contained reset page ─────────────────────────
function resetPageHtml({ token, error, success } = {}) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Reset Password — Jenovate LMS</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:'Inter','Segoe UI',system-ui,sans-serif;background:#F5F7FA;min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}
    .card{background:#fff;border-radius:24px;padding:40px 32px;max-width:420px;width:100%;box-shadow:0 10px 40px rgba(0,0,0,.08)}
    h1{font-size:24px;font-weight:700;color:#1F2937;text-align:center;margin-bottom:6px}
    .subtitle{font-size:14px;color:#6B7280;text-align:center;margin-bottom:28px}
    label{display:block;font-size:12px;font-weight:600;color:#6B7280;text-transform:uppercase;letter-spacing:.8px;margin-bottom:6px}
    input{width:100%;padding:14px 16px;border:1.5px solid #E5E7EB;border-radius:14px;font-size:15px;background:#F9FAFB;transition:border .2s;outline:none;margin-bottom:16px}
    input:focus{border-color:#2563EB;background:#fff}
    button{width:100%;padding:15px;background:linear-gradient(135deg,#4F46E5,#7C3AED);color:#fff;border:none;border-radius:14px;font-size:16px;font-weight:700;cursor:pointer;transition:transform .15s,box-shadow .15s}
    button:hover{transform:translateY(-1px);box-shadow:0 6px 20px rgba(79,70,229,.35)}
    button:active{transform:scale(.98)}
    .error{background:#FEE2E2;color:#DC2626;padding:12px 16px;border-radius:12px;font-size:13px;font-weight:600;margin-bottom:20px;text-align:center}
    .success{background:#D1FAE5;color:#065F46;padding:18px 16px;border-radius:12px;font-size:15px;font-weight:600;text-align:center}
    .logo{text-align:center;margin-bottom:20px;font-size:28px}
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">🎓</div>
    ${success ? `
      <h1>Password Reset!</h1>
      <p class="subtitle" style="margin-bottom:20px">Your password has been updated successfully.</p>
      <div class="success">✓ You can now log in with your new password in the Jenovate LMS app.</div>
    ` : error && !token ? `
      <h1>Reset Password</h1>
      <div class="error">${error}</div>
      <p class="subtitle">Please request a new reset link from the app.</p>
    ` : `
      <h1>Reset Password</h1>
      <p class="subtitle">Enter your new password below</p>
      ${error ? `<div class="error">${error}</div>` : ''}
      <form method="POST" action="/api/auth/reset-password">
        <input type="hidden" name="token" value="${token || ''}">
        <label>New Password</label>
        <input type="password" name="password" placeholder="••••••••" minlength="6" required>
        <label>Confirm Password</label>
        <input type="password" name="confirmPassword" placeholder="••••••••" minlength="6" required>
        <button type="submit">Reset Password</button>
      </form>
    `}
  </div>
</body>
</html>`;
}

module.exports = router;
