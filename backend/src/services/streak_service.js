const { pool } = require('../db');

const MAX_OFFLINE_HOURS = Number(process.env.STREAK_MAX_OFFLINE_HOURS || 36);

function isValidTimezone(timezone) {
  if (!timezone || typeof timezone !== 'string') return false;
  try {
    Intl.DateTimeFormat('en-US', { timeZone: timezone }).format(new Date());
    return true;
  } catch (_) {
    return false;
  }
}

function normalizeTimezone(timezone) {
  if (isValidTimezone(timezone)) return timezone;
  return 'UTC';
}

function dateKeyInTimezone(date, timezone) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: normalizeTimezone(timezone),
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
}

function parseDateKey(dateKey) {
  return new Date(`${dateKey}T00:00:00.000Z`);
}

function addDays(dateKey, days) {
  const date = parseDateKey(dateKey);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function dayDiff(fromDateKey, toDateKey) {
  const from = parseDateKey(fromDateKey);
  const to = parseDateKey(toDateKey);
  return Math.floor((to.getTime() - from.getTime()) / 86400000);
}

function normalizeActionTimestamp(rawTimestamp) {
  const now = new Date();
  if (!rawTimestamp) return now;

  const parsed = new Date(rawTimestamp);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error('Invalid event timestamp');
  }

  // Anti-cheat guard: reject far future timestamps.
  if (parsed.getTime() > now.getTime() + 5 * 60 * 1000) {
    throw new Error('Event timestamp is in the future');
  }

  // Offline support with bounded window to avoid arbitrary backdating.
  if (parsed.getTime() < now.getTime() - MAX_OFFLINE_HOURS * 60 * 60 * 1000) {
    throw new Error(`Event timestamp is too old (max ${MAX_OFFLINE_HOURS}h offline window)`);
  }

  return parsed;
}

function applyGapWithFreeze({ streakCount, freezeCount, lastActiveDate, targetDate }) {
  if (!lastActiveDate) {
    return { streakCount, freezeCount, streakBroken: false, freezeUsed: 0 };
  }

  const days = dayDiff(lastActiveDate, targetDate);
  if (days <= 1) {
    return { streakCount, freezeCount, streakBroken: false, freezeUsed: 0 };
  }

  const missedDays = days - 1;
  const usableFreezes = Math.max(0, freezeCount || 0);
  const freezeUsed = Math.min(usableFreezes, missedDays);
  const remainingMisses = missedDays - freezeUsed;

  return {
    streakCount: remainingMisses > 0 ? 0 : streakCount,
    freezeCount: usableFreezes - freezeUsed,
    streakBroken: remainingMisses > 0,
    freezeUsed,
  };
}

async function ensureUserForUpdate(client, userId) {
  const result = await client.query(
    `SELECT id, streak_count, last_active_date, coins, streak_freeze_count, timezone, last_rewarded_date, weekly_logins
     FROM users
     WHERE id = $1
     FOR UPDATE`,
    [userId],
  );

  if (result.rowCount === 0) {
    throw new Error('User not found');
  }

  const row = result.rows[0];
  return {
    id: row.id,
    streakCount: Number(row.streak_count || 0),
    lastActiveDate: row.last_active_date ? row.last_active_date.toISOString().slice(0, 10) : null,
    coins: Number(row.coins || 0),
    streakFreezeCount: Number(row.streak_freeze_count || 0),
    timezone: normalizeTimezone(row.timezone),
    lastRewardedDate: row.last_rewarded_date ? row.last_rewarded_date.toISOString().slice(0, 10) : null,
    weeklyLogins: Array.isArray(row.weekly_logins) ? row.weekly_logins : [false, false, false, false, false, false, false],
  };
}

