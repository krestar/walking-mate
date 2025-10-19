const bcrypt = require("bcrypt");
const pool = require("../config/database");

exports.getFullUserProfile = async (req, res) => {
  const userId = req.userData.userId;
  try {
    const [results] = await pool.query(
      "SELECT user_id, email, nickname, profile_image_url, location, discoverable, points FROM User WHERE user_id = ?",
      [userId]
    );
    if (results.length > 0) {
      res.status(200).json(results[0]);
    } else {
      res.status(404).json({ message: "사용자를 찾을 수 없습니다." });
    }
  } catch (error) {
    res.status(500).json({ message: "데이터베이스 오류가 발생했습니다." });
  }
};

exports.updateUserProfile = async (req, res) => {
  const userId = req.userData.userId;
  const { nickname, location, discoverable } = req.body;
  try {
    const query =
      "UPDATE User SET nickname = ?, location = ?, discoverable = ? WHERE user_id = ?";
    await pool.query(query, [nickname, location, discoverable, userId]);
    res
      .status(200)
      .json({ message: "프로필이 성공적으로 업데이트되었습니다." });
  } catch (error) {
    if (error.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ message: "이미 사용 중인 닉네임입니다." });
    }
    res
      .status(500)
      .json({ message: "프로필 업데이트 중 오류가 발생했습니다." });
  }
};

exports.changePassword = async (req, res) => {
  const userId = req.userData.userId;
  const { currentPassword, newPassword } = req.body;
  try {
    const [users] = await pool.query(
      "SELECT password FROM User WHERE user_id = ?",
      [userId]
    );
    if (users.length === 0) {
      return res.status(404).json({ message: "사용자를 찾을 수 없습니다." });
    }
    const isMatch = await bcrypt.compare(currentPassword, users[0].password);
    if (!isMatch) {
      return res
        .status(401)
        .json({ message: "현재 비밀번호가 일치하지 않습니다." });
    }
    const hashedNewPassword = await bcrypt.hash(newPassword, 10);
    await pool.query("UPDATE User SET password = ? WHERE user_id = ?", [
      hashedNewPassword,
      userId,
    ]);
    res.status(200).json({ message: "비밀번호가 성공적으로 변경되었습니다." });
  } catch (error) {
    res.status(500).json({ message: "비밀번호 변경 중 오류가 발생했습니다." });
  }
};

exports.uploadProfileImage = async (req, res) => {
  const userId = req.userData.userId;
  if (!req.file) {
    return res.status(400).json({ message: "이미지 파일이 필요합니다." });
  }
  try {
    const imageUrl = `${req.protocol}://${req.get("host")}/uploads/profiles/${
      req.file.filename
    }`;
    await pool.query(
      "UPDATE User SET profile_image_url = ? WHERE user_id = ?",
      [imageUrl, userId]
    );
    res
      .status(200)
      .json({
        message: "프로필 이미지가 성공적으로 업로드되었습니다.",
        imageUrl: imageUrl,
      });
  } catch (error) {
    res
      .status(500)
      .json({ message: "이미지 업로드 중 서버 오류가 발생했습니다." });
  }
};
