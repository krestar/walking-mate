require("dotenv").config();

const express = require("express");
const cors = require("cors");
const path = require("path");

const authRoutes = require("./routes/auth");
const userRoutes = require("./routes/user");
const walkwayRoutes = require("./routes/walkway");
const locationRoutes = require("./routes/location");
const walkrecordRoutes = require("./routes/walkrecord");
const communityRoutes = require("./routes/community");
const friendRoutes = require("./routes/friend");
const achievementRoutes = require("./routes/achievements");
const shopRoutes = require("./routes/shop");
const characterRoutes = require("./routes/character");
const reportRoutes = require("./routes/report");
const adminRoutes = require("./routes/admin");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use("/uploads", express.static(path.join(__dirname, "uploads")));
app.use(express.static("public"));

app.get("/", (req, res) => {
  res.send("Walking Mate API Server is running!");
});

app.use("/api/auth", authRoutes);
app.use("/api/user", userRoutes);
app.use("/api/walkways", walkwayRoutes);
app.use("/api/locations", locationRoutes);
app.use("/api/walkrecord", walkrecordRoutes);
app.use("/api/community", communityRoutes);
app.use("/api/friends", friendRoutes);
app.use("/api/achievements", achievementRoutes);
app.use("/api/shop", shopRoutes);
app.use("/api/character", characterRoutes);
app.use("/api/report", reportRoutes);
app.use("/api/admin", adminRoutes);

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server is running on port ${PORT}`);
});