async function upsertDailyActivity(client, { userId, dateKey, xpEarned }) {
  const existing = await client.query(
    `SELECT id, activity_completed, xp_earned
     FROM daily_activity
     WHERE user_id = $1 AND activity_date = $2
     FOR UPDATE`,
    [userId, dateKey],
  );

  if (existing.rowCount > 0) {
    const row = existing.rows[0];
    await client.query(
      `UPDATE daily_activity
       SET xp_earned = COALESCE(xp_earned, 0) + $2,
           activity_completed = TRUE,
           updated_at = NOW()
       WHERE id = $1`,
      [row.id, xpEarned],
    );
    return { alreadyCompleted: Boolean(row.activity_completed) };
  }

  await client.query(
    `INSERT INTO daily_activity (user_id, activity_date, xp_earned, activity_completed)
     VALUES ($1, $2, $3, TRUE)`,
    [userId, dateKey, xpEarned],
  );
  return { alreadyCompleted: false };
}

async function logEvent(client, { userId, eventType, timestamp, metadata }) {
  await client.query(
    `INSERT INTO events (user_id, event_type, event_timestamp, metadata)
     VALUES ($1, $2, $3, $4::jsonb)`,
    [userId, eventType, timestamp.toISOString(), JSON.stringify(metadata || {})],
  );
}

