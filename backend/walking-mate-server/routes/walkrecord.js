const express = require("express");
const router = express.Router();
const walkrecordController = require("../controllers/walkrecordController");
const authMiddleware = require("../middleware/authMiddleware");


router.post("/result", authMiddleware, walkrecordController.saveWalkRecord);


router.get("/today", authMiddleware, walkrecordController.getTodayWalkRecord);

module.exports = router;
