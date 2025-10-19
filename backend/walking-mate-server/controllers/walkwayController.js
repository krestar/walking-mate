const pool = require("../config/database");
const axios = require("axios");
const { updateAchievementProgress } = require("../helpers/achievementHelper");

const callGemini = async (prompt) => {
  const geminiApiKey = process.env.GEMINI_API_KEY;
  const geminiApiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=${geminiApiKey}`;

  try {
    const response = await axios.post(geminiApiUrl, {
      contents: [{ parts: [{ text: prompt }] }],
    });
    return response.data.candidates[0].content.parts[0].text;
  } catch (error) {
    console.error(
      "Gemini API 호출 중 오류:",
      error.response
        ? JSON.stringify(error.response.data, null, 2)
        : error.message
    );
    throw new Error("Gemini API 호출에 실패했습니다.");
  }
};

exports.uploadThumbnail = async (req, res) => {
  const { id } = req.params;
  const userId = req.userData.userId;

  if (!req.file) {
    return res
      .status(400)
      .json({ message: "썸네일 이미지 파일이 필요합니다." });
  }

  try {
    const [walkways] = await pool.query(
      "SELECT user_id FROM Walkway WHERE walkway_id = ?",
      [id]
    );
    if (walkways.length === 0) {
      return res.status(404).json({ message: "산책로를 찾을 수 없습니다." });
    }
    if (walkways[0].user_id !== userId) {
      return res
        .status(403)
        .json({ message: "썸네일을 업로드할 권한이 없습니다." });
    }

    const imageUrl = `uploads/thumbnails/${req.file.filename}`;

    await pool.query(
      "UPDATE Walkway SET thumbnail_url = ? WHERE walkway_id = ?",
      [imageUrl, id]
    );

    res.status(200).json({
      message: "썸네일이 성공적으로 업로드되었습니다.",
      thumbnailUrl: `${req.protocol}://${req.get("host")}/${imageUrl}`,
    });
  } catch (error) {
    console.error("썸네일 업로드 중 오류:", error);
    res
      .status(500)
      .json({ message: "썸네일 업로드 중 서버 오류가 발생했습니다." });
  }
};

