const pool = require("../config/database");
const { updateAchievementProgress } = require("../helpers/achievementHelper");

// --- 크루 관련 ---
exports.createCrew = async (req, res) => {
  const userId = req.userData.userId;
  const { crew_name, description } = req.body;
  if (!crew_name) {
    return res.status(400).json({ message: "크루 이름은 필수입니다." });
  }

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const createCrewQuery =
      "INSERT INTO Crew (crew_name, description, leader_id) VALUES (?, ?, ?)";
    const [crewResult] = await connection.query(createCrewQuery, [
      crew_name,
      description,
      userId,
    ]);
    const crewId = crewResult.insertId;

    const addMemberQuery =
      "INSERT INTO Crew_Member (crew_id, user_id, role) VALUES (?, ?, 'leader')";
    await connection.query(addMemberQuery, [crewId, userId]);

    // 업적 업데이트
    await updateAchievementProgress(userId, "create_crew", 1, connection);

    await connection.commit();
    res
      .status(201)
      .json({ message: "크루가 성공적으로 생성되었습니다.", crewId: crewId });
  } catch (error) {
    await connection.rollback();
    if (error.code === "ER_DUP_ENTRY") {
      return res
        .status(409)
        .json({ message: "이미 사용 중인 크루 이름입니다." });
    }
    console.error("크루 생성 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 인해 크루를 생성하지 못했습니다." });
  } finally {
    connection.release();
  }
};

exports.joinCrew = async (req, res) => {
  const userId = req.userData.userId;
  const { crewId } = req.params;

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const [existingMemberships] = await connection.query(
      "SELECT crew_id FROM Crew_Member WHERE user_id = ? AND crew_id = ?",
      [userId, crewId]
    );

    if (existingMemberships.length > 0) {
      await connection.rollback();
      return res.status(409).json({ message: "이미 가입된 크루입니다." });
    }

    const addMemberQuery =
      "INSERT INTO Crew_Member (crew_id, user_id, role) VALUES (?, ?, 'member')";
    await connection.query(addMemberQuery, [crewId, userId]);

    // 업적 업데이트
    await updateAchievementProgress(userId, "join_crew", 1, connection);

    await connection.commit();
    res.status(200).json({ message: "크루에 성공적으로 가입했습니다." });
  } catch (error) {
    await connection.rollback();
    console.error("크루 가입 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 인해 크루에 가입하지 못했습니다." });
  } finally {
    connection.release();
  }
};

exports.leaveCrew = async (req, res) => {
  const userId = req.userData.userId;
  const { crewId } = req.params;

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const [member] = await connection.query(
      "SELECT role FROM Crew_Member WHERE user_id = ? AND crew_id = ?",
      [userId, crewId]
    );

    if (member.length === 0) {
      await connection.rollback();
      return res.status(404).json({ message: "가입 정보가 없습니다." });
    }

    if (member[0].role === "leader") {
      const [memberCount] = await connection.query(
        "SELECT COUNT(*) as count FROM Crew_Member WHERE crew_id = ?",
        [crewId]
      );
      if (memberCount[0].count > 1) {
        await connection.rollback();
        return res
          .status(403)
          .json({
            message:
              "다른 멤버가 있는 경우 크루장은 탈퇴할 수 없습니다. 크루를 삭제해주세요.",
          });
      }
      await connection.query("DELETE FROM Crew WHERE crew_id = ?", [crewId]);
    } else {
      await connection.query(
        "DELETE FROM Crew_Member WHERE user_id = ? AND crew_id = ?",
        [userId, crewId]
      );
    }

    await connection.commit();
    res.status(200).json({ message: "크루에서 탈퇴했습니다." });
  } catch (error) {
    await connection.rollback();
    console.error("크루 탈퇴 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 크루에서 탈퇴하지 못했습니다." });
  } finally {
    connection.release();
  }
};

exports.deleteCrew = async (req, res) => {
  const userId = req.userData.userId;
  const { crewId } = req.params;
  try {
    const [crew] = await pool.query(
      "SELECT leader_id FROM Crew WHERE crew_id = ?",
      [crewId]
    );
    if (crew.length === 0) {
      return res.status(404).json({ message: "존재하지 않는 크루입니다." });
    }
    if (crew[0].leader_id !== userId) {
      return res
        .status(403)
        .json({ message: "크루를 삭제할 권한이 없습니다." });
    }
    await pool.query("DELETE FROM Crew WHERE crew_id = ?", [crewId]);
    res.status(200).json({ message: "크루가 성공적으로 삭제되었습니다." });
  } catch (error) {
    console.error("크루 삭제 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 크루를 삭제하지 못했습니다." });
  }
};

exports.getMyCrews = async (req, res) => {
  const userId = req.userData.userId;
  try {
    const query = `
      SELECT c.crew_id, c.crew_name, c.description, c.leader_id,
      (SELECT COUNT(*) FROM Crew_Member cm WHERE cm.crew_id = c.crew_id) as member_count
      FROM Crew c
      JOIN Crew_Member cm ON c.crew_id = cm.crew_id
      WHERE cm.user_id = ?
    `;
    const [crews] = await pool.query(query, [userId]);
    res.status(200).json(crews);
  } catch (error) {
    console.error("가입한 크루 목록 조회 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 목록을 조회하지 못했습니다." });
  }
};

