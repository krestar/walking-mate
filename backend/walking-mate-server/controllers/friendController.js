const pool = require("../config/database");
const db = require("../config/firebaseAdmin");
const admin = require("firebase-admin");
const { updateAchievementProgress } = require("../helpers/achievementHelper");

exports.sendRequest = async (req, res) => {
  const requesterId = req.userData.userId;
  const { receiverId } = req.body;

  if (requesterId === receiverId) {
    return res
      .status(400)
      .json({ message: "자신에게 친구 요청을 보낼 수 없습니다." });
  }

  try {
    const checkQuery = `
            SELECT * FROM Friendship 
            WHERE (requester_id = ? AND receiver_id = ?) OR (requester_id = ? AND receiver_id = ?)
        `;
    const [existing] = await pool.query(checkQuery, [
      requesterId,
      receiverId,
      receiverId,
      requesterId,
    ]);

    if (existing.length > 0) {
      const friendship = existing[0];
      if (friendship.status === "accepted") {
        return res.status(409).json({ message: "이미 워킹메이트 관계입니다." });
      } else if (friendship.status === "pending") {
        return res
          .status(409)
          .json({ message: "이미 친구 요청을 보냈거나 받았습니다." });
      }
    }

    const insertQuery =
      "INSERT INTO Friendship (requester_id, receiver_id) VALUES (?, ?)";
    await pool.query(insertQuery, [requesterId, receiverId]);

    // Firestore 실시간 업데이트 신호 전송
    const updateTime = admin.firestore.FieldValue.serverTimestamp();
    const userRef = db.collection("status_updates").doc(String(receiverId));
    await userRef.set({ friends: updateTime }, { merge: true });

    res
      .status(201)
      .json({ message: "워킹메이트 요청을 성공적으로 보냈습니다." });
  } catch (error) {
    console.error("친구 요청 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 인해 친구 요청을 보내지 못했습니다." });
  }
};

exports.acceptRequest = async (req, res) => {
  const receiverId = req.userData.userId;
  const { friendshipId } = req.body;

  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    const [requests] = await connection.query(
      "SELECT * FROM Friendship WHERE friendship_id = ? AND receiver_id = ? AND status = 'pending'",
      [friendshipId, receiverId]
    );

    if (requests.length === 0) {
      await connection.rollback();
      return res
        .status(404)
        .json({ message: "해당 요청을 찾을 수 없거나 이미 처리되었습니다." });
    }
    const request = requests[0];
    const requesterId = request.requester_id;

    const chatRoomId =
      requesterId < receiverId
        ? `${requesterId}_${receiverId}`
        : `${receiverId}_${requesterId}`;

    const updateQuery =
      "UPDATE Friendship SET status = 'accepted', chat_room_id = ? WHERE friendship_id = ?";
    await connection.query(updateQuery, [chatRoomId, friendshipId]);

    const chatRoomRef = db.collection("chat_rooms").doc(chatRoomId);
    await chatRoomRef.set({
      users: [String(requesterId), String(receiverId)],
      lastMessage: "워킹메이트가 되었습니다! 대화를 시작해보세요.",
      lastMessageTimestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 업적 업데이트
    await updateAchievementProgress(requesterId, "friend_count", 1, connection);
    await updateAchievementProgress(receiverId, "friend_count", 1, connection);

    // Firestore 실시간 업데이트 신호 전송
    const updateTime = admin.firestore.FieldValue.serverTimestamp();
    const user1Ref = db.collection("status_updates").doc(String(requesterId));
    const user2Ref = db.collection("status_updates").doc(String(receiverId));
    await user1Ref.set({ friends: updateTime }, { merge: true });
    await user2Ref.set({ friends: updateTime }, { merge: true });

    await connection.commit();
    res.status(200).json({
      message: "워킹메이트 요청을 수락했습니다.",
      chatRoomId: chatRoomId,
    });
  } catch (error) {
    await connection.rollback();
    console.error("친구 요청 수락 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 인해 친구 요청을 수락하지 못했습니다." });
  } finally {
    connection.release();
  }
};