exports.recommendAndCreateWalkway = async (req, res) => {
  const userId = req.userData.userId;
  const {
    title,
    description,
    difficulty,
    start_location_name,
    start_coords,
    end_location_name,
    end_coords,
    tags,
    status,
  } = req.body;
  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    let keywordParts = [];
    if (tags && tags.length > 0) {
      keywordParts.push(...tags);
    }

    if (description) {
      const extractionPrompt = `
            From the following sentence, extract only the names of specific places, landmarks, or key nouns. 
            For example, if the sentence is "I want to stop by Incheon Nonhyeon Homeplus", extract "Incheon Nonhyeon Homeplus".
            If the sentence is "A quiet park would be nice", extract "quiet park".
            Just return the extracted keywords, separated by a space. Do not add any other explanation.
            Sentence: "${description}"
        `;
      const extractedKeywords = await callGemini(extractionPrompt);
      keywordParts.push(extractedKeywords.trim());
    }

    if (keywordParts.length === 0) {
      keywordParts.push("공원");
    }

    const searchQuery = keywordParts.join(" ");
    console.log(`Naver Local API 검색어: "${searchQuery}"`);

    const naverDevClientId = process.env.NAVER_DEV_CLIENT_ID;
    const naverDevClientSecret = process.env.NAVER_DEV_CLIENT_SECRET;

    const localSearchApiUrl = new URL(
      "https://openapi.naver.com/v1/search/local.json"
    );
    localSearchApiUrl.searchParams.append("query", searchQuery);
    localSearchApiUrl.searchParams.append("display", "5");
    localSearchApiUrl.searchParams.append("start", "1");
    localSearchApiUrl.searchParams.append("sort", "random");

    const localSearchResponse = await axios.get(localSearchApiUrl.href, {
      headers: {
        "X-Naver-Client-Id": naverDevClientId,
        "X-Naver-Client-Secret": naverDevClientSecret,
      },
    });

    const candidatePlaces = localSearchResponse.data.items.map((item) => ({
      name: item.title.replace(/<[^>]*>/g, ""),
      address: item.roadAddress,
    }));

    console.log("경유지 후보 목록:", candidatePlaces);

    const selectionPrompt = `
      You are an intelligent walk course planner.
      From the given "Candidate Places", select 1 or 2 waypoints that best create a natural walking path from Start to End.
      Pay close attention to the addresses to ensure the selected places are logically located between the start and end points.

      **CRITICAL RULES:**
      1. **Prioritize Detailed Request**: If the user has a "Detailed Request", you MUST prioritize finding a waypoint that matches it from the "Candidate Places".
      2. **Select only from "Candidate Places"**: Do not invent new places.
      3. **JSON Output Only**: The output MUST be a clean JSON array. If no places are suitable, return an empty array [].

      **User Request:**
      - Start: "${start_location_name}"
      - End: "${end_location_name}"
      - Detailed Request: "${description || "None"}"

      **Candidate Places:**
      ${JSON.stringify(candidatePlaces, null, 2)}
    `;

    let selectedWaypointsInfo = [];
    if (candidatePlaces.length > 0) {
      try {
        console.log("Gemini API에 최적 경유지 선택 요청...");
        const jsonText = await callGemini(selectionPrompt);
        selectedWaypointsInfo = JSON.parse(
          jsonText.replace(/```json|```/g, "").trim()
        );
      } catch (e) {
        console.error("Gemini 경유지 선택 응답 처리 중 오류:", e.message);
        selectedWaypointsInfo = [];
      }
    }

    console.log("Gemini API가 선택한 최종 경유지:", selectedWaypointsInfo);

    const ncpClientId = process.env.NAVER_CLIENT_ID;
    const ncpClientSecret = process.env.NAVER_CLIENT_SECRET;
    const waypointCoords = [];

    for (const place of selectedWaypointsInfo) {
      if (!place.address) continue;
      const geocodeApiUrl = new URL(
        "https://maps.apigw.ntruss.com/map-geocode/v2/geocode"
      );
      geocodeApiUrl.searchParams.append("query", place.address);
      const geocodeResponse = await axios.get(geocodeApiUrl.href, {
        headers: {
          "X-NCP-APIGW-API-KEY-ID": ncpClientId,
          "X-NCP-APIGW-API-KEY": ncpClientSecret,
        },
      });
      if (
        geocodeResponse.data.addresses &&
        geocodeResponse.data.addresses.length > 0
      ) {
        const coords = geocodeResponse.data.addresses[0];
        waypointCoords.push(`${coords.x},${coords.y}`);
      }
    }

    const startCoordString = `${start_coords.lng},${start_coords.lat}`;
    const endCoordString = `${end_coords.lng},${end_coords.lat}`;
    const locations = [startCoordString, ...waypointCoords, endCoordString];
    let totalPath = [];
    let totalDistance = 0;

    for (let i = 0; i < locations.length - 1; i++) {
      const directionsApiUrl = new URL(
        "https://maps.apigw.ntruss.com/map-direction/v1/driving"
      );
      directionsApiUrl.searchParams.append("start", locations[i]);
      directionsApiUrl.searchParams.append("goal", locations[i + 1]);
      directionsApiUrl.searchParams.append("option", "trafast");

      const directionsResponse = await axios.get(directionsApiUrl.href, {
        headers: {
          "X-NCP-APIGW-API-KEY-ID": ncpClientId,
          "X-NCP-APIGW-API-KEY": ncpClientSecret,
        },
      });
      if (directionsResponse.data.route) {
        const route = directionsResponse.data.route.trafast[0];
        totalPath.push(...route.path);
        totalDistance += route.summary.distance;
      }
    }

    const path_data = { coordinates: totalPath };
    const distanceInKm = totalDistance / 1000;
    const estimated_time = Math.round((distanceInKm / 4.5) * 60);

    const insertQuery = `
      INSERT INTO Walkway (user_id, title, description, path_data, distance, estimated_time, difficulty, waypoints, start_location_name, end_location_name, tags, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`;
    const params = [
      userId,
      title || "새로운 AI 추천 산책로",
      description,
      JSON.stringify(path_data),
      distanceInKm,
      estimated_time,
      difficulty,
      JSON.stringify(selectedWaypointsInfo.map((wp) => ({ name: wp.name }))),
      start_location_name,
      end_location_name,
      JSON.stringify(tags),
      status,
    ];
    const [result] = await connection.query(insertQuery, params);

    await updateAchievementProgress(userId, "create_walkway", 1, connection);
    await connection.commit();

    res.status(201).json({
      message: "AI 산책로가 성공적으로 생성되었습니다.",
      walkwayId: result.insertId,
    });
  } catch (error) {
    await connection.rollback();
    console.error(
      "--- 산책로 생성 중 오류 발생 ---",
      error.response
        ? JSON.stringify(error.response.data, null, 2)
        : error.message
    );
    res
      .status(500)
      .json({ message: "서버 오류로 인해 산책로를 생성하지 못했습니다." });
  } finally {
    connection.release();
  }
};

