const express = require("express");
const router = express.Router();
const reportController = require("../controllers/reportController");
const authMiddleware = require("../middleware/authMiddleware");
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const reportUploadDir = 'uploads/reports';
if (!fs.existsSync(reportUploadDir)) {
    fs.mkdirSync(reportUploadDir, { recursive: true });
}

const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, reportUploadDir);
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, req.userData.userId + '-' + uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({ storage: storage });

router.post("/", authMiddleware, upload.single('screenshot'), reportController.submitReport);

module.exports = router;