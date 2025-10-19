const express = require("express");
const router = express.Router();
const characterController = require("../controllers/characterController");
const authMiddleware = require("../middleware/authMiddleware");

router.get("/inventory", authMiddleware, characterController.getInventory);
router.post("/equip", authMiddleware, characterController.equipItems);
router.post(
  "/buy/:characterId",
  authMiddleware,
  characterController.buyCharacter
);

module.exports = router;
