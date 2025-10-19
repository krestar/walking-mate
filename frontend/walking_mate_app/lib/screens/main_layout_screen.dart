import 'package:flutter/material.dart';
import 'package:walking_mate_app/screens/achievement_screen.dart';
import 'package:walking_mate_app/screens/community_screen.dart';
import 'package:walking_mate_app/screens/home_screen.dart';
import 'package:walking_mate_app/screens/profile_screen.dart';
import 'package:walking_mate_app/screens/walk_prep_screen.dart';
import 'package:walking_mate_app/widgets/custom_bottom_nav_bar.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = <Widget>[
      const HomeScreen(),
      const AchievementScreen(),
      const WalkPrepScreen(),
      const CommunityScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: widgetOptions,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}

