const pool = require("../config/database");

exports.getInventory = async (req, res) => {
  const userId = req.userData.userId;
  try {
    // 1. 모든 캐릭터 기본 정보 가져오기
    const [allCharactersInfo] = await pool.query(
      "SELECT * FROM All_Characters"
    );

    // 2. 모든 캐릭터의 스프라이트 프레임 정보 가져오기
    const [allFrames] = await pool.query(
      "SELECT * FROM Sprite_Frame ORDER BY character_id, animation_type, frame_number ASC"
    );

    // 3. 캐릭터 ID별로 프레임 정보를 정리
    const framesByCharacter = {};
    for (const frame of allFrames) {
      if (!framesByCharacter[frame.character_id]) {
        framesByCharacter[frame.character_id] = {};
      }
      if (!framesByCharacter[frame.character_id][frame.animation_type]) {
        framesByCharacter[frame.character_id][frame.animation_type] = [];
      }
      framesByCharacter[frame.character_id][frame.animation_type].push({
        x: frame.x,
        y: frame.y,
        width: frame.width,
        height: frame.height,
      });
    }

    // 4. 사용자가 소유한 캐릭터 ID 목록 가져오기
    const [ownedCharacterIds] = await pool.query(
      "SELECT character_id FROM User_Character WHERE user_id = ?",
      [userId]
    );
    const ownedIdsSet = new Set(ownedCharacterIds.map((c) => c.character_id));

    // 5. 최종 캐릭터 목록 생성 (소유 여부 및 애니메이션 정보 포함)
    const charactersWithDetails = allCharactersInfo.map((char) => ({
      ...char,
      isOwned: ownedIdsSet.has(char.character_id),
      animations: framesByCharacter[char.character_id] || {},
    }));

    // 6. 사용자가 소유한 아이템 및 현재 캐릭터 정보 가져오기
    const [ownedItems] = await pool.query(
      "SELECT i.* FROM User_Item ui JOIN Item i ON ui.item_id = i.item_id WHERE ui.user_id = ?",
      [userId]
    );
    const [[character]] = await pool.query(
      "SELECT character_type, equipped_items FROM `Character` WHERE user_id = ?",
      [userId]
    );

    res.status(200).json({
      allCharacters: charactersWithDetails,
      character_type: character ? character.character_type : "polar_bear",
      ownedItems: ownedItems,
      equipped_items: character ? character.equipped_items : {},
    });
  } catch (error) {
    console.error("인벤토리 정보 로딩 중 오류:", error);
    res
      .status(500)
      .json({ message: "인벤토리 정보를 불러오는 중 오류가 발생했습니다." });
  }
};

// buyCharacter와 equipItems 함수는 기존과 동일하게 유지됩니다.
exports.buyCharacter = async (req, res) => {
  const userId = req.userData.userId;
  const { characterId } = req.params;
  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    const [[user]] = await connection.query(
      "SELECT points FROM User WHERE user_id = ? FOR UPDATE",
      [userId]
    );
    const [[characterToBuy]] = await connection.query(
      "SELECT price FROM All_Characters WHERE character_id = ?",
      [characterId]
    );

    if (!characterToBuy) {
      await connection.rollback();
      return res.status(404).json({ message: "존재하지 않는 캐릭터입니다." });
    }
    if (user.points < characterToBuy.price) {
      await connection.rollback();
      return res.status(400).json({ message: "포인트가 부족합니다." });
    }

    await connection.query(
      "UPDATE User SET points = points - ? WHERE user_id = ?",
      [characterToBuy.price, userId]
    );
    await connection.query(
      "INSERT INTO Point_Ledger (user_id, amount, description) VALUES (?, ?, ?)",
      [userId, -characterToBuy.price, "캐릭터 구매"]
    );
    await connection.query(
      "INSERT INTO User_Character (user_id, character_id) VALUES (?, ?)",
      [userId, characterId]
    );

    await connection.commit();
    res.status(200).json({ message: "캐릭터를 성공적으로 구매했습니다." });
  } catch (error) {
    await connection.rollback();
    if (error.code === "ER_DUP_ENTRY") {
      return res
        .status(409)
        .json({ message: "이미 보유하고 있는 캐릭터입니다." });
    }
    res.status(500).json({ message: "캐릭터 구매 중 오류가 발생했습니다." });
  } finally {
    connection.release();
  }
};

exports.equipItems = async (req, res) => {
  const userId = req.userData.userId;
  const { items, characterType } = req.body;

  if (!items || typeof items !== "object" || !characterType) {
    return res
      .status(400)
      .json({ message: "잘못된 아이템 또는 캐릭터 정보입니다." });
  }

  try {
    await pool.query(
      "UPDATE `Character` SET equipped_items = ?, character_type = ? WHERE user_id = ?",
      [JSON.stringify(items), characterType, userId]
    );
    res
      .status(200)
      .json({ message: "캐릭터 정보가 성공적으로 저장되었습니다." });
  } catch (error) {
    res
      .status(500)
      .json({ message: "캐릭터 정보 저장 중 오류가 발생했습니다." });
  }
};
