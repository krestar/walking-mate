const pool = require("../config/database");

exports.submitReport = async (req, res) => {
  const reporterId = req.userData.userId;
  const { targetType, targetId, reason } = req.body;

  if (!targetType || !targetId || !reason) {
    return res.status(400).json({ message: "필수 정보가 누락되었습니다." });
  }

  let screenshotUrl = null;
  if (req.file) {
    screenshotUrl = `uploads/reports/${req.file.filename}`;
  }

  try {
    await pool.query(
      "INSERT INTO Report (reporter_id, target_type, target_id, reason, screenshot_url) VALUES (?, ?, ?, ?, ?)",
      [reporterId, targetType, targetId, reason, screenshotUrl]
    );

    res.status(201).json({ message: "신고가 성공적으로 접수되었습니다." });
  } catch (error) {
    console.error("신고 접수 중 오류 발생:", error);
    res.status(500).json({ message: "서버 오류로 인해 신고를 접수하지 못했습니다." });
  }
};