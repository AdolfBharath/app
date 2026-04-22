const express = require('express');
const { pool } = require('../db');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();
router.use(authenticate);

async function hasBatchAccess(user, batchId) {
  if (!user || !batchId) return false;
  if (user.role === 'admin') return true;

  if (user.role === 'mentor') {
    const result = await pool.query(
      `
      SELECT 1
      FROM batches b
      LEFT JOIN user_courses uc ON uc.course_id = b.course_id AND uc.user_id = $1
      WHERE b.id = $2
        AND (b.mentor_id = $1 OR uc.user_id IS NOT NULL)
      LIMIT 1
      `,
      [user.id, batchId],
    );
    return result.rowCount > 0;
  }

  if (user.role === 'student') {
    const result = await pool.query(
      `
      SELECT 1
      FROM users u
      LEFT JOIN batch_students bs ON bs.student_id = u.id
      WHERE u.id = $1
        AND (u.batch_id = $2 OR bs.batch_id = $2)
      LIMIT 1
      `,
      [user.id, batchId],
    );
    return result.rowCount > 0;
  }

  return false;
}

async function getTask(taskId) {
  const result = await pool.query(
    `SELECT id, batch_id, deadline, drive_link FROM batch_tasks WHERE id = $1 LIMIT 1`,
    [taskId],
  );
  return result.rowCount > 0 ? result.rows[0] : null;
}

function detectFileType({ fileUrl, driveLink }) {
  if (driveLink && String(driveLink).trim().length > 0) {
    return 'link';
  }
  const raw = (fileUrl ?? '').toString().toLowerCase();
  if (raw.endsWith('.pdf')) return 'pdf';
  if (raw.endsWith('.doc') || raw.endsWith('.docx')) return 'doc';
  if (raw.endsWith('.png') || raw.endsWith('.jpg') || raw.endsWith('.jpeg') || raw.endsWith('.webp')) {
    return 'image';
  }
  return raw.length > 0 ? 'file' : null;
}