exports.getCrewMembers = async (req, res) => {
  const { crewId } = req.params;
  try {
    const query = `
      SELECT u.user_id, u.nickname, u.profile_image_url, cm.role
      FROM User u
      JOIN Crew_Member cm ON u.user_id = cm.user_id
      WHERE cm.crew_id = ?
    `;
    const [members] = await pool.query(query, [crewId]);
    res.status(200).json(members);
  } catch (error) {
    console.error("크루 멤버 목록 조회 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 멤버 목록을 조회하지 못했습니다." });
  }
};

exports.removeCrewMember = async (req, res) => {
  const leaderId = req.userData.userId;
  const { crewId, memberId } = req.params;

  if (leaderId === parseInt(memberId, 10)) {
    return res
      .status(400)
      .json({ message: "크루장은 자신을 추방할 수 없습니다." });
  }

  try {
    const [crew] = await pool.query(
      "SELECT leader_id FROM Crew WHERE crew_id = ?",
      [crewId]
    );
    if (crew.length === 0 || crew[0].leader_id !== leaderId) {
      return res
        .status(403)
        .json({ message: "멤버를 추방할 권한이 없습니다." });
    }

    const [result] = await pool.query(
      "DELETE FROM Crew_Member WHERE crew_id = ? AND user_id = ? AND role = 'member'",
      [crewId, memberId]
    );

    if (result.affectedRows === 0) {
      return res
        .status(404)
        .json({ message: "해당 멤버를 찾을 수 없거나 이미 추방되었습니다." });
    }

    res.status(200).json({ message: "멤버를 성공적으로 추방했습니다." });
  } catch (error) {
    console.error("멤버 추방 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 멤버를 추방하지 못했습니다." });
  }
};

// --- 게시글 관련 ---
exports.getPosts = async (req, res) => {
  const { crewId } = req.params;
  try {
    const getPostsQuery = `
      SELECT p.post_id, p.user_id, p.title, p.content, p.created_at, u.nickname 
      FROM Community_Post p
      JOIN User u ON p.user_id = u.user_id
      WHERE p.crew_id = ? 
      ORDER BY p.created_at DESC`;
    const [posts] = await pool.query(getPostsQuery, [crewId]);
    res.status(200).json(posts);
  } catch (error) {
    console.error("게시글 목록 조회 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 게시글 목록을 조회하지 못했습니다." });
  }
};

exports.createPost = async (req, res) => {
  const userId = req.userData.userId;
  const { crewId } = req.params;
  const { title, content } = req.body;
  if (!title || !content) {
    return res.status(400).json({ message: "제목과 내용은 필수입니다." });
  }

  try {
    const createPostQuery =
      "INSERT INTO Community_Post (user_id, crew_id, title, content) VALUES (?, ?, ?, ?)";
    const [result] = await pool.query(createPostQuery, [
      userId,
      crewId,
      title,
      content,
    ]);

    // 업적 업데이트
    await updateAchievementProgress(userId, "create_post", 1);

    res.status(201).json({
      message: "게시글이 성공적으로 작성되었습니다.",
      postId: result.insertId,
    });
  } catch (error) {
    console.error("게시글 작성 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 게시글을 작성하지 못했습니다." });
  }
};

exports.updatePost = async (req, res) => {
  const userId = req.userData.userId;
  const { postId } = req.params;
  const { title, content } = req.body;

  if (!title || !content) {
    return res.status(400).json({ message: "제목과 내용은 필수입니다." });
  }

  try {
    const [posts] = await pool.query(
      "SELECT user_id FROM Community_Post WHERE post_id = ?",
      [postId]
    );
    if (posts.length === 0) {
      return res.status(404).json({ message: "존재하지 않는 게시글입니다." });
    }
    if (posts[0].user_id !== userId) {
      return res
        .status(403)
        .json({ message: "게시글을 수정할 권한이 없습니다." });
    }

    const query =
      "UPDATE Community_Post SET title = ?, content = ? WHERE post_id = ?";
    await pool.query(query, [title, content, postId]);
    res.status(200).json({ message: "게시글이 성공적으로 수정되었습니다." });
  } catch (error) {
    console.error("게시글 수정 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 게시글을 수정하지 못했습니다." });
  }
};

exports.deletePost = async (req, res) => {
  const userId = req.userData.userId;
  const { postId } = req.params;
  try {
    const [posts] = await pool.query(
      "SELECT user_id FROM Community_Post WHERE post_id = ?",
      [postId]
    );
    if (posts.length === 0) {
      return res.status(404).json({ message: "존재하지 않는 게시글입니다." });
    }
    if (posts[0].user_id !== userId) {
      return res
        .status(403)
        .json({ message: "게시글을 삭제할 권한이 없습니다." });
    }
    await pool.query("DELETE FROM Community_Post WHERE post_id = ?", [postId]);
    res.status(200).json({ message: "게시글이 성공적으로 삭제되었습니다." });
  } catch (error) {
    console.error("게시글 삭제 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 게시글을 삭제하지 못했습니다." });
  }
};

