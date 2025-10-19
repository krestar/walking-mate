const express = require("express");
const router = express.Router();
const adminController = require("../controllers/adminController");
const authMiddleware = require("../middleware/authMiddleware");


router.post("/login", adminController.login);


router.get("/reports", authMiddleware, adminController.getReports);
router.post(
  "/reports/:reportId/process",
  authMiddleware,
  adminController.processReport
);

module.exports = router;
