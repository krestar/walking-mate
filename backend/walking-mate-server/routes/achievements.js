const express = require("express");
const router = express.Router();
const achievementController = require("../controllers/achievementController");
const authMiddleware = require("../middleware/authMiddleware");

router.get("/", authMiddleware, achievementController.getAchievements);


router.post(
  "/:achievementId/claim",
  authMiddleware,
  achievementController.claimReward
);

module.exports = router;
