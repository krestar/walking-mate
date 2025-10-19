import 'package:flutter/material.dart';
import 'package:walking_mate_app/screens/crew_creation_screen.dart';
import 'package:walking_mate_app/screens/friends_screen.dart';
import 'package:walking_mate_app/screens/search_screen.dart';
import 'package:walking_mate_app/services/community_service.dart';
import 'package:walking_mate_app/models/community_model.dart';
import 'package:walking_mate_app/screens/crew_detail_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CommunityService _communityService = CommunityService();
  Future<List<Crew>>? _myCrewsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyCrews();
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyCrews() async {
    if (!mounted) return;
    setState(() {
      _myCrewsFuture = _communityService.getMyCrews();
    });
  }

  void _navigateToCrewCreation() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CrewCreationScreen()),
    );
    if (result == true && mounted) {
      _loadMyCrews();
    }
  }

  void _navigateToSearch() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SearchScreen()),
    );
    if (result == true && mounted) {
      _loadMyCrews();
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color themeColor = Color(0xFF3ED2B3);

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('커뮤니티', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '크루/친구 찾기',
            onPressed: _navigateToSearch,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: themeColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: themeColor,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: '나의 크루'),
            Tab(text: '워킹메이트'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCrewTab(),
          const FriendsScreen(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_tabController.index == 0) {
      return FloatingActionButton(
        heroTag: 'crew_fab',
        onPressed: _navigateToCrewCreation,
        backgroundColor: const Color(0xFF3ED2B3),
        child: const Icon(Icons.add, color: Colors.white),
      );
    }
    return null;
  }

  Widget _buildCrewTab() {
    return FutureBuilder<List<Crew>>(
      future: _myCrewsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('크루 목록을 불러오는 데 실패했습니다: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return RefreshIndicator(
            onRefresh: _loadMyCrews,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.5,
                alignment: Alignment.center,
                child: const Text('가입한 크루가 없습니다.\n크루를 찾아 가입하거나 직접 만들어보세요!'),
              ),
            ),
          );
        }

        final myCrews = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _loadMyCrews,
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: myCrews.length,
            itemBuilder: (context, index) {
              return _buildCrewCard(myCrews[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildCrewCard(Crew crew) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: InkWell(
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CrewDetailScreen(crew: crew),
            ),
          );
          if (result == true && mounted) {
            _loadMyCrews();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(crew.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                crew.description,
                style: TextStyle(color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.group_outlined, size: 16, color: Colors.grey[700]),
                  const SizedBox(width: 4),
                  Text('${crew.memberCount}명 활동중'),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
