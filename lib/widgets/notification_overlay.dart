import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationOverlay extends StatefulWidget {
  final Widget child;

  const NotificationOverlay({super.key, required this.child});

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay> {
  final NotificationService _notificationService = NotificationService();
  OverlayEntry? _overlayEntry;
  bool _isShowing = false;

  @override
  void initState() {
    super.initState();
    // Set up notification callback
    NotificationService.onNotificationReceived = _showNotificationOverlay;
  }

  @override
  void dispose() {
    NotificationService.onNotificationReceived = null;
    _overlayEntry?.remove();
    super.dispose();
  }

  void _showNotificationOverlay(AppNotification notification) {
    if (_isShowing) return;

    setState(() => _isShowing = true);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: _NotificationBanner(
          notification: notification,
          onDismiss: _dismissNotification,
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), _dismissNotification);
  }

  void _dismissNotification() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isShowing = false);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _NotificationBanner extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;

  const _NotificationBanner({
    required this.notification,
    required this.onDismiss,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return Colors.blue;
      case NotificationType.eventReminder:
        return Colors.orange;
      case NotificationType.friendRequest:
        return Colors.purple;
      case NotificationType.posterRecommendation:
        return Colors.green;
      case NotificationType.posterShare:
        return Colors.indigo;
    }
  }

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return Icons.message;
      case NotificationType.eventReminder:
        return Icons.event;
      case NotificationType.friendRequest:
        return Icons.person_add;
      case NotificationType.posterRecommendation:
        return Icons.star;
      case NotificationType.posterShare:
        return Icons.share;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Material(
        child: Container(
          decoration: BoxDecoration(
            color: _getColorForType(widget.notification.type),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconForType(widget.notification.type),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.notification.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.notification.body,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onDismiss,
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
