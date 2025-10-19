const express = require("express");
const router = express.Router();
const communityController = require("../controllers/communityController");
const authMiddleware = require("../middleware/authMiddleware");

// --- 크루 관련 API ---
router.post("/crews", authMiddleware, communityController.createCrew);
router.get("/crews/my", authMiddleware, communityController.getMyCrews);
router.post(
  "/crews/:crewId/join",
  authMiddleware,
  communityController.joinCrew
);
router.delete(
  "/crews/:crewId/leave",
  authMiddleware,
  communityController.leaveCrew
);
router.delete("/crews/:crewId", authMiddleware, communityController.deleteCrew);
router.get(
  "/crews/:crewId/members",
  authMiddleware,
  communityController.getCrewMembers
);
router.delete(
  "/crews/:crewId/members/:memberId",
  authMiddleware,
  communityController.removeCrewMember
);

// --- 게시글 관련 API ---
router.get(
  "/crews/:crewId/posts",
  authMiddleware,
  communityController.getPosts
);
router.post(
  "/crews/:crewId/posts",
  authMiddleware,
  communityController.createPost
);
router.put("/posts/:postId", authMiddleware, communityController.updatePost);
router.delete("/posts/:postId", authMiddleware, communityController.deletePost);

// --- 추천(좋아요) 관련 API ---
router.post(
  "/posts/:postId/like",
  authMiddleware,
  communityController.likePost
);

// --- 댓글 관련 API ---
router.get(
  "/posts/:postId/comments",
  authMiddleware,
  communityController.getComments
);
router.post(
  "/posts/:postId/comments",
  authMiddleware,
  communityController.createComment
);
router.delete(
  "/comments/:commentId",
  authMiddleware,
  communityController.deleteComment
);

// --- 탐색 관련 API ---
router.get("/search/crews", authMiddleware, communityController.searchCrews);
router.get("/search/users", authMiddleware, communityController.searchUsers);

module.exports = router;
