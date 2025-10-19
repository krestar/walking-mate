const express = require("express");
const router = express.Router();
const friendController = require("../controllers/friendController");
const authMiddleware = require("../middleware/authMiddleware");

// POST /api/friends/request - 워킹메이트 요청 보내기
router.post("/request", authMiddleware, friendController.sendRequest);

// POST /api/friends/accept - 워킹메이트 요청 수락
router.post("/accept", authMiddleware, friendController.acceptRequest);

// DELETE /api/friends/request/:friendshipId - 워킹메이트 요청 거절 또는 취소
router.delete("/request/:friendshipId", authMiddleware, friendController.rejectOrCancelRequest);

// GET /api/friends - 워킹메ITE 목록 조회
router.get("/", authMiddleware, friendController.listFriends);

// GET /api/friends/requests/all - 받은/보낸 워킹메이트 요청 목록 조회
router.get("/requests/all", authMiddleware, friendController.listAllRequests);

// DELETE /api/friends/:friendshipId - 워킹메이트 삭제
router.delete("/:friendshipId", authMiddleware, friendController.deleteFriend);

module.exports = router;
