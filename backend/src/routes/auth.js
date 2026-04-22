const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
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
router.post('/login', async (req, res) => {
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
    });
  } catch (err) {
    console.error('[LOGIN] ✗ Server error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
