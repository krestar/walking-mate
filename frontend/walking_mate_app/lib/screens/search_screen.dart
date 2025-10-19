import 'package:flutter/material.dart';
import 'package:walking_mate_app/models/community_model.dart';
import 'package:walking_mate_app/services/auth_service.dart';
import 'package:walking_mate_app/services/community_service.dart';
import 'package:walking_mate_app/services/friend_service.dart';

class SearchScreen extends StatefulWidget {
  final String? initialTab;

  const SearchScreen({super.key, this.initialTab});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final CommunityService _communityService = CommunityService();
  final FriendService _friendService = FriendService();
  final AuthService _authService = AuthService();

  List<CrewSearchResult> _crewResults = [];
  List<UserSearchResult> _userResults = [];
  bool _isLoading = true;
  bool _searchInMyArea = false;
  String? _currentUserLocation;

  @override
  void initState() {
    super.initState();
    int initialIndex = (widget.initialTab == 'user') ? 1 : 0;
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: initialIndex);
    _loadCurrentUserLocationAndSearch('');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserLocationAndSearch(String term) async {
    try {
      final userProfile = await _authService.getFullUserProfile();
      if (mounted) {
        setState(() {
          _currentUserLocation = userProfile['location'];
        });
      }
    } catch (e) {
      // Handle error if needed
    }
    _performSearch(term);
  }

  void _performSearch(String term) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final locationToSearch = _searchInMyArea ? _currentUserLocation : null;
      final results = await Future.wait([
        _communityService.searchCrews(term),
        _communityService.searchUsers(term, location: locationToSearch),
      ]);
      if (mounted) {
        setState(() {
          _crewResults = results[0] as List<CrewSearchResult>;
          _userResults = results[1] as List<UserSearchResult>;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('검색 실패: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color themeColor = Color(0xFF3ED2B3);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '크루 또는 워킹메이트 검색',
            border: InputBorder.none,
          ),
          onSubmitted: _performSearch,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _performSearch(_searchController.text),
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: themeColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: themeColor,
          tabs: const [
            Tab(text: '크루'),
            Tab(text: '워킹메이트'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildCrewResults(),
          _buildUserResults(),
        ],
      ),
    );
  }

  Widget _buildCrewResults() {
    if (_crewResults.isEmpty) {
      return const Center(child: Text('표시할 크루가 없습니다.'));
    }
    return ListView.builder(
      itemCount: _crewResults.length,
      itemBuilder: (context, index) {
        final crew = _crewResults[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.group)),
          title: Text(crew.crewName),
          subtitle: Text('멤버 ${crew.memberCount}명'),
          trailing: ElevatedButton(
            child: const Text('가입'),
            onPressed: () => _joinCrew(crew.crewId),
          ),
        );
      },
    );
  }

  Widget _buildUserResults() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: CheckboxListTile(
            title: const Text('내 지역에서만 검색'),
            value: _searchInMyArea,
            onChanged: (bool? value) {
              if (_currentUserLocation == null || _currentUserLocation!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('프로필에서 거주 지역을 먼저 설정해주세요.')),
                );
                return;
              }
              setState(() {
                _searchInMyArea = value ?? false;
              });
              _performSearch(_searchController.text);
            },
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: const Color(0xFF3ED2B3),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _userResults.isEmpty
              ? const Center(child: Text('검색 가능한 워킹메이트가 없습니다.'))
              : ListView.builder(
            itemCount: _userResults.length,
            itemBuilder: (context, index) {
              final user = _userResults[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(user.nickname),
                subtitle: Text(user.location ?? '지역 정보 없음'),
                trailing: ElevatedButton(
                  child: const Text('요청'),
                  onPressed: () => _sendFriendRequest(user.userId),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _joinCrew(int crewId) async {
    try {
      await _communityService.joinCrew(crewId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('크루에 가입했습니다!')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('가입 실패: $e')));
    }
  }

  void _sendFriendRequest(int userId) async {
    try {
      await _friendService.sendFriendRequest(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('워킹메이트 요청을 보냈습니다!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('요청 실패: $e')));
    }
  }
}