const getWalkwayQuery = (userId) => `
  SELECT 
    w.*, 
    u.nickname,
    (SELECT COUNT(*) FROM Walkway_Likes wl WHERE wl.walkway_id = w.walkway_id) as likeCount,
    (SELECT COUNT(*) FROM Walkway_Likes wl WHERE wl.walkway_id = w.walkway_id AND wl.user_id = ?) > 0 as isLiked
  FROM Walkway w 
  JOIN User u ON w.user_id = u.user_id
`;

const processWalkwayResults = (walkways, req) => {
  const baseUrl = `${req.protocol}://${req.get("host")}`;
  return walkways.map((walkway) => {
    try {
      return {
        ...walkway,
        isLiked: !!walkway.isLiked,
        thumbnail_url: walkway.thumbnail_url
          ? `${baseUrl}/${walkway.thumbnail_url}`
          : null,
        path_data:
          typeof walkway.path_data === "string"
            ? JSON.parse(walkway.path_data || "{}")
            : walkway.path_data || {},
        waypoints:
          typeof walkway.waypoints === "string"
            ? JSON.parse(walkway.waypoints || "[]")
            : walkway.waypoints || [],
        tags:
          typeof walkway.tags === "string"
            ? JSON.parse(walkway.tags || "[]")
            : walkway.tags || [],
      };
    } catch (e) {
      return { ...walkway, path_data: {}, waypoints: [], tags: [] };
    }
  });
};

exports.getWalkways = async (req, res) => {
  const userId = req.userData.userId;
  try {
    const fullQuery = `${getWalkwayQuery(userId)} ORDER BY w.created_at DESC`;
    const [allWalkways] = await pool.query(fullQuery, [userId]);
    res.status(200).json(processWalkwayResults(allWalkways, req));
  } catch (error) {
    res
      .status(500)
      .json({ message: "서버 오류로 인해 산책로 목록을 조회하지 못했습니다." });
  }
};

exports.getWalkwayById = async (req, res) => {
  const { id } = req.params;
  const userId = req.userData.userId;
  try {
    const fullQuery = `${getWalkwayQuery(userId)} WHERE w.walkway_id = ?`;
    const [walkways] = await pool.query(fullQuery, [userId, id]);

    if (walkways.length === 0) {
      return res.status(404).json({ message: "산책로를 찾을 수 없습니다." });
    }
    res.status(200).json(processWalkwayResults(walkways, req)[0]);
  } catch (error) {
    res
      .status(500)
      .json({ message: "서버 오류로 인해 산책로 정보를 조회하지 못했습니다." });
  }
};

exports.updateWalkway = async (req, res) => {
  const { id } = req.params;
  const { title, description, status } = req.body;
  const userId = req.userData.userId;

  try {
    const [walkways] = await pool.query(
      "SELECT user_id FROM Walkway WHERE walkway_id = ?",
      [id]
    );
    if (walkways.length === 0)
      return res.status(404).json({ message: "산책로를 찾을 수 없습니다." });
    if (walkways[0].user_id !== userId)
      return res.status(403).json({ message: "수정 권한이 없습니다." });

    await pool.query(
      "UPDATE Walkway SET title = ?, description = ?, status = ? WHERE walkway_id = ?",
      [title, description, status, id]
    );
    res
      .status(200)
      .json({ message: "산책로 정보가 성공적으로 수정되었습니다." });
  } catch (error) {
    res
      .status(500)
      .json({ message: "서버 오류로 인해 산책로 정보를 수정하지 못했습니다." });
  }
};

