const express = require('express');
const jwt = require('jsonwebtoken');
const { pool } = require('../db');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

function normalizeStudyMaterials(raw) {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((item) => {
      if (!item || typeof item !== 'object') return null;
      const title = String(item.title ?? '').trim();
      if (!title) return null;
      return {
        title,
        description: String(item.description ?? '').trim(),
        driveLink: String(item.driveLink ?? item.drive_link ?? '').trim(),
        fileName: String(item.fileName ?? item.file_name ?? '').trim(),
        fileType: String(item.fileType ?? item.file_type ?? '').trim(),
      };
    })
    .filter(Boolean);
}

function normalizeQuizQuestions(raw) {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((item) => {
      if (!item || typeof item !== 'object') return null;
      const question = String(item.question ?? '').trim();
      if (!question) return null;
      return {
        question,
        optionA: String(item.optionA ?? item.option_a ?? '').trim(),
        optionB: String(item.optionB ?? item.option_b ?? '').trim(),
        optionC: String(item.optionC ?? item.option_c ?? '').trim(),
        optionD: String(item.optionD ?? item.option_d ?? '').trim(),
        correctAnswer: String(item.correctAnswer ?? item.correct_answer ?? '').trim(),
      };
    })
    .filter(Boolean);
}

function normalizeModules(modules) {
  if (!Array.isArray(modules)) return [];
  return modules
    .map((raw, index) => {
      if (!raw || typeof raw !== 'object') return null;
      const moduleNumberRaw = raw.moduleNumber ?? raw.module_number ?? raw.order ?? (index + 1);
      const moduleNumber = Number(moduleNumberRaw);
      const coinRewardRaw = raw.coinReward ?? raw.coin_reward ?? 0;
      const coinReward = Number(coinRewardRaw);
      return {
        id: String(raw.id ?? ''),
        courseId: raw.courseId ?? raw.course_id ?? null,
        moduleNumber: Number.isFinite(moduleNumber) && moduleNumber > 0 ? moduleNumber : (index + 1),
        title: String(raw.title ?? '').trim(),
        lessonTitle: String(raw.lessonTitle ?? raw.lesson_title ?? raw.title ?? '').trim(),
        description: String(raw.description ?? '').trim(),
        videoDriveLink: String(raw.videoDriveLink ?? raw.video_drive_link ?? '').trim(),
        transcript: String(raw.transcript ?? '').trim(),
        duration: String(raw.duration ?? '').trim(),
        coinReward: Number.isFinite(coinReward) && coinReward > 0 ? Math.floor(coinReward) : 0,
        studyMaterials: normalizeStudyMaterials(raw.studyMaterials ?? raw.study_materials),
        quizQuestions: normalizeQuizQuestions(raw.quizQuestions ?? raw.quiz_questions),
      };
    })
    .filter((m) => m && m.title.length > 0);
}

function sanitizeModulesForViewer(modules, canViewVideo) {
  const normalized = normalizeModules(modules);
  if (canViewVideo) return normalized;
  return normalized.map((m) => ({
    ...m,
    videoDriveLink: '',
    quizQuestions: [],
    studyMaterials: (m.studyMaterials || []).map((material) => ({
      ...material,
      driveLink: '',
      fileName: material.fileName || '',
    })),
  }));
}

function getOptionalUserFromAuthHeader(req) {
  const authHeader = req.headers['authorization'];
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;
  const token = authHeader.split(' ')[1];
  try {
    return jwt.verify(token, process.env.JWT_SECRET);
  } catch (_) {
    return null;
  }
}

async function getUserCourseIds(userId) {
  const result = await pool.query(
    `SELECT course_id FROM user_courses WHERE user_id = $1`,
    [userId],
  );
  return new Set(result.rows.map((r) => String(r.course_id)));
}

/**
 * GET /api/courses
 * PUBLIC — no auth required. Anyone (including marketplace visitors) can
 * browse the course catalogue before logging in.
 */
