const pool = require("../config/database");

exports.getAchievements = async (req, res) => {
  const userId = req.userData.userId;
  try {
    const [[userProfile]] = await pool.query(
      "SELECT user_id, nickname, points FROM User WHERE user_id = ?",
      [userId]
    );

    const query = `
      SELECT 
        a.achievement_id,
        a.title,
        a.description,
        a.category,
        a.goal,
        a.reward_points,
        a.is_hidden,
        COALESCE(ua.progress, 0) as progress,
        COALESCE(ua.status, 'locked') as status
      FROM Achievement a
      LEFT JOIN User_Achievement ua ON a.achievement_id = ua.achievement_id AND ua.user_id = ?
      WHERE a.is_hidden = 0 OR (a.is_hidden = 1 AND ua.status IS NOT NULL AND ua.status != 'locked')
      ORDER BY a.category, a.achievement_id;
    `;
    const [achievements] = await pool.query(query, [userId]);

    res.status(200).json({ userProfile, achievements });
  } catch (error) {
    console.error("Error fetching achievements:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 업적 정보를 가져오지 못했습니다." });
  }
};

exports.claimReward = async (req, res) => {
  const userId = req.userData.userId;

  // 디버깅을 위해 받은 파라미터를 모두 출력합니다.
  console.log("Received params for claimReward:", req.params);
  const { achievementId } = req.params;

  if (!achievementId || isNaN(parseInt(achievementId, 10))) {
    return res.status(400).json({ message: "잘못된 업적 ID입니다." });
  }

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const [[userAchievement]] = await connection.query(
      "SELECT * FROM User_Achievement WHERE user_id = ? AND achievement_id = ?",
      [userId, achievementId]
    );

    if (!userAchievement || userAchievement.status !== "completed") {
      console.error(
        `보상 수령 실패: User ${userId}, Achievement ${achievementId}. DB 상태: ${
          userAchievement?.status || "존재하지 않음"
        }`
      );
      await connection.rollback();
      return res
        .status(400)
        .json({ message: "보상을 수령할 수 있는 상태가 아닙니다." });
    }

    const [[achievementInfo]] = await connection.query(
      "SELECT * FROM Achievement WHERE achievement_id = ?",
      [achievementId]
    );

    const rewardPoints = achievementInfo.reward_points;
    await connection.query(
      "UPDATE User SET points = points + ? WHERE user_id = ?",
      [rewardPoints, userId]
    );
    await connection.query(
      "UPDATE User_Achievement SET status = 'rewarded', completed_at = NOW() WHERE user_id = ? AND achievement_id = ?",
      [userId, achievementId]
    );
    await connection.query(
      "INSERT INTO Point_Ledger (user_id, amount, description) VALUES (?, ?, ?)",
      [userId, rewardPoints, `업적 보상: ${achievementInfo.title}`]
    );

    const [[{ totalPoints }]] = await connection.query(
      "SELECT points as totalPoints FROM User WHERE user_id = ?",
      [userId]
    );

    await connection.commit();

    res.status(200).json({
      message: `'${achievementInfo.title}' 업적 보상을 획득했습니다!`,
      newTotalPoints: totalPoints,
    });
  } catch (error) {
    await connection.rollback();
    console.error("보상 수령 중 서버 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 보상을 수령하지 못했습니다." });
  } finally {
    connection.release();
  }
};
