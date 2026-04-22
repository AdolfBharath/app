const express = require('express');
const { pool } = require('../db');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(authenticate);
router.use(requireRole('mentor', 'admin'));

/**
 * GET /api/mentor/courses
 * Returns courses assigned to the current mentor.
 */
router.get('/courses', async (req, res) => {
  try {
    const result = req.user.role === 'admin'
      ? await pool.query(
          `
          SELECT c.*
          FROM courses c
          ORDER BY c.created_at DESC
          `,
        )
      : await pool.query(
          `
          SELECT c.*
          FROM courses c
          WHERE c.mentor_id = $1
          ORDER BY c.created_at DESC
          `,
          [req.user.id],
        );
    return res.json(result.rows);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * GET /api/mentor/batches
 * Returns batches assigned to the current mentor with enrolled_count.
 */
router.get('/batches', async (req, res) => {
  try {
    const result = await pool.query(
      `
      WITH mentor_course_ids AS (
        SELECT uc.course_id
        FROM user_courses uc
        WHERE uc.user_id = $1
      )
      SELECT
        b.*,
        COALESCE(ec.enrolled_count, 0)::int AS enrolled_count,
        CASE
          WHEN b.capacity IS NOT NULL AND b.capacity > 0
            THEN LEAST(1.0, COALESCE(ec.enrolled_count, 0)::double precision / b.capacity::double precision)
          ELSE 0.0
        END AS progress
      FROM batches b
      LEFT JOIN (
        SELECT
          bs.batch_id,
          COUNT(*)::int AS enrolled_count
        FROM batch_students bs
        GROUP BY bs.batch_id
      ) ec ON ec.batch_id = b.id
      WHERE b.mentor_id = $1
         OR b.course_id IN (SELECT course_id FROM mentor_course_ids)
      ORDER BY b.created_at DESC
      `,
      [req.user.id],
    );
    return res.json(result.rows);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