router.get('/', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM courses ORDER BY created_at');

    const optionalUser = getOptionalUserFromAuthHeader(req);
    let enrolledCourseIds = new Set();
    if (optionalUser && optionalUser.id && optionalUser.role === 'student') {
      enrolledCourseIds = await getUserCourseIds(optionalUser.id);
    }

    const mapped = result.rows.map((course) => {
      let canViewVideo = false;
      if (optionalUser) {
        if (optionalUser.role === 'admin') {
          canViewVideo = true;
        } else if (optionalUser.role === 'mentor') {
          canViewVideo = String(course.mentor_id ?? '') === String(optionalUser.id);
        } else if (optionalUser.role === 'student') {
          canViewVideo = enrolledCourseIds.has(String(course.id));
        }
      }

      return {
        ...course,
        modules: sanitizeModulesForViewer(course.modules, canViewVideo),
      };
    });

    return res.json(mapped);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

// All write operations below this point require a valid JWT.
router.use(authenticate);

/**
 * POST /api/courses/:courseId/enroll
 * Student self-enrollment endpoint.
 *
 * Inserts into user_courses for the current authenticated student.
 * Returns the updated user profile fields + course_ids so the client can
 * refresh its local session state.
 */
router.post('/:courseId/enroll', requireRole('student'), async (req, res) => {
  const { courseId } = req.params;
  const userId = req.user.id;

  try {
    const courseCheck = await pool.query('SELECT id FROM courses WHERE id = $1', [courseId]);
    if (courseCheck.rowCount === 0) {
      return res.status(404).json({ message: 'Course not found' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      await client.query(
        `INSERT INTO user_courses (user_id, course_id)
         VALUES ($1, $2)
         ON CONFLICT (user_id, course_id) DO NOTHING`,
        [userId, courseId],
      );

      await client.query(
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
        LIMIT 1
        `,
        [userId],
      );

      await client.query('COMMIT');
      return res.status(201).json({ message: 'Enrolled', user: result.rows[0] });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * POST /api/courses
 * Create a new course. Admin or mentor.
 */
router.post('/', requireRole('admin', 'mentor'), async (req, res) => {
  const {
    title,
    description,
    category,
    duration,
    instructor_name,
    instructorName,
    module_type,
    moduleType,
    thumbnail_url,
    thumbnailUrl,
    rating,
    difficulty,
    modules,
    mentor_id,
    mentorId,
    price,
    quiz_coin_reward,
    quizCoinReward,
    quiz_pass_score,
    quizPassScore,
  } = req.body;

  if (!title || !description) {
    return res.status(400).json({ message: 'title and description are required' });
  }

  try {
    const result = await pool.query(
      `INSERT INTO courses
        (title, description, category, duration, instructor_name, module_type, thumbnail_url, rating, difficulty, modules, mentor_id, price, quiz_coin_reward, quiz_pass_score)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
       RETURNING *`,
      [
        title,
        description,
        category || 'Development',
        duration || '',
        instructorName || instructor_name || 'Academy Mentor',
        moduleType || module_type || 'Self-paced',
        thumbnailUrl || thumbnail_url || '',
        rating || 4.5,
        difficulty || 'intermediate',
        JSON.stringify(normalizeModules(modules || [])),
        req.user.role === 'mentor' ? req.user.id : (mentor_id || mentorId || null),
        price != null ? Number(price) : 0.00,
        quizCoinReward != null ? Number(quizCoinReward) : (quiz_coin_reward != null ? Number(quiz_coin_reward) : 0),
        quizPassScore != null ? Number(quizPassScore) : (quiz_pass_score != null ? Number(quiz_pass_score) : 0),
      ],
    );
    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * PUT /api/courses/:id
 * Update course flags (featured, my-course) or fields. Admin or mentor.
 */
router.put('/:id', requireRole('admin', 'mentor'), async (req, res) => {
  const { id } = req.params;
  const {
    isFeatured,
    isMyCourse,
    title,
    description,
    difficulty,
    category,
    duration,
    modules,
    module_type,
    moduleType,
    thumbnail_url,
    thumbnailUrl,
    instructor_name,
    instructorName,
    mentor_id,
    mentorId,
    rating,
    price,
    quiz_coin_reward,
    quizCoinReward,
    quiz_pass_score,
    quizPassScore,
  } = req.body;

  try {
    const existing = await pool.query('SELECT id, mentor_id FROM courses WHERE id = $1 LIMIT 1', [id]);
    if (existing.rowCount === 0) {
      return res.status(404).json({ message: 'Course not found' });
    }
    // Ownership check: mentors can only edit courses where they are the assigned mentor.
    // If mentor_id is null on the course (admin-created, not yet assigned), block access
    // to be safe — admins bypass this check entirely.
    if (req.user.role === 'mentor') {
      const courseOwnerId = existing.rows[0].mentor_id;
      if (courseOwnerId == null || String(courseOwnerId) !== String(req.user.id)) {
        return res.status(403).json({ message: 'Forbidden: you can only edit your own courses' });
      }
    }

    const updates = [];
    const values = [];

    if (title !== undefined) {
      updates.push('title = $' + (values.length + 1));
      values.push(title);
    }
    if (description !== undefined) {
      updates.push('description = $' + (values.length + 1));
      values.push(description);
    }
    if (difficulty !== undefined) {
      updates.push('difficulty = $' + (values.length + 1));
      values.push(difficulty);
    }
    if (category !== undefined) {
      updates.push('category = $' + (values.length + 1));
      values.push(category);
    }
    if (duration !== undefined) {
      updates.push('duration = $' + (values.length + 1));
      values.push(duration);
    }
    if (moduleType !== undefined || module_type !== undefined) {
      updates.push('module_type = $' + (values.length + 1));
      values.push(moduleType ?? module_type);
    }
    if (modules !== undefined) {
      updates.push('modules = $' + (values.length + 1));
      values.push(JSON.stringify(normalizeModules(modules)));
    }
    if (thumbnailUrl !== undefined || thumbnail_url !== undefined) {
      updates.push('thumbnail_url = $' + (values.length + 1));
      values.push(thumbnailUrl ?? thumbnail_url);
    }
    if (instructorName !== undefined || instructor_name !== undefined) {
      updates.push('instructor_name = $' + (values.length + 1));
      values.push(instructorName ?? instructor_name);
    }
    // Only update mentor_id if a non-null value is explicitly provided.
    // Sending mentor_id: null should not clear the existing owner.
    const newMentorId = mentorId ?? mentor_id;
    if (newMentorId != null && newMentorId !== undefined) {
      updates.push('mentor_id = $' + (values.length + 1));
      values.push(newMentorId);
    }
    if (rating !== undefined) {
      updates.push('rating = $' + (values.length + 1));
      values.push(rating);
    }
    if (price !== undefined) {
      updates.push('price = $' + (values.length + 1));
      values.push(Number(price));
    }
    if (quizCoinReward !== undefined || quiz_coin_reward !== undefined) {
      updates.push('quiz_coin_reward = $' + (values.length + 1));
      values.push(Number(quizCoinReward ?? quiz_coin_reward));
    }
    if (quizPassScore !== undefined || quiz_pass_score !== undefined) {
      updates.push('quiz_pass_score = $' + (values.length + 1));
      values.push(Number(quizPassScore ?? quiz_pass_score));
    }
    if (isFeatured !== undefined) {
      updates.push('is_featured = $' + (values.length + 1));
      values.push(isFeatured);
    }
    if (isMyCourse !== undefined) {
      updates.push('is_my_course = $' + (values.length + 1));
      values.push(isMyCourse);
    }

    if (updates.length === 0) {
      return res.status(400).json({ message: 'No fields to update' });
    }

    values.push(id);
    const query = `UPDATE courses SET ${updates.join(', ')} WHERE id = $${values.length} RETURNING *`;
    const result = await pool.query(query, values);

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Course not found' });
    }

    return res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * DELETE /api/courses/:id
 * Delete a course. Admin only.
 */
router.delete('/:id', requireRole('admin'), async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query('DELETE FROM courses WHERE id = $1 RETURNING id', [id]);

    if (result.rowCount === 0) {
      return res.status(404).json({ message: 'Course not found' });
    }

    return res.json({ message: 'Course deleted' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

function parseJsonArray(value, fallback = []) {
  if (Array.isArray(value)) return value;
  try {
    const parsed = JSON.parse(value || '[]');
    return Array.isArray(parsed) ? parsed : fallback;
  } catch (_) {
    return fallback;
  }
}

async function ensureStudentEnrollment(studentId, courseId) {
  const enrollment = await pool.query(
    `SELECT 1 FROM user_courses WHERE user_id = $1 AND course_id = $2 LIMIT 1`,
    [studentId, courseId],
  );
  return enrollment.rowCount > 0;
}

async function getOrCreateProgressRow(client, studentId, courseId) {
  const inserted = await client.query(
    `INSERT INTO student_course_progress (student_id, course_id)
     VALUES ($1, $2)
     ON CONFLICT (student_id, course_id) DO NOTHING`,
    [studentId, courseId],
  );

  const progress = await client.query(
    `SELECT * FROM student_course_progress
     WHERE student_id = $1 AND course_id = $2
     FOR UPDATE`,
    [studentId, courseId],
  );

  return progress.rows[0];
}

function lessonKeyForModule(moduleNumber, moduleItem) {
  const title = String(moduleItem.lessonTitle || moduleItem.title || '').trim();
  return `${moduleNumber}:${title}`;
}

router.get('/:courseId/progress', requireRole('student', 'mentor', 'admin'), async (req, res) => {
  const { courseId } = req.params;

  try {
    const courseResult = await pool.query('SELECT id, mentor_id FROM courses WHERE id = $1 LIMIT 1', [courseId]);
    if (courseResult.rowCount === 0) {
      return res.status(404).json({ message: 'Course not found' });
    }

    const isStudent = req.user.role === 'student';
    if (isStudent) {
      const enrolled = await ensureStudentEnrollment(req.user.id, courseId);
      if (!enrolled) {
        return res.status(403).json({ message: 'Course access denied' });
      }
    }

    if (req.user.role === 'mentor' && String(courseResult.rows[0].mentor_id || '') !== String(req.user.id)) {
      return res.status(403).json({ message: 'Course access denied' });
    }

    const progressResult = await pool.query(
      `SELECT * FROM student_course_progress WHERE student_id = $1 AND course_id = $2 LIMIT 1`,
      [req.user.id, courseId],
    );

    const courseRow = courseResult.rows[0];
    const modules = normalizeModules(courseRow.modules || []);
    const totalModules = modules.length;
    
    const row = progressResult.rows[0];
    const completedLessons = row ? parseJsonArray(row.completed_lessons, []) : [];
    
    const progressPercentage = totalModules > 0 
      ? Math.min(100, Math.round((completedLessons.length / totalModules) * 100))
      : 0;

    return res.json({
      completed_lessons: completedLessons,
      completed_modules: row ? parseJsonArray(row.completed_modules, []) : [],
      rewarded_modules: row ? parseJsonArray(row.rewarded_modules, []) : [],
      quiz_completed: row ? Boolean(row.quiz_completed) : false,
      quiz_reward_given: row ? Boolean(row.quiz_reward_given) : false,
      quiz_score: row?.quiz_score ?? null,
      progress_percentage: progressPercentage,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

router.post('/:courseId/lessons/complete', requireRole('student'), async (req, res) => {
  const { courseId } = req.params;
  const { module_number, lesson_key } = req.body;
  const studentId = req.user.id;

  if (!module_number || !lesson_key) {
    return res.status(400).json({ message: 'module_number and lesson_key are required' });
  }

  try {
    const enrolled = await ensureStudentEnrollment(studentId, courseId);
    if (!enrolled) {
      return res.status(403).json({ message: 'Course access denied' });
    }

    const courseResult = await pool.query(
      `SELECT id, modules FROM courses WHERE id = $1 LIMIT 1`,
      [courseId],
    );
    if (courseResult.rowCount === 0) {
      return res.status(404).json({ message: 'Course not found' });
    }

    const moduleNumber = Number(module_number);
    const modules = normalizeModules(courseResult.rows[0].modules || []);
    const targetModuleLessons = modules.filter((m) => Number(m.moduleNumber) === moduleNumber);
    if (targetModuleLessons.length === 0) {
      return res.status(404).json({ message: 'Module not found' });
    }

    const expectedLessonKeys = targetModuleLessons.map((m) => lessonKeyForModule(moduleNumber, m));
    if (!expectedLessonKeys.includes(String(lesson_key))) {
      return res.status(400).json({ message: 'Invalid lesson key for module' });
    }

    const moduleReward = Number(targetModuleLessons[0].coinReward || 0);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const progress = await getOrCreateProgressRow(client, studentId, courseId);
      const completedLessons = parseJsonArray(progress.completed_lessons, []).map(String);
      const completedModules = parseJsonArray(progress.completed_modules, []).map((v) => Number(v));
      const rewardedModules = parseJsonArray(progress.rewarded_modules, []).map((v) => Number(v));

      let rewardGranted = 0;
      let moduleCompletedNow = false;

      if (!completedLessons.includes(String(lesson_key))) {
        completedLessons.push(String(lesson_key));
      }

      const moduleIsComplete = expectedLessonKeys.every((k) => completedLessons.includes(k));
      if (moduleIsComplete && !completedModules.includes(moduleNumber)) {
        completedModules.push(moduleNumber);
        moduleCompletedNow = true;
      }

      if (moduleIsComplete && moduleReward > 0 && !rewardedModules.includes(moduleNumber)) {
        rewardedModules.push(moduleNumber);
        rewardGranted = moduleReward;
        await client.query(
          `UPDATE users SET coins = COALESCE(coins, 0) + $2, updated_at = NOW() WHERE id = $1`,
          [studentId, moduleReward],
        );
      }

      await client.query(
        `UPDATE student_course_progress
         SET completed_lessons = $3::jsonb,
             completed_modules = $4::jsonb,
             rewarded_modules = $5::jsonb,
             updated_at = NOW()
         WHERE student_id = $1 AND course_id = $2`,
        [
          studentId,
          courseId,
          JSON.stringify(completedLessons),
          JSON.stringify(completedModules),
          JSON.stringify(rewardedModules),
        ],
      );

      const userCoins = await client.query('SELECT coins FROM users WHERE id = $1', [studentId]);

      await client.query('COMMIT');

      return res.json({
        module_completed_now: moduleCompletedNow,
        reward_granted: rewardGranted,
        completed_lessons: completedLessons,
        completed_modules: completedModules,
        rewarded_modules: rewardedModules,
        coins: Number(userCoins.rows[0]?.coins || 0),
      });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

router.post('/:courseId/quiz/complete', requireRole('student'), async (req, res) => {
  const { courseId } = req.params;
  const { score, total } = req.body;
  const studentId = req.user.id;

  try {
    const enrolled = await ensureStudentEnrollment(studentId, courseId);
    if (!enrolled) {
      return res.status(403).json({ message: 'Course access denied' });
    }

    const courseResult = await pool.query(
      `SELECT id, modules, quiz_coin_reward, quiz_pass_score FROM courses WHERE id = $1 LIMIT 1`,
      [courseId],
    );
    if (courseResult.rowCount === 0) {
      return res.status(404).json({ message: 'Course not found' });
    }

    const course = courseResult.rows[0];
    const modules = normalizeModules(course.modules || []);
    const quizCount = modules.reduce((sum, m) => sum + (Array.isArray(m.quizQuestions) ? m.quizQuestions.length : 0), 0);
    if (quizCount < 20) {
      return res.status(400).json({ message: 'Quiz requires at least 20 questions' });
    }

    const parsedScore = Number(score || 0);
    const parsedTotal = Number(total || 0);
    const passScore = Number(course.quiz_pass_score || 0);
    const passed = passScore > 0 ? parsedScore >= passScore : parsedScore > 0;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const progress = await getOrCreateProgressRow(client, studentId, courseId);

      let rewardGranted = 0;
      const alreadyRewarded = Boolean(progress.quiz_reward_given);
      if (passed && !alreadyRewarded && Number(course.quiz_coin_reward || 0) > 0) {
        rewardGranted = Number(course.quiz_coin_reward);
        await client.query(
          `UPDATE users SET coins = COALESCE(coins, 0) + $2, updated_at = NOW() WHERE id = $1`,
          [studentId, rewardGranted],
        );
      }

      await client.query(
        `UPDATE student_course_progress
         SET quiz_completed = TRUE,
             quiz_reward_given = CASE WHEN quiz_reward_given = TRUE THEN TRUE ELSE $3 END,
             quiz_score = $4,
             updated_at = NOW()
         WHERE student_id = $1 AND course_id = $2`,
        [studentId, courseId, passed && rewardGranted > 0, parsedScore],
      );

      const userCoins = await client.query('SELECT coins FROM users WHERE id = $1', [studentId]);

      await client.query('COMMIT');

      return res.json({
        passed,
        reward_granted: rewardGranted,
        quiz_completed: true,
        coins: Number(userCoins.rows[0]?.coins || 0),
        score: parsedScore,
        total: parsedTotal,
      });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * POST /api/courses/:courseId/assign
 * Compatibility route: assign a course to a user.
 * Body: { user_id } or { userId }
 */
router.post('/:courseId/assign', requireRole('admin'), async (req, res) => {
  const { courseId } = req.params;
  const { user_id, userId } = req.body;
  const uid = userId || user_id;

  if (!uid) {
    return res.status(400).json({ message: 'user_id is required' });
  }

  try {
    const userCheck = await pool.query(
      'SELECT id, role FROM users WHERE id = $1',
      [uid],
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

    await pool.query(
      `INSERT INTO user_courses (user_id, course_id)
       VALUES ($1, $2)
       ON CONFLICT (user_id, course_id) DO NOTHING`,
      [uid, courseId],
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
      [courseId, uid],
    );

    return res.status(201).json({ message: 'Course assigned' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
