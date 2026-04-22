const jwt = require('jsonwebtoken');

/**
 * Express middleware that verifies the JWT token on every protected route.
 *
 * Expects the header:
 *   Authorization: Bearer <token>
 *
 * On success  → attaches `req.user = { id, email, role }` and calls next().
 * On failure  → returns 401 Unauthorized.
 */
function authenticate(req, res, next) {
  const authHeader = req.headers['authorization'];

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'No token provided' });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; // { id, email, role, iat, exp }
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ message: 'Token expired, please log in again' });
    }
    return res.status(401).json({ message: 'Invalid token' });
  }
}

/**
 * Role-guard middleware factory.
 * Usage: requireRole('admin') or requireRole('admin', 'mentor')
 *
 * Must be used AFTER authenticate().
 */
function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ message: 'Forbidden: insufficient permissions' });
    }
    next();
  };
}

module.exports = { authenticate, requireRole };
