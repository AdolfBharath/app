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
    ? {
        service: smtpService,
        auth: { user: smtpUser, pass: smtpPass },
      }
    : {
        host: smtpHost,
        port: smtpPort,
        secure: smtpSecure,
        auth: { user: smtpUser, pass: smtpPass },
      };

  cachedTransporter = nodemailer.createTransport(transportConfig);
  return cachedTransporter;
}

function escapeHtml(input) {
  return String(input ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

async function sendWelcomeUserEmail({ userName, email, role, temporaryPassword }) {
  const transporter = getTransporter();
  if (!transporter) {
    throw new Error('Email service is not configured');
  }

  const fromAddress =
    process.env.MAIL_FROM || process.env.SMTP_FROM || process.env.SMTP_USER;
  const loginUrl =
    process.env.LMS_LOGIN_URL || process.env.APP_LOGIN_URL || 'http://localhost:3000/login';

  const safeName = escapeHtml(userName);
  const safeEmail = escapeHtml(email);
  const safeRole = escapeHtml(role);
  const safePassword = escapeHtml(temporaryPassword);
  const safeLoginUrl = escapeHtml(loginUrl);

  const subject = 'Welcome to Jenovate LMS 🎉';
  const html = `
    <p>Hello ${safeName},</p>
    <p>Your account has been successfully created in Jenovate LMS.</p>
    <p>Here are your login details:</p>
    <p>
      <strong>Email:</strong> ${safeEmail}<br/>
      <strong>Role:</strong> ${safeRole}<br/>
      <strong>Temporary Password:</strong> ${safePassword}
    </p>
    <p>
      Login here:<br/>
      <a href="${safeLoginUrl}">${safeLoginUrl}</a>
    </p>
    <p>For security reasons, please change your password after first login.</p>
    <p>Regards,<br/>Jenovate Team</p>
  `;

  await transporter.sendMail({
    from: fromAddress,
    to: email,
    subject,
    html,
  });
}

module.exports = {
  isEmailServiceConfigured,
  sendWelcomeUserEmail,
};
