const express = require('express');
const { pool } = require('../db');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(authenticate);

/**
 * GET /api/projects
 * Admin/mentor project review list.
 */
router.get('/', requireRole('admin', 'mentor'), async (_req, res) => {
  try {
    const result = await pool.query(
      `
      SELECT
        p.id,
        p.title,
        p.description,
        p.student_id,
        COALESCE(s.name, 'Unknown Student') AS student_name,
        p.batch_id,
        COALESCE(b.name, 'Unknown Batch') AS batch_name,
        p.created_at AS submission_date,
        p.status,
        p.file_urls,
        p.review_notes,
        p.reviewed_by,
        p.reviewed_date
      FROM projects p
      LEFT JOIN users s ON s.id = p.student_id
      LEFT JOIN batches b ON b.id = p.batch_id
      ORDER BY p.created_at DESC
      `,
    );
    return res.json(result.rows);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * GET /api/projects/:id
 */
router.get('/:id', requireRole('admin', 'mentor'), async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `
      SELECT
        p.id,
        p.title,
        p.description,
        p.student_id,
        COALESCE(s.name, 'Unknown Student') AS student_name,
        p.batch_id,
        COALESCE(b.name, 'Unknown Batch') AS batch_name,
        p.created_at AS submission_date,
        p.status,
        p.file_urls,
        p.review_notes,
        p.reviewed_by,
        p.reviewed_date
      FROM projects p
      LEFT JOIN users s ON s.id = p.student_id
      LEFT JOIN batches b ON b.id = p.batch_id
      WHERE p.id = $1
      `,
      [id],
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ message: 'Project not found' });
    }
    return res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * PUT /api/projects/:id/status
 */
router.put('/:id/status', requireRole('admin', 'mentor'), async (req, res) => {
  const { id } = req.params;
  const { status, review_notes } = req.body;

  if (!status) {
    return res.status(400).json({ message: 'status is required' });
  }

  try {
    const result = await pool.query(
      `
      UPDATE projects
      SET
        status = $1,
        review_notes = COALESCE($2, review_notes),
        reviewed_by = $3,
        reviewed_date = NOW()
      WHERE id = $4
      RETURNING id
      `,
      [status, review_notes || null, req.user.id, id],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ message: 'Project not found' });
    }

    return res.json({ message: 'Project status updated' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
