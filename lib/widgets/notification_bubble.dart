import 'package:flutter/material.dart';

/// Red notification bubble badge for displaying unread counts
class NotificationBubble extends StatelessWidget {
  final int count;
  final double size;
  final Color color;
  final TextStyle? textStyle;

  const NotificationBubble({
    super.key,
    required this.count,
    this.size = 20,
    this.color = Colors.red,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      constraints: BoxConstraints(
        minWidth: size,
        minHeight: size,
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: textStyle ??
              const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Red dot indicator for unread notifications
class NotificationDot extends StatelessWidget {
  final bool hasNotification;
  final double size;
  final Color color;

  const NotificationDot({
    super.key,
    required this.hasNotification,
    this.size = 8,
    this.color = Colors.red,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasNotification) return const SizedBox.shrink();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
