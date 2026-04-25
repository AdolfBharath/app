const express = require('express');
const { authenticate, requireRole } = require('../middleware/auth');
const {
  completeActivity,
  processLogin,
  reconcileUserStreakForToday,
  getWeeklyStats,
} = require('../services/streak_service');

const router = express.Router();

router.use(authenticate);

function resolveTargetUserId(req, res) {
  const requested = req.body?.user_id || req.query?.user_id;
  if (!requested) return req.user.id;

  // Non-admins can only act on themselves.
  if (req.user.role !== 'admin' && String(requested) !== String(req.user.id)) {
    res.status(403).json({ message: 'Forbidden: cannot operate on another user' });
    return null;
  }

  return requested;
}

/**
 * POST /api/activity/complete
 * Body: { user_id?, xp_earned, event_timestamp?, metadata? }
 */
router.post('/activity/complete', requireRole('student', 'mentor', 'admin'), async (req, res) => {
  const userId = resolveTargetUserId(req, res);
  if (!userId) return;

  const xpEarned = Math.min(Number(req.body?.xp_earned || 0), 500); // Cap XP per activity to prevent massive abuse
  if (!Number.isFinite(xpEarned) || xpEarned < 0) {
    return res.status(400).json({ message: 'xp_earned must be a non-negative number' });
  }

  try {
    const result = await completeActivity({
      actingUser: req.user.id,
      targetUserId: userId,
      xpEarned,
      eventTimestamp: req.body?.event_timestamp,
      metadata: req.body?.metadata,
    });
    return res.json(result);
  } catch (err) {
    console.error('[STREAK] activity complete failed:', err.message);
    if (err.message === 'User not found') {
      return res.status(404).json({ message: err.message });
    }
    if (err.message.includes('timestamp') || err.message.includes('Activity date')) {
      return res.status(400).json({ message: err.message });
    }
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * GET /api/streak?user_id=
 */
router.get('/streak', requireRole('student', 'mentor', 'admin'), async (req, res) => {
  const requested = req.query?.user_id;
  const userId = requested || req.user.id;

  if (req.user.role !== 'admin' && String(userId) !== String(req.user.id)) {
    return res.status(403).json({ message: 'Forbidden: cannot view another user streak' });
  }

  try {
    const streak = await reconcileUserStreakForToday(userId);
    return res.json({
      streak_count: streak.streak_count,
      last_active_date: streak.last_active_date,
      streak_freeze_count: streak.streak_freeze_count,
    });
  } catch (err) {
    console.error('[STREAK] get streak failed:', err.message);
    if (err.message === 'User not found') {
      return res.status(404).json({ message: err.message });
    }
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * GET /api/weekly-stats?user_id=
 */
router.get('/weekly-stats', requireRole('student', 'mentor', 'admin'), async (req, res) => {
  const requested = req.query?.user_id;
  const userId = requested || req.user.id;

  if (req.user.role !== 'admin' && String(userId) !== String(req.user.id)) {
    return res.status(403).json({ message: 'Forbidden: cannot view another user stats' });
  }

  try {
    const weekly = await getWeeklyStats(userId);
    return res.json(weekly);
  } catch (err) {
    console.error('[STREAK] get weekly stats failed:', err.message);
    if (err.message === 'User not found') {
      return res.status(404).json({ message: err.message });
    }
    return res.status(500).json({ message: 'Server error' });
  }
});

/**
 * POST /api/login
 * Daily login tracking endpoint for authenticated users.
 */
router.post('/login', requireRole('student', 'mentor', 'admin'), async (req, res) => {
  const userId = resolveTargetUserId(req, res);
  if (!userId) return;

  try {
    const result = await processLogin(userId, {
      source: 'app_login',
      client: req.body?.client || 'unknown',
    });
    return res.json(result);
  } catch (err) {
    console.error('[STREAK] login tracking failed:', err.message);
    if (err.message === 'User not found') {
      return res.status(404).json({ message: err.message });
    }
    return res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
