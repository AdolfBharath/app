const express = require('express');
const nodemailer = require('nodemailer');
const { pool } = require('../db');
const { authenticate } = require('../middleware/auth');

const router = express.Router();
router.use(authenticate);

function getAdminEmail() {
  return (
    process.env.SUPPORT_ADMIN_EMAIL ||
    process.env.SUPER_ADMIN_EMAIL ||
    process.env.DEFAULT_ADMIN_EMAIL ||
    ''
  ).trim();
}

function buildTransport() {
  const host = (process.env.SMTP_HOST || '').trim();
  const portRaw = (process.env.SMTP_PORT || '').trim();
  const user = (process.env.SMTP_USER || '').trim();
  const pass = (process.env.SMTP_PASS || '').trim();

  if (!host || !portRaw || !user || !pass) return null;

  const port = Number(portRaw);
  const secure = port === 465;

  return nodemailer.createTransport({
    host,
    port,
    secure,
    auth: { user, pass },
  });
}

/**
 * POST /api/support/messages
 * Body: { message: string }
 *
 * Creates an admin notification + sends an email (if SMTP configured).
 */
router.post('/messages', async (req, res) => {
  const { message } = req.body;

  if (!message || String(message).trim().length < 2) {
    return res.status(400).json({ message: 'message is required' });
  }

  try {
    const userId = req.user.id;
    const role = req.user.role;

    const userResult = await pool.query(
      'SELECT id, name, email, role, username, phone FROM users WHERE id = $1',
      [userId],
    );

    const user = userResult.rows[0];
    const displayName = (user?.username || user?.name || 'User').toString();

    const title = `New support message from ${displayName}`;
    const body = String(message).trim();

    // 1) In-app notification to admins
    await pool.query(
      `
      INSERT INTO notifications (
        title,
        message,
        type,
        target_group,
        sender_id,
        sender_role
      )
      VALUES ($1, $2, 'support', 'admins', $3, $4)
      `,
      [title, body, userId, role],
    );

    // 2) Email to admins (best-effort)
    const adminEmail = getAdminEmail();
    const transport = buildTransport();

    if (adminEmail && transport) {
      const from = (process.env.SMTP_FROM || process.env.SMTP_USER || '').trim();

      await transport.sendMail({
        from: from || adminEmail,
        to: adminEmail,
        subject: title,
        text: [
          title,
          '',
          `From: ${displayName} (${user?.email || 'unknown'})`,
          `Role: ${user?.role || role}`,
          `Phone: ${user?.phone || '-'}`,
          '',
          body,
        ].join('\n'),
      });
    } else {
      console.log('[SUPPORT] Email skipped (SMTP not configured or admin email missing)');
    }

    return res.status(201).json({ ok: true });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