async function completeActivity({ actingUser, targetUserId, xpEarned, eventTimestamp, metadata }) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const user = await ensureUserForUpdate(client, targetUserId);

    const safeTimestamp = normalizeActionTimestamp(eventTimestamp);
    const actionDate = dateKeyInTimezone(safeTimestamp, user.timezone);
    const todayDate = dateKeyInTimezone(new Date(), user.timezone);

    const earliestAllowed = addDays(todayDate, -1);
    if (actionDate < earliestAllowed || actionDate > todayDate) {
      throw new Error('Activity date is outside allowed range');
    }

    const gapAdjusted = applyGapWithFreeze({
      streakCount: user.streakCount,
      freezeCount: user.streakFreezeCount,
      lastActiveDate: user.lastActiveDate,
      targetDate: actionDate,
    });

    let streakCount = gapAdjusted.streakCount;
    let freezeCount = gapAdjusted.freezeCount;
    let coins = user.coins;
    let lastRewardedDate = user.lastRewardedDate;

    const daily = await upsertDailyActivity(client, {
      userId: targetUserId,
      dateKey: actionDate,
      xpEarned: Math.max(0, Number(xpEarned || 0)),
    });

    if (!daily.alreadyCompleted) {
      const lastActive = user.lastActiveDate;
      if (!lastActive) {
        streakCount = 1;
      } else {
        const diff = dayDiff(lastActive, actionDate);
        if (diff === 0) {
          // already counted today through another synced event, keep value
        } else if (diff === 1) {
          streakCount += 1;
        } else if (!gapAdjusted.streakBroken && streakCount > 0) {
          // Freeze covered skipped days, continue streak.
          streakCount += 1;
        } else {
          streakCount = 1;
        }
      }

      if (actionDate === todayDate && lastRewardedDate !== todayDate) {
        coins += 1;
        lastRewardedDate = todayDate;
      }
    }

    const nextLastActive =
      !user.lastActiveDate || dayDiff(user.lastActiveDate, actionDate) >= 0
        ? actionDate
        : user.lastActiveDate;

    await client.query(
      `UPDATE users
       SET streak_count = $2,
           last_active_date = $3,
           coins = $4,
           streak_freeze_count = $5,
           last_rewarded_date = $6,
           updated_at = NOW()
       WHERE id = $1`,
      [targetUserId, streakCount, nextLastActive, coins, freezeCount, lastRewardedDate],
    );

    await logEvent(client, {
      userId: targetUserId,
      eventType: 'activity_complete',
      timestamp: safeTimestamp,
      metadata: {
        xp_earned: Math.max(0, Number(xpEarned || 0)),
        source_user_id: actingUser,
        ...metadata,
      },
    });

    await client.query('COMMIT');

    return {
      streak_count: streakCount,
      coins,
      streak_freeze_count: freezeCount,
      last_active_date: nextLastActive,
      daily_reward_granted: !daily.alreadyCompleted && actionDate === todayDate && lastRewardedDate === todayDate,
      already_completed_today: daily.alreadyCompleted && actionDate === todayDate,
    };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function reconcileUserStreakForToday(userId) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const user = await ensureUserForUpdate(client, userId);
    const today = dateKeyInTimezone(new Date(), user.timezone);

    const adjusted = applyGapWithFreeze({
      streakCount: user.streakCount,
      freezeCount: user.streakFreezeCount,
      lastActiveDate: user.lastActiveDate,
      targetDate: today,
    });

    if (adjusted.streakCount !== user.streakCount || adjusted.freezeCount !== user.streakFreezeCount) {
      await client.query(
        `UPDATE users
         SET streak_count = $2,
             streak_freeze_count = $3,
             updated_at = NOW()
         WHERE id = $1`,
        [userId, adjusted.streakCount, adjusted.freezeCount],
      );
    }

    await client.query('COMMIT');

    return {
      streak_count: adjusted.streakCount,
      last_active_date: user.lastActiveDate,
      streak_freeze_count: adjusted.freezeCount,
      coins: user.coins,
      timezone: user.timezone,
      last_rewarded_date: user.lastRewardedDate,
      weekly_logins: user.weeklyLogins,
      today,
    };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function processLogin(userId, metadata = {}) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const user = await ensureUserForUpdate(client, userId);
    const today = dateKeyInTimezone(new Date(), user.timezone);
    const dayIndex = (new Date().getDay() + 6) % 7; // Mon = 0, Sun = 6

    let streakCount = user.streakCount;
    let coins = user.coins;
    let lastRewardedDate = user.lastRewardedDate;
    let weeklyLogins = [...user.weeklyLogins];
    let lastActiveDate = user.lastActiveDate;

    // Reset weeklyLogins if it's a new week (Monday)
    // Actually, a better way is to check if 'today' is before 'lastActiveDate' week-wise
    // But for simplicity, let's just use the user's logic or a improved version.
    // If diff > 7, definitely reset. If current day is Monday and last active wasn't today, reset.
    if (new Date().getDay() === 1 && lastActiveDate !== today) {
      weeklyLogins = [false, false, false, false, false, false, false];
    }

    if (lastActiveDate !== today) {
      if (!lastActiveDate) {
        streakCount = 1;
      } else {
        const diff = dayDiff(lastActiveDate, today);
        if (diff === 1) {
          streakCount += 1;
        } else if (diff > 1) {
          streakCount = 1;
          weeklyLogins = [false, false, false, false, false, false, false];
        } else {
          // diff < 0 (clock skew) or diff 0 (handled above)
          streakCount = 1;
        }
      }
      
      lastActiveDate = today;
      weeklyLogins[dayIndex] = true;

      // Award coin if not rewarded today
      if (lastRewardedDate !== today) {
        coins += 1;
        lastRewardedDate = today;
      }

      await client.query(
        `UPDATE users
         SET streak_count = $2,
             last_active_date = $3,
             coins = $4,
             last_rewarded_date = $5,
             weekly_logins = $6,
             updated_at = NOW()
         WHERE id = $1`,
        [userId, streakCount, lastActiveDate, coins, lastRewardedDate, JSON.stringify(weeklyLogins)],
      );
    }

    await logEvent(client, {
      userId,
      eventType: 'login',
      timestamp: new Date(),
      metadata,
    });

    await client.query('COMMIT');

    return {
      streak_count: streakCount,
      last_active_date: lastActiveDate,
      coins,
      weekly_logins: weeklyLogins,
      reward_granted: lastRewardedDate === today && user.lastRewardedDate !== today,
      today,
    };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function getWeeklyStats(userId) {
  const streak = await reconcileUserStreakForToday(userId);
  const start = addDays(streak.today, -6);

  const result = await pool.query(
    `SELECT COUNT(*)::int AS active_days
     FROM daily_activity
     WHERE user_id = $1
       AND activity_completed = TRUE
       AND activity_date BETWEEN $2 AND $3`,
    [userId, start, streak.today],
  );

  const activeDays = Number(result.rows[0]?.active_days || 0);

  return {
    active_days_last_7: activeDays,
    perfect_week: activeDays === 7,
  };
}

module.exports = {
  completeActivity,
  processLogin,
  reconcileUserStreakForToday,
  getWeeklyStats,
  normalizeTimezone,
};
