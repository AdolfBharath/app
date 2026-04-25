const nodemailer = require('nodemailer');

let cachedTransporter = null;

function parseBool(value, fallback = false) {
  if (value == null) return fallback;
  const v = String(value).trim().toLowerCase();
  if (v === 'true' || v === '1' || v === 'yes') return true;
  if (v === 'false' || v === '0' || v === 'no') return false;
  return fallback;
}

function isEmailServiceConfigured() {
  const smtpUser = process.env.SMTP_USER;
  const smtpPass = process.env.SMTP_PASS;
  const hasService = !!process.env.SMTP_SERVICE;
  const hasHost = !!process.env.SMTP_HOST;
  return Boolean(smtpUser && smtpPass && (hasService || hasHost));
}

function getTransporter() {
  if (cachedTransporter) return cachedTransporter;
  if (!isEmailServiceConfigured()) return null;

  const smtpUser = process.env.SMTP_USER;
  const smtpPass = process.env.SMTP_PASS;
  const smtpService = process.env.SMTP_SERVICE;
  const smtpHost = process.env.SMTP_HOST;
  const smtpPort = Number(process.env.SMTP_PORT || 587);
  const smtpSecure = parseBool(process.env.SMTP_SECURE, smtpPort === 465);

  const transportConfig = smtpService
    ? { service: smtpService, auth: { user: smtpUser, pass: smtpPass } }
    : { host: smtpHost, port: smtpPort, secure: smtpSecure, auth: { user: smtpUser, pass: smtpPass } };

  cachedTransporter = nodemailer.createTransport(transportConfig);
  return cachedTransporter;
}

/**
 * Create a one-off transporter using admin-supplied credentials.
 * NOT cached — each call creates a fresh transporter so different
 * sender addresses don't bleed into each other.
 */
function createDynamicTransporter(senderEmail, senderPassword) {
  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: senderEmail.trim(),
      pass: senderPassword.trim(),
    },
  });
}

