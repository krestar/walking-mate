const express = require("express");
const router = express.Router();
const walkwayController = require("../controllers/walkwayController");
const authMiddleware = require("../middleware/authMiddleware");
const multer = require("multer");
const path = require("path");
const fs = require("fs");

const thumbnailUploadDir = "uploads/thumbnails";
if (!fs.existsSync(thumbnailUploadDir)) {
  fs.mkdirSync(thumbnailUploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, thumbnailUploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
    cb(
      null,
      "walkway-" +
        req.params.id +
        "-" +
        uniqueSuffix +
        path.extname(file.originalname)
    );
  },
});

const upload = multer({ storage: storage });

router.post(
  "/recommend",
  authMiddleware,
  walkwayController.recommendAndCreateWalkway
);
router.post(
  "/:id/thumbnail",
  authMiddleware,
  upload.single("thumbnail"),
  walkwayController.uploadThumbnail
);
router.get("/", authMiddleware, walkwayController.getWalkways);
router.get("/:id", authMiddleware, walkwayController.getWalkwayById);
router.post("/:id/like", authMiddleware, walkwayController.likeWalkway);
router.delete("/:id/like", authMiddleware, walkwayController.unlikeWalkway);
router.put("/:id", authMiddleware, walkwayController.updateWalkway);
router.delete("/:id", authMiddleware, walkwayController.deleteWalkway);
router.get("/:id/comments", authMiddleware, walkwayController.getComments);
router.post("/:id/comments", authMiddleware, walkwayController.createComment);
router.delete(
  "/:id/comments/:commentId",
  authMiddleware,
  walkwayController.deleteComment
);

module.exports = router;
