const express = require('express');
const fs = require('fs');
const { Readable } = require('stream');
const multer = require('multer');
const { google } = require('googleapis');
const { pool } = require('../db');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();
router.use(authenticate);
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 20 * 1024 * 1024 },
});

function parseServiceAccountConfig() {
  const rawJson = process.env.GOOGLE_SERVICE_ACCOUNT_JSON;
  const rawBase64 = process.env.GOOGLE_SERVICE_ACCOUNT_BASE64;
  const keyPath = process.env.GOOGLE_SERVICE_ACCOUNT_KEY_PATH;
  const serviceEmail = process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL;
  const privateKey = process.env.GOOGLE_PRIVATE_KEY;

  if (rawJson) {
    return JSON.parse(rawJson);
  }

  if (rawBase64) {
    const decoded = Buffer.from(rawBase64, 'base64').toString('utf8');
    return JSON.parse(decoded);
  }

  if (keyPath) {
    const data = fs.readFileSync(keyPath, 'utf8');
    return JSON.parse(data);
  }

  if (serviceEmail && privateKey) {
    return {
      client_email: serviceEmail,
      private_key: String(privateKey).replace(/\\n/g, '\n'),
    };
  }

  return null;
}

function detectFileType({ mimeType, fileName }) {
  const mt = String(mimeType || '').toLowerCase();
  const name = String(fileName || '').toLowerCase();

  if (mt.includes('pdf') || name.endsWith('.pdf')) return 'pdf';
  if (mt.includes('word') || name.endsWith('.doc') || name.endsWith('.docx')) return 'doc';
  if (mt.startsWith('image/') || name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.jpeg')) {
    return 'image';
  }
  return 'file';
}

async function assertStudentTaskAccess(studentId, taskId) {
  const result = await pool.query(
    `
    SELECT t.id, t.batch_id
    FROM batch_tasks t
    WHERE t.id = $1
    LIMIT 1
    `,
    [taskId],
  );

  if (result.rowCount === 0) {
    const err = new Error('Task not found');
    err.statusCode = 404;
    throw err;
  }

  const { batch_id: batchId } = result.rows[0];

  const access = await pool.query(
    `
    SELECT 1
    FROM users u
    LEFT JOIN batch_students bs ON bs.student_id = u.id
    WHERE u.id = $1
      AND (u.batch_id = $2 OR bs.batch_id = $2)
    LIMIT 1
    `,
    [studentId, batchId],
  );

  if (access.rowCount === 0) {
    const err = new Error('Forbidden: no access to this task');
    err.statusCode = 403;
    throw err;
  }

  return { batchId };
}

router.post(['/upload', '/uploads/drive-submission', '/drive-submission'], requireRole('student'), upload.single('file'), async (req, res) => {
  const { taskId } = req.body;
  const file = req.file;
  const requestedMimeType = req.body?.mimeType;

  if (!taskId) {
    return res.status(400).json({ message: 'taskId is required' });
  }

  if (!file) {
    return res.status(400).json({ message: 'file is required (multipart/form-data)' });
  }

  try {
    await assertStudentTaskAccess(req.user.id, taskId);

    const serviceAccount = parseServiceAccountConfig();
    if (!serviceAccount) {
      return res.status(503).json({
        message:
          'Google Drive upload not configured. Set GOOGLE_SERVICE_ACCOUNT_JSON, GOOGLE_SERVICE_ACCOUNT_BASE64, GOOGLE_SERVICE_ACCOUNT_KEY_PATH, or GOOGLE_SERVICE_ACCOUNT_EMAIL + GOOGLE_PRIVATE_KEY.',
      });
    }

    const folderId = process.env.GOOGLE_DRIVE_FOLDER_ID || '1H33QJ1tIPxyx7WLVj1hyvgFYDdjXI-Sd';

    const auth = new google.auth.GoogleAuth({
      credentials: serviceAccount,
      scopes: ['https://www.googleapis.com/auth/drive.file'],
    });

    const drive = google.drive({ version: 'v3', auth });

    const created = await drive.files.create({
      requestBody: {
        name: String(file.originalname || `submission-${Date.now()}`),
        parents: [folderId],
      },
      media: {
        mimeType: requestedMimeType || file.mimetype || 'application/octet-stream',
        body: Readable.from(file.buffer),
      },
      fields: 'id, webViewLink, webContentLink',
    });

    const fileId = created.data.id;
    if (!fileId) {
      throw new Error('Drive API did not return file id');
    }

    // Make uploaded submissions accessible for mentor/admin review.
    await drive.permissions.create({
      fileId,
      requestBody: {
        role: 'reader',
        type: 'anyone',
      },
    });

    const fileUrl =
      created.data.webViewLink ||
      created.data.webContentLink ||
      `https://drive.google.com/file/d/${fileId}/view`;

    return res.status(201).json({
      fileId,
      fileUrl,
      fileName: file.originalname,
      fileType: detectFileType({
        mimeType: requestedMimeType || file.mimetype,
        fileName: file.originalname,
      }),
    });
  } catch (err) {
    const status = err.statusCode || 500;
    console.error(err);
    return res.status(status).json({ message: err.message || 'Server error' });
  }
});

module.exports = router;
