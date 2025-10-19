import 'package:flutter/material.dart';
import 'package:walking_mate_app/models/item_model.dart';
import 'package:walking_mate_app/models/character_model.dart';
import 'package:walking_mate_app/services/character_service.dart';
import 'package:walking_mate_app/services/shop_service.dart';
import 'package:walking_mate_app/services/auth_service.dart';

class CharacterProvider with ChangeNotifier {
  final CharacterService _characterService = CharacterService();
  final ShopService _shopService = ShopService();
  final AuthService _authService = AuthService();

  String _characterType = 'polar_bear';
  String _previewCharacterType = 'polar_bear';
  List<Character> _allCharacters = [];
  List<Item> _ownedItems = [];
  Map<String, int?> _equippedItems = {};
  Map<String, int?> _previewEquippedItems = {};
  int _userPoints = 0;

  String get characterType => _previewCharacterType;
  List<Character> get allCharacters => _allCharacters;
  List<Item> get ownedItems => _ownedItems;
  Map<String, int?> get equippedItems => _equippedItems;
  Map<String, int?> get previewEquippedItems => _previewEquippedItems;
  int get userPoints => _userPoints;

  Future<void> fetchInventory() async {
    final inventoryData = await _characterService.getInventory();

    _characterType = inventoryData['character_type'] ?? 'polar_bear';
    _previewCharacterType = _characterType;

    _allCharacters = (inventoryData['allCharacters'] as List)
        .map((charJson) => Character.fromJson(charJson))
        .toList();

    _ownedItems = (inventoryData['ownedItems'] as List)
        .map((itemJson) => Item.fromJson(itemJson))
        .toList();

    final equippedData =
        inventoryData['equipped_items'] as Map<String, dynamic>;
    _equippedItems =
        equippedData.map((key, value) => MapEntry(key, value as int?));
    _previewEquippedItems = Map.from(_equippedItems);

    await fetchUserPoints();
    notifyListeners();
  }

  Character? getCharacterById(String characterId) {
    try {
      return _allCharacters.firstWhere((char) => char.id == characterId);
    } catch (e) {
      return null;
    }
  }

  Future<void> fetchUserPoints() async {
    try {
      final userProfile = await _authService.getFullUserProfile();
      _userPoints = userProfile['points'] ?? 0;
      notifyListeners();
    } catch (e) {
      // 에러 발생 시 처리
    }
  }

  void setCharacterPreview(String characterId) {
    _previewCharacterType = characterId;
    notifyListeners();
  }

  void equipItemPreview(Item item) {
    _previewEquippedItems[item.type] = item.id;
    notifyListeners();
  }

  void unequipItemPreview(String itemType) {
    _previewEquippedItems[itemType] = null;
    notifyListeners();
  }

  bool isOwned(int itemId) {
    return _ownedItems.any((item) => item.id == itemId);
  }

  Item? getItemById(int itemId) {
    try {
      return _ownedItems.firstWhere((item) => item.id == itemId);
    } catch (e) {
      return null;
    }
  }

  Future<void> purchaseItem(Item item) async {
    if (_userPoints >= item.price) {
      await _shopService.buyItem(item.id);
      await fetchInventory();
    } else {
      throw Exception('포인트가 부족합니다.');
    }
  }

  Future<void> purchaseCharacter(Character character) async {
    if (_userPoints >= character.price) {
      await _characterService.buyCharacter(character.id);
      await fetchInventory();
    } else {
      throw Exception('포인트가 부족합니다.');
    }
  }

  Future<void> saveEquippedItems() async {
    await _characterService.equipItems(
        _previewEquippedItems, _previewCharacterType);
    _equippedItems = Map.from(_previewEquippedItems);
    _characterType = _previewCharacterType;
    notifyListeners();
  }
}