exports.rejectOrCancelRequest = async (req, res) => {
  const currentUserId = req.userData.userId;
  const { friendshipId } = req.params;

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const [[friendship]] = await connection.query(
      "SELECT requester_id, receiver_id FROM Friendship WHERE friendship_id = ? AND (requester_id = ? OR receiver_id = ?) AND status = 'pending'",
      [friendshipId, currentUserId, currentUserId]
    );

    if (!friendship) {
      await connection.rollback();
      return res.status(404).json({ message: "해당 요청을 찾을 수 없습니다." });
    }

    const { requester_id, receiver_id } = friendship;
    const otherUserId =
      currentUserId === requester_id ? receiver_id : requester_id;

    await connection.query("DELETE FROM Friendship WHERE friendship_id = ?", [
      friendshipId,
    ]);

    // Firestore 실시간 업데이트 신호 전송
    const updateTime = admin.firestore.FieldValue.serverTimestamp();
    const userRef = db.collection("status_updates").doc(String(otherUserId));
    await userRef.set({ friends: updateTime }, { merge: true });

    await connection.commit();
    res.status(200).json({ message: "요청을 처리했습니다." });
  } catch (error) {
    await connection.rollback();
    console.error("친구 요청 거절/취소 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 인해 요청을 처리하지 못했습니다." });
  } finally {
    connection.release();
  }
};

exports.listFriends = async (req, res) => {
  const userId = req.userData.userId;
  try {
    const query = `
      SELECT 
        f.friendship_id,
        u.user_id, 
        u.nickname, 
        u.profile_image_url,
        f.status,
        f.chat_room_id
      FROM Friendship f
      JOIN User u ON 
          CASE
              WHEN f.requester_id = ? THEN f.receiver_id
              ELSE f.requester_id
          END = u.user_id
      WHERE (f.requester_id = ? OR f.receiver_id = ?) AND f.status = 'accepted'
    `;
    const [friends] = await pool.query(query, [userId, userId, userId]);
    res.status(200).json(friends);
  } catch (error) {
    console.error("친구 목록 조회 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 인해 친구 목록을 조회하지 못했습니다." });
  }
};

exports.listAllRequests = async (req, res) => {
  const userId = req.userData.userId;
  try {
    const receivedQuery = `
      SELECT f.friendship_id, u.user_id, u.nickname, u.profile_image_url, 'received' as type, f.status
      FROM Friendship f
      JOIN User u ON f.requester_id = u.user_id
      WHERE f.receiver_id = ? AND f.status = 'pending'
    `;
    const [received] = await pool.query(receivedQuery, [userId]);

    const sentQuery = `
      SELECT f.friendship_id, u.user_id, u.nickname, u.profile_image_url, 'sent' as type, f.status
      FROM Friendship f
      JOIN User u ON f.receiver_id = u.user_id
      WHERE f.requester_id = ? AND f.status = 'pending'
    `;
    const [sent] = await pool.query(sentQuery, [userId]);

    res.status(200).json({ received, sent });
  } catch (error) {
    console.error("친구 요청 목록 조회 중 오류:", error);
    res
      .status(500)
      .json({
        message: "서버 오류로 인해 친구 요청 목록을 조회하지 못했습니다.",
      });
  }
};

exports.deleteFriend = async (req, res) => {
  const userId = req.userData.userId;
  const { friendshipId } = req.params;
  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    const [friendship] = await connection.query(
      "SELECT requester_id, receiver_id FROM Friendship WHERE friendship_id = ? AND (requester_id = ? OR receiver_id = ?) AND status = 'accepted'",
      [friendshipId, userId, userId]
    );

    if (friendship.length === 0) {
      await connection.rollback();
      return res
        .status(404)
        .json({ message: "워킹메이트 관계가 아니거나 이미 삭제되었습니다." });
    }

    const { requester_id, receiver_id } = friendship[0];
    const otherUserId = userId === requester_id ? receiver_id : requester_id;

    const [result] = await connection.query(
      "DELETE FROM Friendship WHERE friendship_id = ?",
      [friendshipId]
    );

    if (result.affectedRows > 0) {
      await updateAchievementProgress(userId, "friend_count", -1, connection);
      await updateAchievementProgress(
        otherUserId,
        "friend_count",
        -1,
        connection
      );

      const updateTime = admin.firestore.FieldValue.serverTimestamp();
      const user1Ref = db.collection("status_updates").doc(String(userId));
      const user2Ref = db.collection("status_updates").doc(String(otherUserId));
      await user1Ref.set({ friends: updateTime }, { merge: true });
      await user2Ref.set({ friends: updateTime }, { merge: true });
    }

    await connection.commit();
    res.status(200).json({ message: "워킹메이트를 삭제했습니다." });
  } catch (error) {
    await connection.rollback();
    console.error("친구 삭제 중 오류:", error);
    res
      .status(500)
      .json({ message: "서버 오류로 인해 친구를 삭제하지 못했습니다." });
  } finally {
    connection.release();
  }
};