function escapeHtml(input) {
  return String(input ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/** Build course-list HTML block. Returns '' when no courses. */
function buildCoursesBlock(courseNames = []) {
  if (!Array.isArray(courseNames) || courseNames.length === 0) return '';
  const items = courseNames
    .map((n) => `<li style="margin-bottom:4px">${escapeHtml(n)}</li>`)
    .join('\n');
  return `
    <p style="margin-top:20px"><strong>Assigned Course(s):</strong></p>
    <ul style="margin:0;padding-left:20px;color:#374151">${items}</ul>
  `;
}

/** Build the full branded welcome HTML email. */
function buildWelcomeHtml({ safeName, safeEmail, safeRole, safePassword, safeLoginUrl, courseNames }) {
  const coursesBlock = buildCoursesBlock(courseNames);
  return `
    <div style="font-family:'Inter','Segoe UI',system-ui,sans-serif;max-width:520px;margin:0 auto;padding:36px 28px;background:#ffffff;border-radius:16px;border:1px solid #E5E7EB">
      <div style="margin-bottom:24px">
        <h2 style="color:#1F2937;margin:0 0 4px">Welcome to Jenovate LMS 🎉</h2>
        <p style="color:#6B7280;font-size:13px;margin:0">Your account is ready. Let's get started!</p>
      </div>
      <p style="color:#374151;font-size:15px">Hello <strong>${safeName}</strong>,</p>
      <p style="color:#374151;font-size:14px">Your account has been successfully created by an administrator. Here are your login details:</p>
      <div style="background:#F9FAFB;border:1px solid #E5E7EB;border-radius:12px;padding:20px;margin:20px 0">
        <table style="width:100%;border-collapse:collapse;font-size:14px">
          <tr><td style="padding:6px 0;color:#6B7280;width:140px">Email</td><td style="color:#111827;font-weight:600">${safeEmail}</td></tr>
          <tr><td style="padding:6px 0;color:#6B7280">Role</td><td style="color:#111827;font-weight:600;text-transform:capitalize">${safeRole}</td></tr>
          <tr><td style="padding:6px 0;color:#6B7280">Password</td><td style="color:#111827;font-weight:600;font-family:monospace;letter-spacing:1px">${safePassword}</td></tr>
        </table>
      </div>
      ${coursesBlock}
      <div style="margin:28px 0">
        <a href="${safeLoginUrl}"
           style="display:inline-block;padding:14px 28px;background:linear-gradient(135deg,#2563EB,#4F46E5);color:#fff;text-decoration:none;border-radius:12px;font-weight:700;font-size:15px">
          Login to Jenovate LMS →
        </a>
      </div>
      <p style="color:#9CA3AF;font-size:12px;margin-top:8px">
        ⚠️ For security, please change your password after your first login.
      </p>
      <hr style="border:none;border-top:1px solid #E5E7EB;margin:24px 0"/>
      <p style="color:#D1D5DB;font-size:11px;margin:0">Jenovate LMS Team · This is an automated message.</p>
    </div>
  `;
}

/**
 * Send welcome email using env-configured SMTP (existing behaviour).
 * @param {object} opts
 * @param {string} opts.userName
 * @param {string} opts.email
 * @param {string} opts.role
 * @param {string} opts.temporaryPassword
 * @param {string[]} [opts.courseNames]
 */
async function sendWelcomeUserEmail({ userName, email, role, temporaryPassword, courseNames = [] }) {
  const transporter = getTransporter();
  if (!transporter) throw new Error('Email service is not configured');

  const fromAddress = process.env.MAIL_FROM || process.env.SMTP_FROM || process.env.SMTP_USER;
  const loginUrl = process.env.LMS_LOGIN_URL || process.env.APP_LOGIN_URL || 'http://localhost:3000/login';

  const html = buildWelcomeHtml({
    safeName: escapeHtml(userName),
    safeEmail: escapeHtml(email),
    safeRole: escapeHtml(role),
    safePassword: escapeHtml(temporaryPassword),
    safeLoginUrl: escapeHtml(loginUrl),
    courseNames,
  });

  await transporter.sendMail({ from: fromAddress, to: email, subject: 'Welcome to Jenovate LMS 🎉', html });
}

/**
 * Send welcome email using admin-supplied per-request Gmail credentials.
 * Credentials are NEVER stored — used only for this single send.
 *
 * @param {object} opts
 * @param {string} opts.senderEmail     - Gmail address to send from
 * @param {string} opts.senderPassword  - Gmail App Password (16-char)
 * @param {string} opts.userName
 * @param {string} opts.email
 * @param {string} opts.role
 * @param {string} opts.temporaryPassword
 * @param {string[]} [opts.courseNames]
 */
async function sendWelcomeEmailDynamic({
  senderEmail, senderPassword, userName, email, role, temporaryPassword, courseNames = [],
}) {
  const transporter = createDynamicTransporter(senderEmail, senderPassword);
  const loginUrl = process.env.LMS_LOGIN_URL || process.env.APP_LOGIN_URL || 'http://localhost:3000/login';

  const html = buildWelcomeHtml({
    safeName: escapeHtml(userName),
    safeEmail: escapeHtml(email),
    safeRole: escapeHtml(role),
    safePassword: escapeHtml(temporaryPassword),
    safeLoginUrl: escapeHtml(loginUrl),
    courseNames,
  });

  await transporter.sendMail({
    from: `"Jenovate LMS" <${senderEmail.trim()}>`,
    to: email,
    subject: 'Welcome to Jenovate LMS 🎉',
    html,
  });
}

async function sendPasswordResetEmail({ email, userName, resetUrl }) {
  const transporter = getTransporter();
  if (!transporter) throw new Error('Email service is not configured');

  const fromAddress = process.env.MAIL_FROM || process.env.SMTP_FROM || process.env.SMTP_USER;
  const safeName = escapeHtml(userName || 'User');
  const safeUrl = escapeHtml(resetUrl);

  const html = `
    <div style="font-family:'Inter','Segoe UI',system-ui,sans-serif;max-width:480px;margin:0 auto;padding:32px 24px;background:#ffffff;border-radius:16px">
      <h2 style="color:#1F2937;margin-bottom:8px">Reset Your Password</h2>
      <p style="color:#6B7280;font-size:14px;margin-bottom:24px">
        Hi ${safeName}, we received a request to reset your Jenovate LMS password.
      </p>
      <a href="${safeUrl}"
         style="display:inline-block;padding:14px 28px;background:linear-gradient(135deg,#4F46E5,#7C3AED);
                color:#fff;text-decoration:none;border-radius:12px;font-weight:700;font-size:15px">
        Reset Password
      </a>
      <p style="color:#9CA3AF;font-size:12px;margin-top:24px">
        This link will expire in 15 minutes. If you didn't request a reset, you can safely ignore this email.
      </p>
      <hr style="border:none;border-top:1px solid #E5E7EB;margin:24px 0"/>
      <p style="color:#D1D5DB;font-size:11px">Jenovate LMS Team</p>
    </div>
  `;

  await transporter.sendMail({ from: fromAddress, to: email, subject: 'Password Reset — Jenovate LMS', html });
}

module.exports = {
  isEmailServiceConfigured,
  sendWelcomeUserEmail,
  sendWelcomeEmailDynamic,
  sendPasswordResetEmail,
};
