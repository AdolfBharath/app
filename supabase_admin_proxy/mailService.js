const nodemailer = require('nodemailer');
const dns = require('dns/promises');
const fs = require('fs');
const path = require('path');

const SMTP_HOST = 'smtp.gmail.com';
const SMTP_PORT = 465;
const SMTP_SECURE = true;
const WELCOME_SUBJECT = 'Welcome to Jenovate';
const TEMPORARY_PASSWORD = '123456';
const DEFAULT_LOGO_URL = 'https://jenovate.in/logo.png';
const LOCAL_LOGO_PATH = path.join(__dirname, 'assets', 'jenovate-logo.jpeg');
const LOGO_CID = 'jenovate-logo';

let transporter;

function requireSmtpConfig() {
  const email = process.env.SMTP_EMAIL;
  const appPassword = process.env.SMTP_APP_PASSWORD;

  if (!email || !appPassword) {
    throw new Error('SMTP_EMAIL and SMTP_APP_PASSWORD must be set');
  }

  return { email, appPassword };
}

async function getTransporter() {
  if (transporter) return transporter;

  const { email, appPassword } = requireSmtpConfig();
  const { address } = await dns.lookup(SMTP_HOST, { family: 4 });
  transporter = nodemailer.createTransport({
    host: address,
    port: SMTP_PORT,
    secure: SMTP_SECURE,
    family: 4,
    name: 'localhost',
    connectionTimeout: 15000,
    greetingTimeout: 15000,
    socketTimeout: 20000,
    tls: {
      servername: SMTP_HOST,
    },
    auth: {
      user: email,
      pass: appPassword,
    },
  });

  return transporter;
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function buildWelcomeEmailHtml({ email, username, password }) {
  const safeEmail = escapeHtml(email);
  const safeUsername = escapeHtml(username || 'Jenovate Learner');
  const safePassword = escapeHtml(password || TEMPORARY_PASSWORD);
  const logoUrl = escapeHtml(
    process.env.APP_LOGO_URL ||
      (fs.existsSync(LOCAL_LOGO_PATH) ? `cid:${LOGO_CID}` : DEFAULT_LOGO_URL),
  );

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
  <title>Welcome to Jenovate</title>
</head>
<body style="margin:0;padding:30px 15px;background:#eef5ff;font-family:'Poppins',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr>
      <td align="center">
        <table width="680" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:680px;background:#ffffff;border-radius:32px;overflow:hidden;box-shadow:0 10px 40px rgba(37,99,235,0.08),0 20px 80px rgba(37,99,235,0.10);">
          <tr>
            <td align="center" style="padding:65px 45px 55px;background:#2563eb;background-image:radial-gradient(circle at top left,#60a5fa 0%,transparent 30%),linear-gradient(135deg,#2563eb,#3b82f6);">
              <div style="background:rgba(255,255,255,0.14);padding:18px;border-radius:28px;display:inline-block;margin-bottom:28px;">
                <img src="${logoUrl}" width="95" alt="Jenovate Logo" style="display:block;border-radius:20px;">
              </div>
              <h1 style="margin:0;color:#ffffff;font-size:46px;font-weight:800;letter-spacing:-1px;">Jenovate</h1>
              <p style="margin:16px 0 0;color:#dbeafe;font-size:20px;font-weight:500;line-height:1.8;">Let's Land Your Dream Job Together.</p>
            </td>
          </tr>
          <tr>
            <td style="padding:55px 48px;">
              <h2 style="margin:0;color:#0f172a;font-size:38px;font-weight:800;text-align:center;">Welcome to Jenovate!</h2>
              <p style="margin-top:18px;text-align:center;color:#475569;font-size:17px;line-height:1.9;">Your account has been created successfully.</p>
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-top:40px;border:1px solid #dbeafe;border-radius:24px;background:#f8fbff;">
                <tr>
                  <td style="padding:32px;">
                    <p style="margin:0;color:#2563eb;font-size:16px;font-weight:600;">Hello,</p>
                    <h3 style="margin:10px 0 0;color:#0f172a;font-size:30px;font-weight:700;">${safeUsername}</h3>
                    <p style="margin-top:18px;color:#475569;font-size:16px;line-height:1.9;">We're excited to have you onboard. Here are your login details to get started.</p>
                  </td>
                </tr>
              </table>
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-top:34px;border-radius:28px;overflow:hidden;background:#f8fbff;background-image:linear-gradient(135deg,#f8fbff,#eef5ff);border:1px solid #dbeafe;">
                <tr>
                  <td style="padding:40px;">
                    <div style="text-align:center;margin-bottom:35px;">
                      <p style="margin:0 0 10px;color:#2563eb;font-size:13px;font-weight:700;letter-spacing:1.2px;text-transform:uppercase;">Login Email</p>
                      <p style="margin:0;color:#0f172a;font-size:24px;font-weight:600;word-break:break-word;">${safeEmail}</p>
                    </div>
                    <div style="text-align:center;">
                      <p style="margin:0 0 14px;color:#2563eb;font-size:13px;font-weight:700;letter-spacing:1.2px;text-transform:uppercase;">Temporary Password</p>
                      <div style="display:inline-block;background:#2563eb;background-image:linear-gradient(135deg,#2563eb,#3b82f6);color:#ffffff;padding:18px 42px;border-radius:18px;font-size:30px;font-weight:700;letter-spacing:8px;box-shadow:0 12px 30px rgba(37,99,235,0.28);">${safePassword}</div>
                    </div>
                  </td>
                </tr>
              </table>
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-top:35px;background:#eff6ff;border:1px solid #bfdbfe;border-radius:20px;">
                <tr>
                  <td style="padding:24px 26px;">
                    <p style="margin:0;color:#1d4ed8;font-size:15px;line-height:1.9;font-weight:500;">Please reset your password immediately after your first login to keep your account secure.</p>
                  </td>
                </tr>
              </table>
              <div style="text-align:center;margin:50px 0 40px;">
                <a href="https://jenovate.in/" style="display:inline-block;text-decoration:none;padding:20px 48px;border-radius:18px;background:#2563eb;background-image:linear-gradient(135deg,#2563eb,#3b82f6);color:#ffffff;font-size:17px;font-weight:700;box-shadow:0 12px 30px rgba(37,99,235,0.30);">Login to Jenovate</a>
              </div>
              <p style="color:#64748b;font-size:15px;line-height:2;text-align:center;">Need help? Our support team is always here to assist you.</p>
              <p style="margin-top:35px;text-align:center;color:#0f172a;font-size:16px;line-height:1.9;">Best Regards,<br><span style="color:#2563eb;font-size:20px;font-weight:700;">Team Jenovate</span></p>
            </td>
          </tr>
          <tr>
            <td align="center" style="background:#f8fbff;padding:28px;border-top:1px solid #e2e8f0;">
              <p style="margin:0;color:#64748b;font-size:13px;line-height:2;">&copy; 2026 Jenovate &bull; Let's Land Your Dream Job Together.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `;
}

function buildWelcomeEmailText({ email, username, password }) {
  return [
    'Welcome to Jenovate!',
    'Your account has been created successfully.',
    '',
    `Hello, ${username || 'Jenovate Learner'}`,
    `Login Email: ${email}`,
    `Temporary Password: ${password || TEMPORARY_PASSWORD}`,
    '',
    'Please reset your password immediately after login.',
  ].join('\n');
}

async function sendWelcomeEmail(email, options = {}) {
  const { email: senderEmail } = requireSmtpConfig();
  const normalizedEmail = String(email || '').trim().toLowerCase();

  if (!normalizedEmail) {
    throw new Error('Recipient email is required');
  }

  const mailer = await getTransporter();
  const attachments = fs.existsSync(LOCAL_LOGO_PATH)
    ? [
        {
          filename: 'jenovate-logo.jpeg',
          path: LOCAL_LOGO_PATH,
          cid: LOGO_CID,
        },
      ]
    : [];

  const info = await mailer.sendMail({
    from: `"Jenovate" <${senderEmail}>`,
    to: normalizedEmail,
    subject: WELCOME_SUBJECT,
    text: buildWelcomeEmailText({
      email: normalizedEmail,
      username: options.username,
      password: options.password,
    }),
    html: buildWelcomeEmailHtml({
      email: normalizedEmail,
      username: options.username,
      password: options.password,
    }),
    attachments,
  });

  console.info(`Welcome email sent to ${normalizedEmail}: ${info.messageId}`);
  return info;
}

module.exports = {
  TEMPORARY_PASSWORD,
  sendWelcomeEmail,
};
