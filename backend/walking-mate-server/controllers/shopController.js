const pool = require("../config/database");

exports.getItems = async (req, res) => {
  try {
    const [items] = await pool.query("SELECT * FROM Item ORDER BY price ASC");
    res.status(200).json(items);
  } catch (error) {
    res.status(500).json({ message: "아이템 목록을 불러오는 중 오류가 발생했습니다." });
  }
};

exports.buyItem = async (req, res) => {
  const userId = req.userData.userId;
  const { itemId } = req.params;
  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    const [[user]] = await connection.query("SELECT points FROM User WHERE user_id = ? FOR UPDATE", [userId]);
    const [[item]] = await connection.query("SELECT price FROM Item WHERE item_id = ?", [itemId]);

    if (!item) {
      await connection.rollback();
      return res.status(404).json({ message: "존재하지 않는 아이템입니다." });
    }

    if (user.points < item.price) {
      await connection.rollback();
      return res.status(400).json({ message: "포인트가 부족합니다." });
    }

    const [[ownedItem]] = await connection.query("SELECT user_item_id FROM User_Item WHERE user_id = ? AND item_id = ?", [userId, itemId]);
    if (ownedItem) {
      await connection.rollback();
      return res.status(409).json({ message: "이미 보유하고 있는 아이템입니다." });
    }

    await connection.query("UPDATE User SET points = points - ? WHERE user_id = ?", [item.price, userId]);
    await connection.query("INSERT INTO Point_Ledger (user_id, amount, description) VALUES (?, ?, ?)", [userId, -item.price, "상점 아이템 구매"]);
    await connection.query("INSERT INTO User_Item (user_id, item_id) VALUES (?, ?)", [userId, itemId]);

    await connection.commit();
    res.status(200).json({ message: "아이템을 성공적으로 구매했습니다." });
  } catch (error) {
    await connection.rollback();
    res.status(500).json({ message: "아이템 구매 중 오류가 발생했습니다." });
  } finally {
    connection.release();
  }
};
