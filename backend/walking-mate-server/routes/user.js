const express = require("express");
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const userController = require("../controllers/userController");
const authMiddleware = require("../middleware/authMiddleware");

const profileUploadDir = 'uploads/profiles';
if (!fs.existsSync(profileUploadDir)) {
    fs.mkdirSync(profileUploadDir, { recursive: true });
}

const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, profileUploadDir);
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, req.userData.userId + '-' + uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({ storage: storage });

router.get("/profile", authMiddleware, userController.getFullUserProfile);
router.put("/profile", authMiddleware, userController.updateUserProfile);
router.post("/password", authMiddleware, userController.changePassword);
router.post("/profile-image", authMiddleware, upload.single('profileImage'), userController.uploadProfileImage);

module.exports = router;