// --- 추천(좋아요) 관련 ---
exports.likePost = async (req, res) => {
  const userId = req.userData.userId;
  const { postId } = req.params;
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const [[like]] = await connection.query(
      "SELECT * FROM Community_Post_Likes WHERE post_id = ? AND user_id = ?",
      [postId, userId]
    );

    if (like) {
      await connection.rollback();
      return res.status(409).json({ message: "이미 추천한 게시글입니다." });
    }

    await connection.query(
      "INSERT INTO Community_Post_Likes (post_id, user_id) VALUES (?, ?)",
      [postId, userId]
    );

    const [[post]] = await connection.query(
      "SELECT user_id FROM Community_Post WHERE post_id = ?",
      [postId]
    );
    if (post) {
      await updateAchievementProgress(
        post.user_id,
        "post_liked",
        1,
        connection
      );
    }

    await connection.commit();
    res.status(200).json({ message: "게시글을 추천했습니다." });
  } catch (error) {
    await connection.rollback();
    console.error("게시글 추천 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 게시글을 추천할 수 없었습니다." });
  } finally {
    connection.release();
  }
};

// --- 댓글 관련 ---
exports.getComments = async (req, res) => {
  const { postId } = req.params;
  try {
    const getCommentsQuery = `
      SELECT c.comment_id, c.content, c.created_at, c.user_id, u.nickname 
      FROM Community_Comment c
      JOIN User u ON c.user_id = u.user_id
      WHERE c.post_id = ? 
      ORDER BY c.created_at ASC`;
    const [comments] = await pool.query(getCommentsQuery, [postId]);
    res.status(200).json(comments);
  } catch (error) {
    console.error("댓글 목록 조회 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 댓글 목록을 조회하지 못했습니다." });
  }
};

exports.createComment = async (req, res) => {
  const userId = req.userData.userId;
  const { postId } = req.params;
  const { content } = req.body;
  if (!content) {
    return res.status(400).json({ message: "댓글 내용이 필요합니다." });
  }
  try {
    const createCommentQuery =
      "INSERT INTO Community_Comment (post_id, user_id, content) VALUES (?, ?, ?)";
    const [result] = await pool.query(createCommentQuery, [
      postId,
      userId,
      content,
    ]);

    // 업적 업데이트
    await updateAchievementProgress(userId, "create_comment", 1);

    res.status(201).json({
      message: "댓글이 성공적으로 작성되었습니다.",
      commentId: result.insertId,
    });
  } catch (error) {
    console.error("댓글 작성 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 댓글을 작성하지 못했습니다." });
  }
};

exports.deleteComment = async (req, res) => {
  const userId = req.userData.userId;
  const { commentId } = req.params;
  try {
    const [comments] = await pool.query(
      "SELECT user_id FROM Community_Comment WHERE comment_id = ?",
      [commentId]
    );
    if (comments.length === 0) {
      return res.status(404).json({ message: "존재하지 않는 댓글입니다." });
    }
    if (comments[0].user_id !== userId) {
      return res
        .status(403)
        .json({ message: "댓글을 삭제할 권한이 없습니다." });
    }
    await pool.query("DELETE FROM Community_Comment WHERE comment_id = ?", [
      commentId,
    ]);
    res.status(200).json({ message: "댓글이 성공적으로 삭제되었습니다." });
  } catch (error) {
    console.error("댓글 삭제 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 댓글을 삭제하지 못했습니다." });
  }
};

// --- 탐색 관련 ---
exports.searchCrews = async (req, res) => {
  const { term } = req.query;

  try {
    let searchQuery = `
      SELECT c.crew_id, c.crew_name, c.description, c.leader_id,
             (SELECT COUNT(*) FROM Crew_Member cm WHERE cm.crew_id = c.crew_id) as member_count
      FROM Crew c`;
    const params = [];

    if (term && term.trim() !== "") {
      searchQuery += ` WHERE c.crew_name LIKE ?`;
      params.push(`%${term}%`);
    }

    searchQuery += ` ORDER BY member_count DESC`;

    const [crews] = await pool.query(searchQuery, params);
    res.status(200).json(crews);
  } catch (error) {
    console.error("크루 검색 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 인해 크루를 검색하지 못했습니다." });
  }
};

exports.searchUsers = async (req, res) => {
  const userId = req.userData.userId;
  const { term, location } = req.query;

  try {
    let searchQuery = `
      SELECT user_id, nickname, profile_image_url, location 
      FROM User 
      WHERE discoverable = 1 AND user_id != ?`;
    const params = [userId];

    if (term && term.trim() !== "") {
      searchQuery += " AND nickname LIKE ?";
      params.push(`%${term}%`);
    }

    if (location) {
      searchQuery += " AND location LIKE ?";
      params.push(`%${location}%`);
    }

    searchQuery += ` ORDER BY nickname ASC`;

    const [users] = await pool.query(searchQuery, params);
    res.status(200).json(users);
  } catch (error) {
    console.error("사용자 검색 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 인해 사용자를 검색하지 못했습니다." });
  }
};
