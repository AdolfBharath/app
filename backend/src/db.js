const { Pool } = require('pg');
const dotenv = require('dotenv');

dotenv.config();

const connectionString = process.env.DATABASE_URL;

let pool;

if (connectionString) {
  // Single DATABASE_URL string
  pool = new Pool({ connectionString });
} else {
  // Host/port/db config from individual env vars
  pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 5432),
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'postgres',
  });
}

console.log('[DB] Connection config:', {
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'postgres',
  database: process.env.DB_NAME || 'postgres',
});

// Test connection immediately
pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('[DB] ✗ Connection failed:', err.message);
  } else {
    console.log('[DB] ✓ Database connection successful');
  }
});

async function initDb() {
  console.log('[DB] Initializing database...');
  
  try {
    // Ensure UUID generator is available.
    await pool.query(`CREATE EXTENSION IF NOT EXISTS pgcrypto;`);
    console.log('[DB] ✓ pgcrypto extension ready');

    // Create users table if it doesn't exist.
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL
      );
    `);
    console.log('[DB] ✓ users table created/verified');

    // Ensure newer columns exist even if an older users table was already created.
    await pool.query(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash TEXT;`,
    );
    console.log('[DB] ✓ password_hash column ready');
    
    await pool.query(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'student';`,
    );
    console.log('[DB] ✓ role column ready');
    
    await pool.query(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();`,
    );
    console.log('[DB] ✓ created_at column ready');

    // Optional profile fields for admin UI.
    await pool.query(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS username TEXT;`,
    );
    await pool.query(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS admin_no TEXT;`,
    );
    await pool.query(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS phone TEXT;`,
    );
    console.log('[DB] ✓ profile columns ready');

    // Drop any legacy "password" column that may still exist and conflict
    // with the newer password_hash-based authentication.
    await pool.query(
      `ALTER TABLE users DROP COLUMN IF EXISTS password;`,
    );
    console.log('[DB] ✓ legacy columns cleaned');

    // Clean up any legacy foreign keys/columns that referenced users.id as an integer
    // (for example, courses.created_by) so that we can safely migrate users.id to UUID.
    await pool.query(`
      DO $$
      BEGIN
        IF EXISTS (
          SELECT 1 FROM information_schema.tables WHERE table_name = 'courses'
        ) THEN
          ALTER TABLE courses DROP CONSTRAINT IF EXISTS courses_created_by_fkey;
          ALTER TABLE courses DROP COLUMN IF EXISTS created_by;
        END IF;
      END$$;
    `);

    // If an older users table exists with a non-UUID id column, migrate it to UUID
    // so that new foreign keys using UUIDs can be created safely.
    await pool.query(`
      DO $$
      BEGIN
        IF EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_name = 'users'
            AND column_name = 'id'
            AND data_type <> 'uuid'
        ) THEN
          ALTER TABLE users ALTER COLUMN id DROP DEFAULT;
          ALTER TABLE users
            ALTER COLUMN id TYPE uuid USING gen_random_uuid();
          ALTER TABLE users ALTER COLUMN id SET DEFAULT gen_random_uuid();
        END IF;
      END$$;
    `);
    console.log('[DB] ✓ UUID migration complete');

    await pool.query(`
      CREATE TABLE IF NOT EXISTS courses (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        instructor_name TEXT NOT NULL,
        module_type TEXT NOT NULL DEFAULT 'Self-paced',
        thumbnail_url TEXT,
        rating NUMERIC(2,1) DEFAULT 4.5,
        difficulty TEXT NOT NULL,
        modules JSONB DEFAULT '[]'::jsonb,
        is_featured BOOLEAN DEFAULT FALSE,
        is_my_course BOOLEAN DEFAULT FALSE,
        mentor_id UUID REFERENCES users(id) ON DELETE SET NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    console.log('[DB] ✓ courses table created/verified');

    // Ensure newer course columns exist even if an older courses table
    // was created without them.
    await pool.query(
      `ALTER TABLE courses ADD COLUMN IF NOT EXISTS module_type TEXT NOT NULL DEFAULT 'Self-paced';`,
    );
    await pool.query(
      `ALTER TABLE courses ADD COLUMN IF NOT EXISTS rating NUMERIC(2,1) DEFAULT 4.5;`,
    );
    await pool.query(
      `ALTER TABLE courses ADD COLUMN IF NOT EXISTS difficulty TEXT NOT NULL DEFAULT 'intermediate';`,
    );
    await pool.query(
      `ALTER TABLE courses ADD COLUMN IF NOT EXISTS modules JSONB DEFAULT '[]'::jsonb;`,
    );
    await pool.query(
      `ALTER TABLE courses ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT FALSE;`,
    );
    await pool.query(
      `ALTER TABLE courses ADD COLUMN IF NOT EXISTS is_my_course BOOLEAN DEFAULT FALSE;`,
    );
    await pool.query(
      `ALTER TABLE courses ADD COLUMN IF NOT EXISTS mentor_id UUID REFERENCES users(id) ON DELETE SET NULL;`,
    );
    await pool.query(
      `ALTER TABLE courses ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'Development';`,
    );
    await pool.query(
      `ALTER TABLE courses ADD COLUMN IF NOT EXISTS duration TEXT DEFAULT '';`,
    );
    await pool.query(
      `ALTER TABLE courses ADD COLUMN IF NOT EXISTS price NUMERIC(10,2) DEFAULT 0.00;`,
    );
    await pool.query(
      `ALTER TABLE courses ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Published';`,
    );
    console.log('[DB] ✓ courses columns ready');

    // If an older courses table exists with a non-UUID id column, migrate it to UUID
    // so that batches.course_id (UUID) can reference it.
    await pool.query(`
      DO $$
      BEGIN
        IF EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_name = 'courses'
            AND column_name = 'id'
            AND data_type <> 'uuid'
        ) THEN
          ALTER TABLE courses ALTER COLUMN id DROP DEFAULT;
          ALTER TABLE courses
            ALTER COLUMN id TYPE uuid USING gen_random_uuid();
          ALTER TABLE courses ALTER COLUMN id SET DEFAULT gen_random_uuid();
        END IF;
      END$$;
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS batches (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name TEXT NOT NULL,
        course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
        mentor_id UUID REFERENCES users(id) ON DELETE SET NULL,
        capacity INTEGER,
        enroll_limit INTEGER,
        smart_waitlist BOOLEAN DEFAULT FALSE,
        status TEXT NOT NULL DEFAULT 'draft',
        start_date TIMESTAMPTZ,
        end_date TIMESTAMPTZ,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    console.log('[DB] ✓ batches table created/verified');

    await pool.query(
      `ALTER TABLE batches ADD COLUMN IF NOT EXISTS start_date TIMESTAMPTZ;`,
    );
    await pool.query(
      `ALTER TABLE batches ADD COLUMN IF NOT EXISTS end_date TIMESTAMPTZ;`,
    );

    // Optional mapping hint for frontend: a user's latest/primary batch.
    // Added after batches table is guaranteed to exist.
    await pool.query(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS batch_id UUID REFERENCES batches(id) ON DELETE SET NULL;`,
    );

    // Mapping table between users and courses for assignments.
    await pool.query(`
      CREATE TABLE IF NOT EXISTS user_courses (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE (user_id, course_id)
      );
    `);
    console.log('[DB] ✓ user_courses table created/verified');

    // Dedicated batch-student mapping table for clean, O(1) batch-scoped queries.
    // Backfilled from user_courses on every boot so it stays consistent.
    await pool.query(`
      CREATE TABLE IF NOT EXISTS batch_students (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        batch_id UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
        student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        enrolled_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE (batch_id, student_id)
      );
    `);
    console.log('[DB] ✓ batch_students table created/verified');

    // Backfill batch_students from existing user_courses enrollments.
    await pool.query(`
      INSERT INTO batch_students (batch_id, student_id, enrolled_at)
      SELECT DISTINCT b.id, uc.user_id, uc.created_at
      FROM user_courses uc
      JOIN batches b ON b.course_id = uc.course_id
      JOIN users u   ON u.id = uc.user_id AND u.role = 'student'
      ON CONFLICT (batch_id, student_id) DO NOTHING;
    `);
    console.log('[DB] ✓ batch_students backfill complete');

    // Batch chat (Reddit-style discussion)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS batch_chat_posts (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        batch_id UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
        author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        content TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        deleted_at TIMESTAMPTZ,
        deleted_by UUID REFERENCES users(id) ON DELETE SET NULL
      );
    `);

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_batch_chat_posts_batch_created
      ON batch_chat_posts (batch_id, created_at DESC);
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS batch_chat_replies (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        post_id UUID NOT NULL REFERENCES batch_chat_posts(id) ON DELETE CASCADE,
        author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        parent_reply_id UUID REFERENCES batch_chat_replies(id) ON DELETE CASCADE,
        content TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        deleted_at TIMESTAMPTZ,
        deleted_by UUID REFERENCES users(id) ON DELETE SET NULL
      );
    `);

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_batch_chat_replies_post_created
      ON batch_chat_replies (post_id, created_at ASC);
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS batch_chat_bans (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        batch_id UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        banned_by UUID REFERENCES users(id) ON DELETE SET NULL,
        reason TEXT,
        active BOOLEAN NOT NULL DEFAULT TRUE,
        banned_at TIMESTAMPTZ DEFAULT NOW(),
        unbanned_at TIMESTAMPTZ,
        UNIQUE (batch_id, user_id)
      );
    `);

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_batch_chat_bans_batch_active
      ON batch_chat_bans (batch_id, active);
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS batch_chat_post_votes (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        post_id UUID NOT NULL REFERENCES batch_chat_posts(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE (post_id, user_id)
      );
    `);

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_batch_chat_votes_post
      ON batch_chat_post_votes (post_id);
    `);

    console.log('[DB] ✓ batch chat tables created/verified');

    // Project review table used by admin dashboard review flows.
    await pool.query(`
      CREATE TABLE IF NOT EXISTS projects (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        batch_id UUID REFERENCES batches(id) ON DELETE SET NULL,
        file_urls JSONB NOT NULL DEFAULT '[]'::jsonb,
        status TEXT NOT NULL DEFAULT 'pending',
        review_notes TEXT,
        reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
        reviewed_date TIMESTAMPTZ,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    console.log('[DB] ✓ projects table created/verified');

    // Batch task and submission system (mentor/admin create, students submit).
    await pool.query(`
      CREATE TABLE IF NOT EXISTS batch_tasks (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        batch_id UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        file_url TEXT,
        drive_link TEXT,
        deadline TIMESTAMPTZ,
        created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    await pool.query(
      `ALTER TABLE batch_tasks ADD COLUMN IF NOT EXISTS drive_link TEXT;`,
    );

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_batch_tasks_batch_created
      ON batch_tasks (batch_id, created_at DESC);
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS task_submissions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        task_id UUID NOT NULL REFERENCES batch_tasks(id) ON DELETE CASCADE,
        student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        file_url TEXT,
        file_type TEXT,
        drive_link TEXT,
        submitted_at TIMESTAMPTZ DEFAULT NOW(),
        status TEXT NOT NULL DEFAULT 'pending',
        feedback TEXT,
        reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
        reviewed_at TIMESTAMPTZ,
        is_late BOOLEAN NOT NULL DEFAULT FALSE,
        student_done BOOLEAN NOT NULL DEFAULT FALSE,
        done_at TIMESTAMPTZ,
        UNIQUE (task_id, student_id),
        CONSTRAINT task_submissions_status_check CHECK (status IN ('pending', 'validated', 'rejected'))
      );
    `);

    await pool.query(
      `ALTER TABLE task_submissions ADD COLUMN IF NOT EXISTS is_late BOOLEAN NOT NULL DEFAULT FALSE;`,
    );
    await pool.query(
      `ALTER TABLE task_submissions ADD COLUMN IF NOT EXISTS file_type TEXT;`,
    );
    await pool.query(
      `ALTER TABLE task_submissions ADD COLUMN IF NOT EXISTS student_done BOOLEAN NOT NULL DEFAULT FALSE;`,
    );
    await pool.query(
      `ALTER TABLE task_submissions ADD COLUMN IF NOT EXISTS done_at TIMESTAMPTZ;`,
    );

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_task_submissions_task
      ON task_submissions (task_id, submitted_at DESC);
    `);

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_task_submissions_student
      ON task_submissions (student_id, submitted_at DESC);
    `);
    console.log('[DB] ✓ task tables created/verified');

    // Notification and announcement feed for student/mentor/admin experiences.
    await pool.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        title TEXT NOT NULL DEFAULT 'Notification',
        message TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'announcement',
        target_group TEXT NOT NULL,
        batch_id UUID REFERENCES batches(id) ON DELETE CASCADE,
        sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
        sender_role TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    console.log('[DB] ✓ notifications table created/verified');

    await pool.query(
      `ALTER TABLE notifications ADD COLUMN IF NOT EXISTS title TEXT NOT NULL DEFAULT 'Notification';`,
    );
    await pool.query(
      `ALTER TABLE notifications ADD COLUMN IF NOT EXISTS sender_role TEXT;`,
    );
    await pool.query(
      `ALTER TABLE notifications ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'announcement';`,
    );
    await pool.query(
      `ALTER TABLE notifications ADD COLUMN IF NOT EXISTS target_group TEXT NOT NULL DEFAULT 'both';`,
    );
    await pool.query(
      `ALTER TABLE notifications ADD COLUMN IF NOT EXISTS batch_id UUID REFERENCES batches(id) ON DELETE CASCADE;`,
    );
    await pool.query(
      `CREATE INDEX IF NOT EXISTS idx_notifications_target_created ON notifications (target_group, created_at DESC);`,
    );
    await pool.query(
      `CREATE INDEX IF NOT EXISTS idx_notifications_batch_created ON notifications (batch_id, created_at DESC);`,
    );
    console.log('[DB] ✓ notifications columns ready');

    console.log('[DB] ✓ All tables initialized successfully');
  } catch (err) {
    console.error('[DB] ✗ Initialization error:', err.message);
    throw err;
  }
}

module.exports = {
  pool,
  initDb,
};
