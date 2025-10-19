const jwt = require("jsonwebtoken");
const pool = require("../config/database");

module.exports = async (req, res, next) => {
  try {
    const token = req.headers.authorization.split(" ")[1];
    const decodedToken = jwt.verify(token, process.env.JWT_SECRET);

    const [[user]] = await pool.query(
      "SELECT banned_until FROM User WHERE user_id = ?",
      [decodedToken.userId]
    );

    if (user && user.banned_until && new Date(user.banned_until) > new Date()) {
      return res.status(403).json({ message: "활동이 정지된 계정입니다." });
    }

    req.userData = { userId: decodedToken.userId };
    next();
  } catch (error) {
    res.status(401).json({ message: "인증에 실패했습니다." });
  }
};
