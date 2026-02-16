// UYC - Unlock Your Cloud
// Reusable Navigation Drawer

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../screens/sessions_screen.dart';
import '../screens/endpoint_list_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/help_screen.dart';
import '../screens/about_screen.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF155268), // Darker blue-green
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMenuItems(context)),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0x1AFFFFFF), // 10% white
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UYC',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Universal Chat',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _MenuItem(
          icon: Icons.home,
          label: 'Home',
          route: 'home',
          currentRoute: currentRoute,
          onTap: () => _navigateTo(context, const SessionsScreen()),
        ),
        _MenuItem(
          icon: Icons.chat_bubble_outline,
          label: 'Sessions',
          route: 'sessions',
          currentRoute: currentRoute,
          onTap: () => _navigateTo(context, const SessionsScreen()),
        ),
        _MenuItem(
          icon: Icons.settings_input_antenna,
          label: 'Endpoints',
          route: 'endpoints',
          currentRoute: currentRoute,
          onTap: () => _navigateTo(context, const EndpointListScreen()),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: Divider(
            color: Color(0x1AFFFFFF),
            height: 1,
          ),
        ),
        _MenuItem(
          icon: Icons.settings,
          label: 'Settings',
          route: 'settings',
          currentRoute: currentRoute,
          onTap: () => _navigateTo(context, const SettingsScreen()),
        ),
        _MenuItem(
          icon: Icons.help_outline,
          label: 'Help & Support',
          route: 'help',
          currentRoute: currentRoute,
          onTap: () => _navigateTo(context, const HelpScreen()),
        ),
        _MenuItem(
          icon: Icons.info_outline,
          label: 'About',
          route: 'about',
          currentRoute: currentRoute,
          onTap: () => _navigateTo(context, const AboutScreen()),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Color(0x1AFFFFFF),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Text(
            'UYC v1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textLight.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            '© 2025 Unlock Your Cloud',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textLight.withValues(alpha: 0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context); // Close drawer
    // Use pushReplacement for main screens to prevent deep stack
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = route == currentRoute;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isActive ? AppColors.accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive
                  ? AppColors.accent
                  : AppColors.textLight.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 15),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? AppColors.accent
                    : AppColors.textLight.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