exports.deleteWalkway = async (req, res) => {
  const { id } = req.params;
  const userId = req.userData.userId;

  try {
    const [walkways] = await pool.query(
      "SELECT user_id FROM Walkway WHERE walkway_id = ?",
      [id]
    );
    if (walkways.length === 0)
      return res.status(404).json({ message: "산책로를 찾을 수 없습니다." });
    if (walkways[0].user_id !== userId)
      return res.status(403).json({ message: "삭제 권한이 없습니다." });

    await pool.query("DELETE FROM Walkway WHERE walkway_id = ?", [id]);
    await updateAchievementProgress(userId, "create_walkway", -1);
    res.status(200).json({ message: "산책로가 성공적으로 삭제되었습니다." });
  } catch (error) {
    res
      .status(500)
      .json({ message: "서버 오류로 인해 산책로를 삭제하지 못했습니다." });
  }
};

exports.likeWalkway = async (req, res) => {
  const userId = req.userData.userId;
  const { id: walkwayId } = req.params;
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const [[walkway]] = await connection.query(
      "SELECT user_id FROM Walkway WHERE walkway_id = ?",
      [walkwayId]
    );
    if (walkway) {
      await updateAchievementProgress(
        walkway.user_id,
        "walkway_liked",
        1,
        connection
      );
    }
    await connection.query(
      "INSERT INTO Walkway_Likes (user_id, walkway_id) VALUES (?, ?)",
      [userId, walkwayId]
    );
    await connection.commit();
    res.status(201).json({ message: "산책로를 추천했습니다." });
  } catch (error) {
    await connection.rollback();
    if (error.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ message: "이미 추천한 산책로입니다." });
    }
    res
      .status(500)
      .json({ message: "서버 오류로 산책로를 추천할 수 없습니다." });
  } finally {
    connection.release();
  }
};

exports.unlikeWalkway = async (req, res) => {
  const userId = req.userData.userId;
  const { id: walkwayId } = req.params;
  try {
    const [result] = await pool.query(
      "DELETE FROM Walkway_Likes WHERE user_id = ? AND walkway_id = ?",
      [userId, walkwayId]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "추천 기록을 찾을 수 없습니다." });
    }
    res.status(200).json({ message: "산책로 추천을 취소했습니다." });
  } catch (error) {
    res.status(500).json({ message: "서버 오류로 추천을 취소할 수 없습니다." });
  }
};

exports.getComments = async (req, res) => {
  const { id } = req.params;
  try {
    const query = `
      SELECT wc.comment_id, wc.content, wc.created_at, wc.user_id, u.nickname
      FROM Walkway_Comment wc
      JOIN User u ON wc.user_id = u.user_id
      WHERE wc.walkway_id = ? 
      ORDER BY wc.created_at ASC
    `;
    const [comments] = await pool.query(query, [id]);
    res.status(200).json(comments);
  } catch (error) {
    res
      .status(500)
      .json({ message: "서버 오류로 인해 댓글을 조회하지 못했습니다." });
  }
};

exports.createComment = async (req, res) => {
  const { id } = req.params;
  const { content } = req.body;
  const userId = req.userData.userId;
  if (!content)
    return res.status(400).json({ message: "댓글 내용이 필요합니다." });
  try {
    const [result] = await pool.query(
      "INSERT INTO Walkway_Comment (walkway_id, user_id, content) VALUES (?, ?, ?)",
      [id, userId, content]
    );
    res.status(201).json({
      message: "댓글이 성공적으로 작성되었습니다.",
      commentId: result.insertId,
    });
  } catch (error) {
    res
      .status(500)
      .json({ message: "서버 오류로 인해 댓글을 작성하지 못했습니다." });
  }
};

exports.deleteComment = async (req, res) => {
  const { commentId } = req.params;
  const userId = req.userData.userId;
  try {
    const [comments] = await pool.query(
      "SELECT user_id FROM Walkway_Comment WHERE comment_id = ?",
      [commentId]
    );
    if (comments.length === 0)
      return res.status(404).json({ message: "댓글을 찾을 수 없습니다." });
    if (comments[0].user_id !== userId)
      return res.status(403).json({ message: "삭제 권한이 없습니다." });

    await pool.query("DELETE FROM Walkway_Comment WHERE comment_id = ?", [
      commentId,
    ]);
    res.status(200).json({ message: "댓글이 성공적으로 삭제되었습니다." });
  } catch (error) {
    res
      .status(500)
      .json({ message: "서버 오류로 인해 댓글을 삭제하지 못했습니다." });
  }
};
