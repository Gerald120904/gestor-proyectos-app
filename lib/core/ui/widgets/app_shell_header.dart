import 'dart:async';

import 'package:flutter/material.dart';

import '../../../ui/common.dart';

class AppShellHeader extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  final String userName;
  final String userEmail;
  final String breadcrumb;
  final String searchHint;
  final int notificationCount;
  final double headerHeight;

  final VoidCallback? onRefresh;
  final VoidCallback? onNotifications;
  final ValueChanged<String>? onSearchChanged;

  const AppShellHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.userName,
    required this.userEmail,
    required this.breadcrumb,
    this.searchHint = 'Buscar...',
    this.notificationCount = 0,
    this.headerHeight = 86,
    this.onRefresh,
    this.onNotifications,
    this.onSearchChanged,
  });

  @override
  Size get preferredSize => Size.fromHeight(headerHeight);

  @override
  State<AppShellHeader> createState() => _AppShellHeaderState();
}

class _AppShellHeaderState extends State<AppShellHeader> {
  late DateTime now;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    now = DateTime.now();

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  String two(int value) => value.toString().padLeft(2, '0');

  String get timeText {
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  String get dateText {
    return '${two(now.day)}/${two(now.month)}/${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 700;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.accent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withAlpha(35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 14 : 24,
            vertical: isSmall ? 10 : 12,
          ),
          child: Row(
            children: [
              Container(
                width: isSmall ? 42 : 48,
                height: isSmall ? 42 : 48,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(32),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withAlpha(45),
                  ),
                ),
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: isSmall ? 23 : 26,
                ),
              ),

              SizedBox(width: isSmall ? 12 : 16),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isSmall ? 21 : 25,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isSmall ? 11.5 : 13,
                        color: Colors.white.withAlpha(225),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: isSmall ? 8 : 16),

              _HeaderDateTimeBox(
                time: timeText,
                date: dateText,
                compact: isSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderDateTimeBox extends StatelessWidget {
  final String time;
  final String date;
  final bool compact;

  const _HeaderDateTimeBox({
    required this.time,
    required this.date,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 112 : 170,
      height: compact ? 42 : 46,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withAlpha(42),
        ),
      ),
      child: Row(
        children: [
          if (!compact) ...[
            const Icon(
              Icons.schedule_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment:
                  compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 12.5 : 14,
                  ),
                ),
                Text(
                  date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withAlpha(210),
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 10 : 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


