const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const pool = require("../config/database");
const admin = require("firebase-admin");

exports.register = async (req, res) => {
  const { email, password, nickname } = req.body;
  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    const hashedPassword = await bcrypt.hash(password, 10);
    const [result] = await connection.query(
      "INSERT INTO User (email, password, nickname) VALUES (?, ?, ?)",
      [email, hashedPassword, nickname]
    );
    const newUserId = result.insertId;

    // 모든 사용자는 'polar_bear'를 기본 캐릭터로, 빈 장비 슬롯으로 시작
    const initialEquippedItems = {
      head: null,
      wings: null,
      right_arm: null,
      body: null,
    };

    await connection.query(
      "INSERT INTO `Character` (user_id, character_type, equipped_items) VALUES (?, ?, ?)",
      [newUserId, "polar_bear", JSON.stringify(initialEquippedItems)]
    );

    await connection.commit();

    res.status(201).json({
      message: "회원가입이 성공적으로 완료되었습니다.",
      userId: newUserId,
    });
  } catch (error) {
    await connection.rollback();
    if (error.code === "ER_DUP_ENTRY") {
      return res
        .status(409)
        .json({ message: "이미 사용 중인 이메일 또는 닉네임입니다." });
    }
    res.status(500).json({ message: "데이터베이스 오류가 발생했습니다." });
  } finally {
    connection.release();
  }
};

exports.login = async (req, res) => {
  const { email, password } = req.body;

  try {
    const [users] = await pool.query("SELECT * FROM User WHERE email = ?", [
      email,
    ]);

    if (users.length === 0) {
      return res
        .status(401)
        .json({ message: "이메일 또는 비밀번호가 올바르지 않습니다." });
    }

    const user = users[0];
    const isMatch = await bcrypt.compare(password, user.password);

    if (!isMatch) {
      return res
        .status(401)
        .json({ message: "이메일 또는 비밀번호가 올바르지 않습니다." });
    }

    const accessToken = jwt.sign(
      { userId: user.user_id },
      process.env.JWT_SECRET,
      {
        expiresIn: "1h",
      }
    );

    const refreshToken = jwt.sign(
      { userId: user.user_id },
      process.env.JWT_REFRESH_SECRET,
      {
        expiresIn: "7d",
      }
    );

    await pool.query("UPDATE User SET refresh_token = ? WHERE user_id = ?", [
      refreshToken,
      user.user_id,
    ]);

    const firebaseCustomToken = await admin
      .auth()
      .createCustomToken(String(user.user_id));

    res.status(200).json({
      accessToken: accessToken,
      refreshToken: refreshToken,
      firebaseCustomToken: firebaseCustomToken,
    });
  } catch (error) {
    res.status(500).json({ message: "서버 오류가 발생했습니다." });
  }
};

exports.refresh = async (req, res) => {
  const { token } = req.body;
  if (!token) {
    return res.status(401).json({ message: "Refresh Token이 필요합니다." });
  }

  try {
    const [users] = await pool.query(
      "SELECT * FROM User WHERE refresh_token = ?",
      [token]
    );

    if (users.length === 0) {
      return res
        .status(403)
        .json({ message: "유효하지 않은 Refresh Token입니다." });
    }

    const user = users[0];

    jwt.verify(token, process.env.JWT_REFRESH_SECRET, (err, decoded) => {
      if (err) {
        return res
          .status(403)
          .json({ message: "Refresh Token이 만료되었거나 유효하지 않습니다." });
      }

      const newAccessToken = jwt.sign(
        { userId: user.user_id },
        process.env.JWT_SECRET,
        {
          expiresIn: "1h",
        }
      );

      const newRefreshToken = jwt.sign(
        { userId: user.user_id },
        process.env.JWT_REFRESH_SECRET,
        {
          expiresIn: "7d",
        }
      );

      pool.query("UPDATE User SET refresh_token = ? WHERE user_id = ?", [
        newRefreshToken,
        user.user_id,
      ]);

      res.status(200).json({
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      });
    });
  } catch (error) {
    res.status(500).json({ message: "토큰 갱신 중 서버 오류가 발생했습니다." });
  }
};
