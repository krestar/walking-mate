// frontend/walking_mate_app/lib/screens/costume_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walking_mate_app/providers/character_provider.dart';
import 'package:walking_mate_app/widgets/character_view.dart';
import 'package:walking_mate_app/models/item_model.dart';
import 'package:walking_mate_app/models/character_model.dart';
import 'package:walking_mate_app/services/shop_service.dart';
import 'package:walking_mate_app/utils/api_config.dart';

class CostumeScreen extends StatelessWidget {
  const CostumeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: Provider.of<CharacterProvider>(context, listen: false)
        ..fetchInventory(),
      child: const CostumeViewWrapper(),
    );
  }
}

class CostumeViewWrapper extends StatelessWidget {
  const CostumeViewWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, characterProvider, child) {
        return const CostumeView();
      },
    );
  }
}

class CostumeView extends StatefulWidget {
  const CostumeView({super.key});

  @override
  State<CostumeView> createState() => _CostumeViewState();
}

class _CostumeViewState extends State<CostumeView> {
  String _selectedCategory = 'character';
  Future<List<Item>>? _itemsFuture;
  final ShopService _shopService = ShopService();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    setState(() {
      _itemsFuture = _shopService.getItems();
    });
  }

  void _showSaveMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('저장되었습니다!'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showPurchaseDialog(dynamic itemOrChar, CharacterProvider provider) {
    bool isItem = itemOrChar is Item;
    String name = isItem ? itemOrChar.name : (itemOrChar as Character).name;
    int price = isItem ? itemOrChar.price : (itemOrChar as Character).price;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(isItem ? '아이템 구매' : '캐릭터 구매'),
        content: Text(
            '$name 을(를) ${price}P에 구매하시겠습니까?\n(현재 보유: ${provider.userPoints}P)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                if (isItem) {
                  await provider.purchaseItem(itemOrChar);
                } else {
                  await provider.purchaseCharacter(itemOrChar);
                }
                if (!mounted) return;
                Navigator.of(dialogContext).pop();
              } catch (e) {
                if (!mounted) return;
                final currentContext = context;
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(currentContext).showSnackBar(
                  SnackBar(
                      content: Text(
                          '구매 실패: ${e.toString().replaceAll("Exception: ", "")}')),
                );
              }
            },
            child: const Text('구매'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final characterProvider = Provider.of<CharacterProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('캐릭터 꾸미기'),
        actions: [
          TextButton(
            onPressed: () {
              characterProvider.saveEquippedItems();
              _showSaveMessage();
            },
            child: const Text('저장하기'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              avatar: const Icon(Icons.star, color: Colors.amber),
              label: Text('${characterProvider.userPoints} P'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.grey[200],
              child: const CharacterView(animationType: 'dance'),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCategoryIcon('character', '캐릭터', Icons.person_outline),
                _buildCategoryIcon('head', '머리', Icons.face_retouching_natural),
                _buildCategoryIcon('wings', '날개', Icons.auto_awesome),
                _buildCategoryIcon('right_arm', '팔', Icons.pan_tool_outlined),
                _buildCategoryIcon('body', '옷', Icons.checkroom),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _selectedCategory == 'character'
                  ? _buildCharacterGrid()
                  : _buildItemGrid(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryIcon(String category, String label, IconData icon) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? const Color(0xFF3ED2B3) : Colors.grey[200],
            ),
            child:
                Icon(icon, color: isSelected ? Colors.white : Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? const Color(0xFF3ED2B3) : Colors.black)),
        ],
      ),
    );
  }

  Widget _buildCharacterGrid() {
    final characterProvider = Provider.of<CharacterProvider>(context);
    final characters = characterProvider.allCharacters;

    return GridView.builder(
      key: const ValueKey('characters'),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: characters.length,
      itemBuilder: (context, index) {
        final character = characters[index];
        final isSelected = characterProvider.characterType == character.id;
        final isOwned = character.isOwned;

        return Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: isOwned
                    ? () => characterProvider.setCharacterPreview(character.id)
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: isOwned ? Colors.grey[100] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: const Color(0xFF3ED2B3), width: 3)
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset(
                      'assets/thumbnails/${character.id}_thumb.png',
                      color:
                          isOwned ? null : const Color.fromRGBO(0, 0, 0, 0.4),
                      colorBlendMode: isOwned ? null : BlendMode.dstATop,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            isOwned
                ? ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(80, 36)),
                    onPressed: () =>
                        characterProvider.setCharacterPreview(character.id),
                    child: const Text('선택'),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(80, 36)),
                    onPressed: () =>
                        _showPurchaseDialog(character, characterProvider),
                    child: Text('${character.price} P'),
                  )
          ],
        );
      },
    );
  }

  Widget _buildItemGrid() {
    final characterProvider =
        Provider.of<CharacterProvider>(context, listen: false);

    return FutureBuilder<List<Item>>(
      key: ValueKey(_selectedCategory),
      future: _itemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text('아이템을 불러올 수 없습니다.'));
        }

        final allItems = snapshot.data!;
        final filteredItems =
            allItems.where((item) => item.type == _selectedCategory).toList();

        final displayItems = [null, ...filteredItems];

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.75,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: displayItems.length,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildUnequipButton(characterProvider);
            }

            final item = displayItems[index]!;
            final isOwned = characterProvider.isOwned(item.id);
            final isEquipped =
                characterProvider.previewEquippedItems[_selectedCategory] ==
                    item.id;

            final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
            final fullImageUrl = '$baseUrl/${item.imageUrl}';

            return Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: isEquipped
                          ? Border.all(color: const Color(0xFF3ED2B3), width: 3)
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.network(
                        fullImageUrl,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.error),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                isOwned
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(80, 36)),
                        onPressed: () =>
                            characterProvider.equipItemPreview(item),
                        child: const Text('착용'),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(80, 36)),
                        onPressed: () =>
                            _showPurchaseDialog(item, characterProvider),
                        child: Text('${item.price} P'),
                      )
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildUnequipButton(CharacterProvider provider) {
    final isSelected = provider.previewEquippedItems[_selectedCategory] == null;

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => provider.unequipItemPreview(_selectedCategory),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: const Color(0xFF3ED2B3), width: 3)
                    : null,
              ),
              child: const Center(
                  child:
                      Icon(Icons.not_interested, size: 40, color: Colors.grey)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text('해제', style: TextStyle(fontSize: 14)),
      ],
    );
  }
}
