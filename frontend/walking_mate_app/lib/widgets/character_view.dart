import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walking_mate_app/models/character_model.dart';
import 'package:walking_mate_app/providers/character_provider.dart';
import 'package:walking_mate_app/widgets/sprite_animator.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:walking_mate_app/utils/api_config.dart';
import 'package:walking_mate_app/models/item_model.dart';

class CharacterView extends StatefulWidget {
  final String animationType;

  const CharacterView({super.key, required this.animationType});

  @override
  State<CharacterView> createState() => _CharacterViewState();
}

class _CharacterViewState extends State<CharacterView> {
  ui.Image? _spritesheet;
  bool _isLoading = true;
  String _currentCharacterType = '';
  List<FrameData> _currentFrames = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final characterProvider = Provider.of<CharacterProvider>(context);
    if (_currentCharacterType != characterProvider.characterType) {
      _loadCharacterData();
    }
  }

  Future<void> _loadCharacterData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final characterProvider = Provider.of<CharacterProvider>(context, listen: false);
    _currentCharacterType = characterProvider.characterType;

    final currentCharacter = characterProvider.getCharacterById(_currentCharacterType);
    _currentFrames = currentCharacter?.animations[widget.animationType] ?? [];

    if (_currentFrames.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final assetPath = 'assets/sprites/${_currentCharacterType}_${widget.animationType}.png';
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final ui.FrameInfo fi = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _spritesheet = fi.image;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('스프라이트 시트 로딩 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_spritesheet == null || _currentFrames.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
            SizedBox(height: 8),
            Text('애니메이션을\n표시할 수 없습니다.', textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final characterProvider = Provider.of<CharacterProvider>(context);
    final equippedItems = characterProvider.previewEquippedItems;

    final itemPositions = {
      'head': const Offset(0, -100),
      'wings': const Offset(0, 10),
      'right_arm': const Offset(75, -10),
      'body': const Offset(0, 90),
    };

    final itemScales = {
      'head': 0.6,
      'wings': 1.2,
      'right_arm': 0.4,
      'body': 1.4,
    };

    return Stack(
      alignment: Alignment.center,
      children: [
        if (equippedItems['wings'] != null)
          _buildItemLayer(context, 'wings', equippedItems['wings']!, itemPositions['wings']!, itemScales['wings']!),

        SizedBox(
          width: 200,
          height: 200,
          child: SpriteAnimator(
            image: _spritesheet!,
            frames: _currentFrames,
          ),
        ),

        if (equippedItems['body'] != null)
          _buildItemLayer(context, 'body', equippedItems['body']!, itemPositions['body']!, itemScales['body']!),

        if (equippedItems['right_arm'] != null)
          _buildItemLayer(context, 'right_arm', equippedItems['right_arm']!, itemPositions['right_arm']!, itemScales['right_arm']!),

        if (equippedItems['head'] != null)
          _buildItemLayer(context, 'head', equippedItems['head']!, itemPositions['head']!, itemScales['head']!),
      ],
    );
  }

  Widget _buildItemLayer(BuildContext context, String type, int itemId, Offset position, double scale) {
    final characterProvider = Provider.of<CharacterProvider>(context, listen: false);
    final Item? item = characterProvider.getItemById(itemId);

    if (item == null) {
      return const SizedBox.shrink();
    }

    final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    final fullImageUrl = '$baseUrl/${item.imageUrl}';

    return Transform.translate(
      offset: position,
      child: Transform.scale(
        scale: scale,
        child: Image.network(
          fullImageUrl,
          width: 200,
          height: 200,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
        ),
      ),
    );
  }
}