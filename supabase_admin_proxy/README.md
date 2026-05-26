Supabase Admin Proxy
====================

This small Node/Express proxy performs privileged admin operations on Supabase
using the `service_role` key. Run it locally during development so your Flutter
client does not need the service-role key.

Usage
-----

1. Install dependencies

```bash
cd supabase_admin_proxy
npm install
```

2. Set environment variables and start

PowerShell example:

```powershell
$env:SUPABASE_URL = 'https://<your-project>.supabase.co'
$env:SUPABASE_SERVICE_ROLE_KEY = 'service_role_...'
$env:SMTP_EMAIL = 'welcome.jenovate@gmail.com'
$env:SMTP_APP_PASSWORD = '<gmail-app-password>'
node index.js
```

Linux/macOS:

```bash
export SUPABASE_URL=https://<your-project>.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=service_role_...
export SMTP_EMAIL=welcome.jenovate@gmail.com
export SMTP_APP_PASSWORD=<gmail-app-password>
node index.js
```

You can also copy `.env.example` to `.env` for local development. Do not commit
real SMTP app passwords or service-role keys.

3. Configure Flutter to use the proxy when running locally:

```bash
flutter run -d chrome --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_API_KEY=<publishable_key> \
  --dart-define=ADMIN_PROXY_URL=http://localhost:4000
```

Endpoints
---------

- `POST /admin/create-user` - body: `{ name, email, role, phone, courseNames? }`.
  The proxy assigns the temporary password `123456` and sends the welcome email.
- `PATCH /admin/update-user/:id` - body: fields to update.
- `POST /admin/update-user/:id/course-assignments` - body: `{ courseIds: [..] }`
  (replaces assignments).
- `POST /admin/assign-course` - body: `{ userId, courseId }`.
- `GET /admin/users` - optional query `?role=student`.
- `DELETE /admin/user/:id`.

Security
--------

- Keep the `SUPABASE_SERVICE_ROLE_KEY` secret and run this server in a secure
  environment, not on the client.
- Keep `SMTP_APP_PASSWORD` in environment variables only. Generate it as a Gmail
  App Password for `welcome.jenovate@gmail.com`; do not use a normal Google
  account password.
- Consider adding authentication to this proxy, such as an API key or OAuth,
  before using it in production.

License
-------

MIT
