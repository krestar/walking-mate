import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF3ED2B3);
    const inactiveColor = Colors.grey;

    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      surfaceTintColor: Colors.white,
      elevation: 8.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _buildNavItem('ic_home', '홈', 0, activeColor, inactiveColor),
          _buildNavItem('ic_achievements', '업적', 1, activeColor, inactiveColor),
          _buildCenterNavItem(activeColor, inactiveColor),
          _buildNavItem('ic_community', '커뮤니티', 3, activeColor, inactiveColor),
          _buildNavItem('ic_account', '계정', 4, activeColor, inactiveColor),
        ],
      ),
    );
  }

  Widget _buildCenterNavItem(Color activeColor, Color inactiveColor) {
    final bool isSelected = selectedIndex == 2;

    return InkWell(
      onTap: () => onItemTapped(2),
      customBorder: const CircleBorder(),
      child: Transform.translate(
        offset: const Offset(0, -20),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? activeColor : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(38),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/ic_walking.svg',
                width: 28,
                height: 28,
                colorFilter: ColorFilter.mode(
                  isSelected ? Colors.white : inactiveColor,
                  BlendMode.srcIn,
                ),
              ),
              Text(
                '산책',
                style: TextStyle(
                  color: isSelected ? Colors.white : inactiveColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(String iconName, String label, int index,
      Color activeColor, Color inactiveColor) {
    final color = selectedIndex == index ? activeColor : inactiveColor;

    return InkWell(
      onTap: () => onItemTapped(index),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SvgPicture.asset(
              'assets/icons/$iconName.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

