const express = require("express");
const router = express.Router();
const locationController = require("../controllers/locationController");
const authMiddleware = require("../middleware/authMiddleware");


router.post(
  "/address",
  authMiddleware,
  locationController.getAddressFromCoords
);

module.exports = router;