router.get('/batches/:batchId/tasks', async (req, res) => {
  const { batchId } = req.params;
  try {
    const allowed = await hasBatchAccess(req.user, batchId);
    if (!allowed) {
      return res.status(403).json({ message: 'Forbidden: no access to this batch' });
    }

    if (req.user.role === 'student') {
      const result = await pool.query(
        `
        SELECT
          t.*,
          s.id AS my_submission_id,
          s.file_url AS my_submission_file_url,
          s.drive_link AS my_submission_drive_link,
          s.submitted_at AS my_submission_submitted_at,
          s.status AS my_submission_status,
          s.feedback AS my_submission_feedback,
          s.is_late AS my_submission_is_late,
          s.student_done AS my_submission_student_done,
          s.done_at AS my_submission_done_at,
          COALESCE(sc.done_count, 0)::int AS submission_count,
          COALESCE(sc.attempt_count, 0)::int AS attempt_count
        FROM batch_tasks t
        LEFT JOIN task_submissions s
          ON s.task_id = t.id AND s.student_id = $2
        LEFT JOIN (
          SELECT
            task_id,
            COUNT(*) FILTER (WHERE student_done = TRUE) AS done_count,
            COUNT(*) AS attempt_count
          FROM task_submissions
          GROUP BY task_id
        ) sc ON sc.task_id = t.id
        WHERE t.batch_id = $1
        ORDER BY t.created_at DESC
        `,
        [batchId, req.user.id],
      );
      return res.json(result.rows);
    }

    const result = await pool.query(
      `
      SELECT
        t.*,
        COALESCE(sc.done_count, 0)::int AS submission_count,
        COALESCE(sc.attempt_count, 0)::int AS attempt_count
      FROM batch_tasks t
      LEFT JOIN (
        SELECT
          task_id,
          COUNT(*) FILTER (WHERE student_done = TRUE) AS done_count,
          COUNT(*) AS attempt_count
        FROM task_submissions
        GROUP BY task_id
      ) sc ON sc.task_id = t.id
      WHERE t.batch_id = $1
      ORDER BY t.created_at DESC
      `,
      [batchId],
    );

    return res.json(result.rows);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

router.post('/batches/:batchId/tasks', requireRole('mentor'), async (req, res) => {
  const { batchId } = req.params;
  const { title, description, fileUrl, file_url, driveLink, drive_link, deadline } = req.body;

  if (!title || String(title).trim().length === 0) {
    return res.status(400).json({ message: 'title is required' });
  }

  try {
    const allowed = await hasBatchAccess(req.user, batchId);
    if (!allowed) {
      return res.status(403).json({ message: 'Forbidden: no access to this batch' });
    }

    const result = await pool.query(
      `
      INSERT INTO batch_tasks (batch_id, title, description, file_url, drive_link, deadline, created_by)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *
      `,
      [
        batchId,
        String(title).trim(),
        description ? String(description).trim() : '',
        fileUrl ?? file_url ?? null,
        driveLink ?? drive_link ?? null,
        deadline || null,
        req.user.id,
      ],
    );

    await pool.query(
      `
      INSERT INTO notifications (title, message, type, target_group, batch_id, sender_id, sender_role)
      VALUES ($1, $2, 'task_created', 'students', $3, $4, $5)
      `,
      [
        `New Task: ${String(title).trim()}`,
        `A new task was posted in your batch: ${String(title).trim()}`,
        batchId,
        req.user.id,
        req.user.role,
      ],
    );

    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

router.put('/tasks/:taskId', requireRole('mentor'), async (req, res) => {
  const { taskId } = req.params;
  const { title, description, fileUrl, file_url, driveLink, drive_link, deadline } = req.body;

  if (!title || String(title).trim().length === 0) {
    return res.status(400).json({ message: 'title is required' });
  }

  try {
    const task = await getTask(taskId);
    if (!task) {
      return res.status(404).json({ message: 'Task not found' });
    }

    const allowed = await hasBatchAccess(req.user, task.batch_id);
    if (!allowed) {
      return res.status(403).json({ message: 'Forbidden: no access to this task' });
    }

    const result = await pool.query(
      `
      UPDATE batch_tasks
      SET
        title = $1,
        description = $2,
        file_url = $3,
        drive_link = $4,
        deadline = $5
      WHERE id = $6
      RETURNING *
      `,
      [
        String(title).trim(),
        description ? String(description).trim() : '',
        fileUrl ?? file_url ?? null,
        driveLink ?? drive_link ?? null,
        deadline || null,
        taskId,
      ],
    );

    return res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

// Compatibility alias for deployments expecting a batch-scoped update URL.
router.put('/batches/:batchId/tasks/:taskId', requireRole('mentor'), async (req, res) => {
  const { batchId, taskId } = req.params;
  const { title, description, fileUrl, file_url, driveLink, drive_link, deadline } = req.body;

  if (!title || String(title).trim().length === 0) {
    return res.status(400).json({ message: 'title is required' });
  }

  try {
    const task = await getTask(taskId);
    if (!task) {
      return res.status(404).json({ message: 'Task not found' });
    }

    if (task.batch_id !== batchId) {
      return res.status(400).json({ message: 'Task does not belong to this batch' });
    }

    const allowed = await hasBatchAccess(req.user, task.batch_id);
    if (!allowed) {
      return res.status(403).json({ message: 'Forbidden: no access to this task' });
    }

    const result = await pool.query(
      `
      UPDATE batch_tasks
      SET
        title = $1,
        description = $2,
        file_url = $3,
        drive_link = $4,
        deadline = $5
      WHERE id = $6
      RETURNING *
      `,
      [
        String(title).trim(),
        description ? String(description).trim() : '',
        fileUrl ?? file_url ?? null,
        driveLink ?? drive_link ?? null,
        deadline || null,
        taskId,
      ],
    );

    return res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

router.post('/tasks/:taskId/submissions', requireRole('student'), async (req, res) => {
  const { taskId } = req.params;
  const { fileUrl, file_url, fileType, file_type, driveLink, drive_link, markDone, mark_done } = req.body;

  const normalizedFileUrl = fileUrl ?? file_url ?? null;
  const requestedDriveLink = driveLink ?? drive_link ?? null;
  const shouldMarkDone =
    markDone == true ||
    markDone == 'true' ||
    mark_done == true ||
    mark_done == 'true';

  let normalizedDriveLink = requestedDriveLink;
  const normalizedFileType =
    (fileType ?? file_type ?? '').toString().trim() ||
    detectFileType({
      fileUrl: normalizedFileUrl,
      driveLink: normalizedDriveLink,
    });

  if (!normalizedFileUrl && !normalizedDriveLink && !shouldMarkDone) {
    return res.status(400).json({ message: 'fileUrl or driveLink is required' });
  }

  try {
    const task = await getTask(taskId);
    if (!task) {
      return res.status(404).json({ message: 'Task not found' });
    }

    const allowed = await hasBatchAccess(req.user, task.batch_id);
    if (!allowed) {
      return res.status(403).json({ message: 'Forbidden: no access to this task' });
    }

    // If client marks done without explicitly sending a link,
    // preserve the task-level drive link for auditability.
    if (!normalizedDriveLink && shouldMarkDone && task.drive_link) {
      normalizedDriveLink = task.drive_link;
    }

    const isLate = task.deadline ? new Date() > new Date(task.deadline) : false;

    const result = await pool.query(
      `
      INSERT INTO task_submissions (
        task_id,
        student_id,
        file_url,
        file_type,
        drive_link,
        submitted_at,
        status,
        is_late,
        student_done,
        done_at
      )
      VALUES (
        $1,
        $2,
        $3,
        $4,
        $5,
        NOW(),
        'pending',
        $6,
        $7,
        CASE WHEN $7 THEN NOW() ELSE NULL END
      )
      ON CONFLICT (task_id, student_id)
      DO UPDATE SET
        file_url = COALESCE(EXCLUDED.file_url, task_submissions.file_url),
        file_type = COALESCE(EXCLUDED.file_type, task_submissions.file_type),
        drive_link = COALESCE(EXCLUDED.drive_link, task_submissions.drive_link),
        submitted_at = NOW(),
        status = CASE
          WHEN task_submissions.status IN ('validated', 'rejected')
            THEN task_submissions.status
          ELSE 'pending'
        END,
        feedback = CASE
          WHEN task_submissions.status IN ('validated', 'rejected')
            THEN task_submissions.feedback
          ELSE NULL
        END,
        reviewed_by = CASE
          WHEN task_submissions.status IN ('validated', 'rejected')
            THEN task_submissions.reviewed_by
          ELSE NULL
        END,
        reviewed_at = CASE
          WHEN task_submissions.status IN ('validated', 'rejected')
            THEN task_submissions.reviewed_at
          ELSE NULL
        END,
        is_late = EXCLUDED.is_late,
        student_done = (task_submissions.student_done OR EXCLUDED.student_done),
        done_at = CASE
          WHEN (task_submissions.student_done OR EXCLUDED.student_done)
            THEN COALESCE(task_submissions.done_at, EXCLUDED.done_at, NOW())
          ELSE NULL
        END
      RETURNING *
      `,
      [
        taskId,
        req.user.id,
        normalizedFileUrl,
        normalizedFileType,
        normalizedDriveLink,
        isLate,
        shouldMarkDone,
      ],
    );

    await pool.query(
      `
      INSERT INTO notifications (title, message, type, target_group, batch_id, sender_id, sender_role)
      VALUES
        ('New Submission', $1, 'task_submission', 'mentors', $2, $3, $4),
        ('New Submission', $1, 'task_submission', 'admins',  $2, $3, $4)
      `,
      [
        'A student submitted work for a batch task.',
        task.batch_id,
        req.user.id,
        req.user.role,
      ],
    );

    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

router.get('/tasks/:taskId/my-submission', requireRole('student'), async (req, res) => {
  const { taskId } = req.params;
  try {
    const task = await getTask(taskId);
    if (!task) {
      return res.status(404).json({ message: 'Task not found' });
    }

    const allowed = await hasBatchAccess(req.user, task.batch_id);
    if (!allowed) {
      return res.status(403).json({ message: 'Forbidden: no access to this task' });
    }

    const result = await pool.query(
      `
      SELECT *
      FROM task_submissions
      WHERE task_id = $1 AND student_id = $2
      LIMIT 1
      `,
      [taskId, req.user.id],
    );

    if (result.rowCount === 0) {
      return res.json(null);
    }

    return res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

router.get('/tasks/:taskId/submissions', requireRole('mentor', 'admin'), async (req, res) => {
  const { taskId } = req.params;
  try {
    const task = await getTask(taskId);
    if (!task) {
      return res.status(404).json({ message: 'Task not found' });
    }

    const allowed = await hasBatchAccess(req.user, task.batch_id);
    if (!allowed) {
      return res.status(403).json({ message: 'Forbidden: no access to this task' });
    }

    const result = await pool.query(
      `
      SELECT
        s.*,
        u.name AS student_name,
        u.email AS student_email,
        u.username AS student_username
      FROM task_submissions s
      JOIN users u ON u.id = s.student_id
      WHERE s.task_id = $1
      ORDER BY s.submitted_at DESC
      `,
      [taskId],
    );

    return res.json(result.rows);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

router.put('/submissions/:submissionId/review', requireRole('mentor', 'admin'), async (req, res) => {
  const { submissionId } = req.params;
  const { status, feedback } = req.body;

  if (!status || !['validated', 'rejected', 'pending'].includes(status)) {
    return res.status(400).json({ message: 'status must be pending, validated, or rejected' });
  }

  try {
    const row = await pool.query(
      `
      SELECT s.id, s.task_id, t.batch_id
      FROM task_submissions s
      JOIN batch_tasks t ON t.id = s.task_id
      WHERE s.id = $1
      LIMIT 1
      `,
      [submissionId],
    );

    if (row.rowCount === 0) {
      return res.status(404).json({ message: 'Submission not found' });
    }

    const { batch_id: batchId } = row.rows[0];
    const allowed = await hasBatchAccess(req.user, batchId);
    if (!allowed) {
      return res.status(403).json({ message: 'Forbidden: no access to this submission' });
    }

    const result = await pool.query(
      `
      UPDATE task_submissions
      SET
        status = $1,
        feedback = $2,
        reviewed_by = $3,
        reviewed_at = NOW()
      WHERE id = $4
      RETURNING *
      `,
      [status, feedback ?? null, req.user.id, submissionId],
    );

    return res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
