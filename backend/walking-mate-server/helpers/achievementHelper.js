const pool = require("../config/database");

// 값을 누적하는 업적 유형
const cumulativeAchievements = {
  total_walk_count: [100],
  total_distance: [102, 105, 110],
  total_walk_time: [101, 106, 111],
  walk_with_ai: [103, 107, 112],
  weekend_walk: [109],
  join_crew: [203, 204],
  create_post: [206],
  create_comment: [207],
  post_liked: [208],
  walkway_liked: [308],
  use_others_way: [309],
  total_points_earned: [305],
};

// 값을 현재 상태로 덮어쓰는 업적 유형
const statefulAchievements = {
  consecutive_walk: [104, 108, 113],
  friend_count: [200, 201, 202],
  create_crew: [205],
  create_walkway: [307],
};

const getAchievementIdsByType = (type) => {
  return cumulativeAchievements[type] || statefulAchievements[type] || [];
};

const isStateful = (type) => statefulAchievements.hasOwnProperty(type);

async function updateAchievementProgress(userId, type, value, connection) {
  const conn = connection || pool;
  const achievementIds = getAchievementIdsByType(type);

  if (achievementIds.length === 0) return;

  for (const achievementId of achievementIds) {
    try {
      const [[achievementInfo]] = await conn.query(
        "SELECT * FROM Achievement WHERE achievement_id = ?",
        [achievementId]
      );
      if (!achievementInfo) continue;

      let [[userAchievement]] = await conn.query(
        "SELECT * FROM User_Achievement WHERE user_id = ? AND achievement_id = ?",
        [userId, achievementId]
      );

      if (!userAchievement) {
        await conn.query(
          "INSERT INTO User_Achievement (user_id, achievement_id, progress, status) VALUES (?, ?, 0, 'locked')",
          [userId, achievementId]
        );
        [[userAchievement]] = await conn.query(
          "SELECT * FROM User_Achievement WHERE user_id = ? AND achievement_id = ?",
          [userId, achievementId]
        );
      }

      if (userAchievement.status === "rewarded") continue;

      // 업적 유형에 따라 진행도 계산 방식을 다르게 적용
      const newProgress = isStateful(type)
        ? value
        : userAchievement.progress + value;

      let newStatus = userAchievement.status;
      if (newProgress >= achievementInfo.goal) {
        newStatus = "completed";
      } else if (newProgress > 0 && userAchievement.status === "locked") {
        newStatus = "in_progress";
      }

      await conn.query(
        "UPDATE User_Achievement SET progress = ?, status = ? WHERE user_id = ? AND achievement_id = ?",
        [newProgress, newStatus, userId, achievementId]
      );
    } catch (error) {
      console.error(
        `Error updating achievement progress for user ${userId}, type ${type}, id ${achievementId}:`,
        error
      );
      throw error;
    }
  }
}

module.exports = { updateAchievementProgress };
