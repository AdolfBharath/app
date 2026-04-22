const express = require('express');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { pool } = require('../db');
const { authenticate, requireRole } = require('../middleware/auth');
const {
  isEmailServiceConfigured,
  sendWelcomeUserEmail,
} = require('../services/email_service');

const router = express.Router();

// All user routes are protected — only authenticated users may access them.
router.use(authenticate);

/**
 * GET /api/users?role=student|mentor|admin
 * Returns all users, optionally filtered by role.
 * Accessible by: admin, mentor
 */
router.get('/', requireRole('admin', 'mentor'), async (req, res) => {
  const { role } = req.query;
  try {
    let result;
    const baseSelect = `
      SELECT
        u.id,
        u.name,
        u.email,
        u.role,
        u.username,
        u.admin_no,
        u.phone,
        COALESCE(u.batch_id, ub.batch_id) AS batch_id,
        COALESCE(ucm.course_ids, ARRAY[]::uuid[]) AS course_ids
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
    `;

    if (role && ['admin', 'student', 'mentor'].includes(role)) {
      result = await pool.query(
        `${baseSelect} WHERE u.role = $1 ORDER BY u.created_at DESC`,
        [role],
      );
    } else {
      result = await pool.query(
        `${baseSelect} ORDER BY u.created_at DESC`,
      );
    }
    return res.json(result.rows);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * GET /api/users/me
 * Returns current authenticated user profile + course assignments.
 */
router.get('/me', async (req, res) => {
  try {
    const result = await pool.query(
      `
      SELECT
        u.id,
        u.name,
        u.email,
        u.role,
        u.username,
        u.admin_no,
        u.phone,
        u.batch_id,
        COALESCE(ucm.course_ids, ARRAY[]::uuid[]) AS course_ids
      FROM users u
      LEFT JOIN LATERAL (
        SELECT ARRAY_AGG(uc.course_id ORDER BY uc.created_at DESC) AS course_ids
        FROM user_courses uc
        WHERE uc.user_id = u.id
      ) ucm ON TRUE
      WHERE u.id = $1
      LIMIT 1
      `,
      [req.user.id],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ message: 'User not found' });
    }

    return res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * POST /api/users
 * Create a new user. Admin only.
 */
router.post('/', requireRole('admin'), async (req, res) => {
  const { name, email, password, role, phone } = req.body;

  if (!name || !email || !role) {
    return res.status(400).json({ message: 'name, email, and role are required' });
  }

  if (!['admin', 'student', 'mentor'].includes(role)) {
    return res.status(400).json({ message: 'Invalid role' });
  }

  try {
    const normalizedEmail = email.trim().toLowerCase();
    const temporaryPassword =
      password && String(password).trim().length > 0
        ? String(password).trim()
        : crypto.randomBytes(8).toString('hex');
    const hash = await bcrypt.hash(temporaryPassword, 10);
    const result = await pool.query(
      'INSERT INTO users (name, email, password_hash, role, phone) VALUES ($1, $2, $3, $4, $5) RETURNING id, name, email, role, phone',
      [name, normalizedEmail, hash, role, phone],
    );

    let emailSent = false;
    let emailWarning = null;
    try {
      await sendWelcomeUserEmail({
        userName: name,
        email: normalizedEmail,
        role,
        temporaryPassword,
      });
      emailSent = true;
    } catch (mailErr) {
      console.error('[MAIL] Welcome email failed:', mailErr.message);
      emailWarning = isEmailServiceConfigured()
        ? 'User created, but welcome email could not be sent.'
        : 'User created, but email service is not configured.';
    }

    return res.status(201).json({
      ...result.rows[0],
      email_sent: emailSent,
      email_warning: emailWarning,
    });
  } catch (err) {
    console.error(err);
    if (err.code === '23505') {
      return res.status(409).json({ message: 'Email already exists' });
    }
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * PUT /api/users/current
 * Change the current admin password.
 */
router.put('/current', requireRole('admin'), async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  const userId = req.user.id;

  if (!currentPassword || !newPassword) {
    return res.status(400).json({ message: 'currentPassword and newPassword are required' });
  }

  try {
    const result = await pool.query(
      'SELECT id, password_hash FROM users WHERE id = $1',
      [userId],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ message: 'User not found' });
    }

    const user = result.rows[0];
    const isMatch = await bcrypt.compare(currentPassword, user.password_hash || '');
    if (!isMatch) {
      return res.status(400).json({ message: 'Current password is incorrect' });
    }

    const hash = await bcrypt.hash(newPassword, 10);
    await pool.query(
      'UPDATE users SET password_hash = $1 WHERE id = $2',
      [hash, userId],
    );

    return res.json({ message: 'Password updated successfully' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * PUT /api/users/me
 * Update the currently authenticated user's own profile.
 * Accessible by: admin, mentor, student
 *
 * Body supports:
 *  - name, username, phone, email
 *  - currentPassword + newPassword (optional password change)
 */
router.put('/me', async (req, res) => {
  const userId = req.user.id;
  const {
    name,
    username,
    phone,
    email,
    currentPassword,
    newPassword,
  } = req.body;

  try {
    // Optional password change.
    if ((currentPassword && !newPassword) || (!currentPassword && newPassword)) {
      return res.status(400).json({
        message: 'Both currentPassword and newPassword are required to change password',
      });
    }

    if (currentPassword && newPassword) {
      const result = await pool.query(
        'SELECT id, password_hash FROM users WHERE id = $1',
        [userId],
      );

      if (result.rowCount === 0) {
        return res.status(404).json({ message: 'User not found' });
      }

      const user = result.rows[0];
      const isMatch = await bcrypt.compare(currentPassword, user.password_hash || '');
      if (!isMatch) {
        return res.status(400).json({ message: 'Current password is incorrect' });
      }

      const hash = await bcrypt.hash(newPassword, 10);
      await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [
        hash,
        userId,
      ]);
    }

    // Profile fields.
    const updates = [];
    const values = [];

    if (name && String(name).trim().length > 0) {
      updates.push('name = $' + (values.length + 1));
      values.push(String(name).trim());
    }

    if (username && String(username).trim().length > 0) {
      updates.push('username = $' + (values.length + 1));
      values.push(String(username).trim());
    }

    if (phone !== undefined) {
      const trimmed = String(phone ?? '').trim();
      updates.push('phone = $' + (values.length + 1));
      values.push(trimmed.isEmpty ? null : trimmed);
    }

    if (email && String(email).trim().length > 0) {
      const normalizedEmail = String(email).trim().toLowerCase();
      updates.push('email = $' + (values.length + 1));
      values.push(normalizedEmail);
    }

    let updatedRow = null;
    if (updates.length > 0) {
      values.push(userId);
      const query = `
        UPDATE users
        SET ${updates.join(', ')}
        WHERE id = $${values.length}
        RETURNING id, name, email, role, username, admin_no, phone, batch_id
      `;

      const result = await pool.query(query, values);
      if (result.rows.length === 0) {
        return res.status(404).json({ message: 'User not found' });
      }
      updatedRow = result.rows[0];
    } else {
      const result = await pool.query(
        'SELECT id, name, email, role, username, admin_no, phone, batch_id FROM users WHERE id = $1',
        [userId],
      );
      updatedRow = result.rows[0] || null;
    }

    return res.json(updatedRow);
  } catch (err) {
    console.error(err);
    if (err.code === '23505') {
      return res.status(409).json({ message: 'Email already exists' });
    }
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * PUT /api/users/:id
 * Update a user's fields. Admin only.
 */
router.put('/:id', requireRole('admin'), async (req, res) => {
  const { id } = req.params;
  const {
    name,
    password,
    username,
    adminNo,
    role,
    phone,
    email,
    batch_id,
    batchId,
    course_ids,
    courseIds,
  } = req.body;

  const normalizedBatchId = batchId !== undefined ? batchId : batch_id;
  const incomingCourseIds = courseIds !== undefined ? courseIds : course_ids;
  const hasCourseIds = Array.isArray(incomingCourseIds);

  try {
    const userCheck = await pool.query('SELECT id, role FROM users WHERE id = $1', [id]);
    if (userCheck.rowCount === 0) {
      return res.status(404).json({ message: 'User not found' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const updates = [];
      const values = [];

      if (name !== undefined) {
        updates.push('name = $' + (values.length + 1));
        values.push(name);
      }
      if (username !== undefined) {
        updates.push('username = $' + (values.length + 1));
        values.push(username);
      }
      if (adminNo !== undefined) {
        updates.push('admin_no = $' + (values.length + 1));
        values.push(adminNo);
      }
      if (phone !== undefined) {
        updates.push('phone = $' + (values.length + 1));
        values.push(phone);
      }
      if (email !== undefined) {
        updates.push('email = $' + (values.length + 1));
        values.push(String(email).trim().toLowerCase());
      }
      if (role !== undefined) {
        if (!['admin', 'student', 'mentor'].includes(role)) {
          return res.status(400).json({ message: 'Invalid role' });
        }
        updates.push('role = $' + (values.length + 1));
        values.push(role);
      }
      if (password !== undefined && String(password).trim().length > 0) {
        const hash = await bcrypt.hash(password, 10);
        updates.push('password_hash = $' + (values.length + 1));
        values.push(hash);
      }
      if (normalizedBatchId !== undefined) {
        updates.push('batch_id = $' + (values.length + 1));
        values.push(normalizedBatchId || null);
      }

      if (updates.length > 0) {
        values.push(id);
        const query = `UPDATE users SET ${updates.join(', ')} WHERE id = $${values.length}`;
        await client.query(query, values);
      }

      if (hasCourseIds) {
        const uniqueCourseIds = [...new Set(incomingCourseIds.map((v) => String(v).trim()).filter(Boolean))];

        await client.query('DELETE FROM user_courses WHERE user_id = $1', [id]);

        for (const courseId of uniqueCourseIds) {
          await client.query(
            `INSERT INTO user_courses (user_id, course_id)
             VALUES ($1, $2)
             ON CONFLICT (user_id, course_id) DO NOTHING`,
            [id, courseId],
          );
        }

        await client.query('DELETE FROM batch_students WHERE student_id = $1', [id]);
        await client.query(
          `
          INSERT INTO batch_students (batch_id, student_id)
          SELECT b.id, $1
          FROM batches b
          WHERE b.course_id = ANY($2::uuid[])
            AND (SELECT role FROM users WHERE id = $1) = 'student'
          ON CONFLICT (batch_id, student_id) DO NOTHING
          `,
          [id, uniqueCourseIds],
        );
      }

      if (normalizedBatchId !== undefined) {
        if (normalizedBatchId) {
          await client.query('DELETE FROM batch_students WHERE student_id = $1', [id]);
          await client.query(
            `INSERT INTO batch_students (batch_id, student_id)
             VALUES ($1, $2)
             ON CONFLICT (batch_id, student_id) DO NOTHING`,
            [normalizedBatchId, id],
          );
        } else {
          await client.query('DELETE FROM batch_students WHERE student_id = $1', [id]);
        }
      }

      if (
        updates.length === 0 &&
        !hasCourseIds
      ) {
        await client.query('ROLLBACK');
        return res.status(400).json({ message: 'No fields to update' });
      }

      const result = await client.query(
        `
        SELECT
          u.id,
          u.name,
          u.email,
          u.role,
          u.username,
          u.admin_no,
          u.phone,
          u.batch_id,
          COALESCE(ucm.course_ids, ARRAY[]::uuid[]) AS course_ids
        FROM users u
        LEFT JOIN LATERAL (
          SELECT ARRAY_AGG(uc.course_id ORDER BY uc.created_at DESC) AS course_ids
          FROM user_courses uc
          WHERE uc.user_id = u.id
        ) ucm ON TRUE
        WHERE u.id = $1
        `,
        [id],
      );

      await client.query('COMMIT');
      return res.json(result.rows[0]);
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (err) {
    console.error(err);
    if (err.code === '23505') {
      return res.status(409).json({ message: 'Email already exists' });
    }
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * DELETE /api/users/:id
 * Delete a user. Admin only.
 */
router.delete('/:id', requireRole('admin'), async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query('DELETE FROM users WHERE id = $1 RETURNING id', [id]);

    if (result.rowCount === 0) {
      return res.status(404).json({ message: 'User not found' });
    }

    return res.json({ message: 'User deleted' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * POST /api/users/:userId/courses/:courseId
 * Assign a course to a user. Admin only.
 */
router.post('/:userId/courses/:courseId', requireRole('admin'), async (req, res) => {
  const { userId, courseId } = req.params;

  try {
    const userCheck = await pool.query(
      'SELECT id, role FROM users WHERE id = $1',
      [userId],
    );
    if (userCheck.rowCount === 0) {
      return res.status(404).json({ message: 'User not found' });
    }

    const courseCheck = await pool.query(
      'SELECT id FROM courses WHERE id = $1',
      [courseId],
    );
    if (courseCheck.rowCount === 0) {
      return res.status(404).json({ message: 'Course not found' });
    }

    const result = await pool.query(
      `INSERT INTO user_courses (user_id, course_id)
       VALUES ($1, $2)
       ON CONFLICT (user_id, course_id) DO NOTHING
       RETURNING id`,
      [userId, courseId],
    );

    // Sync the student into batch_students for every batch on this course.
    await pool.query(
      `
      INSERT INTO batch_students (batch_id, student_id)
      SELECT b.id, $1
      FROM batches b
      WHERE b.course_id = $2
        AND (SELECT role FROM users WHERE id = $1) = 'student'
      ON CONFLICT (batch_id, student_id) DO NOTHING
      `,
      [userId, courseId],
    );

    await pool.query(
      `
      UPDATE users
      SET batch_id = (
        SELECT b.id
        FROM batches b
        WHERE b.course_id = $1
        ORDER BY b.created_at DESC
        LIMIT 1
      )
      WHERE id = $2
        AND role = 'student'
      `,
      [courseId, userId],
    );

    if (result.rowCount === 0) {
      return res.status(200).json({ message: 'Course already assigned' });
    }

    return res.status(201).json({ message: 'Course assigned' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * POST /api/users/assign-course
 * Alternate assignment endpoint for compatibility.
 */
router.post('/assign-course', requireRole('admin'), async (req, res) => {
  const { user_id, userId, course_id, courseId } = req.body;
  const uid = userId || user_id;
  const cid = courseId || course_id;

  if (!uid || !cid) {
    return res.status(400).json({ message: 'user_id and course_id are required' });
  }

  try {
    const userCheck = await pool.query(
      'SELECT id FROM users WHERE id = $1',
      [uid],
    );
    if (userCheck.rowCount === 0) {
      return res.status(404).json({ message: 'User not found' });
    }

    const courseCheck = await pool.query(
      'SELECT id FROM courses WHERE id = $1',
      [cid],
    );
    if (courseCheck.rowCount === 0) {
      return res.status(404).json({ message: 'Course not found' });
    }

    await pool.query(
      `INSERT INTO user_courses (user_id, course_id)
       VALUES ($1, $2)
       ON CONFLICT (user_id, course_id) DO NOTHING`,
      [uid, cid],
    );

    // Sync the student into batch_students for every batch on this course.
    await pool.query(
      `
      INSERT INTO batch_students (batch_id, student_id)
      SELECT b.id, $1
      FROM batches b
      WHERE b.course_id = $2
        AND (SELECT role FROM users WHERE id = $1) = 'student'
      ON CONFLICT (batch_id, student_id) DO NOTHING
      `,
      [uid, cid],
    );

    await pool.query(
      `
      UPDATE users
      SET batch_id = (
        SELECT b.id
        FROM batches b
        WHERE b.course_id = $1
        ORDER BY b.created_at DESC
        LIMIT 1
      )
      WHERE id = $2
        AND role = 'student'
      `,
      [cid, uid],
    );

    return res.status(201).json({ message: 'Course assigned' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
