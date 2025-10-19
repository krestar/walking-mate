const pool = require("../config/database");
const { updateAchievementProgress } = require("../helpers/achievementHelper");

// 산책 기록 저장
exports.saveWalkRecord = async (req, res) => {
  const userId = req.userData.userId;
  const { walkwayId, totalTime, totalDistance, isAiWalkway, walkwayCreatorId } =
    req.body;

  if (walkwayId == null || totalTime == null || totalDistance == null) {
    return res.status(400).json({ message: "필수 데이터가 누락되었습니다." });
  }

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const now = new Date();
    const startTime = new Date(now.getTime() - totalTime * 1000);

    await connection.query(
      `INSERT INTO Walk_Record (walkway_id, user_id, start_time, end_time, total_distance) VALUES (?, ?, ?, ?, ?)`,
      [walkwayId, userId, startTime, now, totalDistance]
    );

    const earnedPoints = Math.round(totalDistance * 50);
    if (earnedPoints > 0) {
      await connection.query(
        "UPDATE User SET points = points + ? WHERE user_id = ?",
        [earnedPoints, userId]
      );
      await connection.query(
        "INSERT INTO Point_Ledger (user_id, amount, description) VALUES (?, ?, ?)",
        [userId, earnedPoints, "산책 보상"]
      );
      await updateAchievementProgress(
        userId,
        "total_points_earned",
        earnedPoints,
        connection
      );
    }

    await updateAchievementProgress(userId, "total_walk_count", 1, connection);
    await updateAchievementProgress(
      userId,
      "total_distance",
      totalDistance,
      connection
    );
    await updateAchievementProgress(
      userId,
      "total_walk_time",
      Math.round(totalTime / 60),
      connection
    );

    if (isAiWalkway) {
      await updateAchievementProgress(userId, "walk_with_ai", 1, connection);
    }
    if (walkwayCreatorId && walkwayCreatorId !== userId) {
      await updateAchievementProgress(userId, "use_others_way", 1, connection);
    }

    const [[user]] = await connection.query(
      "SELECT last_walk_date, consecutive_walk_days FROM User WHERE user_id = ?",
      [userId]
    );
    const today = new Date();
    today.setHours(today.getHours() + 9);
    const todayDateString = today.toISOString().split("T")[0];

    let newConsecutiveDays = 1;
    if (user.last_walk_date) {
      const lastWalkDate = new Date(user.last_walk_date);
      const yesterday = new Date(today);
      yesterday.setDate(today.getDate() - 1);

      if (
        lastWalkDate.toISOString().split("T")[0] ===
        yesterday.toISOString().split("T")[0]
      ) {
        newConsecutiveDays = user.consecutive_walk_days + 1;
      } else if (lastWalkDate.toISOString().split("T")[0] !== todayDateString) {
        newConsecutiveDays = 1;
      } else {
        newConsecutiveDays = user.consecutive_walk_days;
      }
    }

    await connection.query(
      "UPDATE User SET last_walk_date = ?, consecutive_walk_days = ? WHERE user_id = ?",
      [todayDateString, newConsecutiveDays, userId]
    );
    await updateAchievementProgress(
      userId,
      "consecutive_walk",
      newConsecutiveDays,
      connection
    );

    const walkDay = today.getDay();
    if (walkDay === 0 || walkDay === 6) {
      await updateAchievementProgress(
        userId,
        "weekend_walk",
        totalDistance,
        connection
      );
    }

    await connection.commit();
    res.status(201).json({ message: "산책 기록이 성공적으로 저장되었습니다." });
  } catch (error) {
    await connection.rollback();
    console.error("산책 기록 저장 중 오류 발생:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 인해 기록을 저장하지 못했습니다." });
  } finally {
    connection.release();
  }
};

exports.getTodayWalkRecord = async (req, res) => {
  const userId = req.userData.userId;

  try {
    const query = `
      SELECT SUM(TIME_TO_SEC(TIMEDIFF(end_time, start_time))) as total_time_seconds
      FROM Walk_Record
      WHERE user_id = ? AND DATE(end_time) = DATE(NOW() + INTERVAL 9 HOUR)
    `;
    const [records] = await pool.query(query, [userId]);

    const totalTimeSeconds = records[0].total_time_seconds || 0;

    res.status(200).json({ total_time_seconds: parseInt(totalTimeSeconds) });
  } catch (error) {
    console.error("오늘 산책 기록 조회 중 오류 발생:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 인해 기록을 조회하지 못했습니다." });
  }
};
