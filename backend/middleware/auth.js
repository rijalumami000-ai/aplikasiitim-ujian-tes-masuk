const jwt = require('jsonwebtoken');

const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ message: 'Token otentikasi tidak ditemukan' });
  }

  jwt.verify(token, process.env.JWT_SECRET || 'supersecretjwtkey123!', (err, user) => {
    if (err) {
      return res.status(403).json({ message: 'Token tidak valid atau kedaluwarsa' });
    }
    req.user = user;
    next();
  });
};

const requireRole = (role) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ message: 'Tidak terotentikasi' });
    }
    if (req.user.role !== role) {
      return res.status(403).json({ message: 'Akses ditolak: Hak akses tidak memadai' });
    }
    next();
  };
};

module.exports = {
  authenticateToken,
  requireRole
};
