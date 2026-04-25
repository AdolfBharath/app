const rateLimitMap = new Map();

/**
 * Basic security headers middleware (manually setting what Helmet does).
 */
function securityHeaders(req, res, next) {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  res.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self'; object-src 'none';");
  next();
}

/**
 * Simple in-memory rate limiter.
 * Usage: rateLimit(10, 60000) // 10 requests per minute
 */
function rateLimit(maxRequests, windowMs) {
  return (req, res, next) => {
    const ip = req.ip || req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    const key = `${req.path}_${ip}`;
    const now = Date.now();

    if (!rateLimitMap.has(key)) {
      rateLimitMap.set(key, { count: 1, firstRequest: now });
      return next();
    }

    const data = rateLimitMap.get(key);
    if (now - data.firstRequest > windowMs) {
      // Reset window
      data.count = 1;
      data.firstRequest = now;
      return next();
    }

    data.count++;
    if (data.count > maxRequests) {
      return res.status(429).json({
        message: 'Too many requests, please try again later.',
      });
    }

    next();
  };
}

module.exports = { securityHeaders, rateLimit };
