const express = require("express");
const router = express.Router();
const shopController = require("../controllers/shopController");
const authMiddleware = require("../middleware/authMiddleware");

router.get("/items", authMiddleware, shopController.getItems);
router.post("/items/:itemId/buy", authMiddleware, shopController.buyItem);

module.exports = router;
