import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Obavesti'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
          // Mark all as read button
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Označi sve kao pročitano',
            onPressed: () {
              _notificationService.markAllNotificationsAsRead();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sve obavesti označene kao pročitane')),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _notificationService.getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Greška: ${snapshot.error}'),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nema obavesti',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(
                notification: notification,
                onDismiss: () {
                  _notificationService.deleteNotification(notification.id);
                },
                onRead: () {
                  if (!notification.isRead) {
                    _notificationService.markNotificationAsRead(notification.id);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;
  final VoidCallback onRead;

  const _NotificationTile({
    required this.notification,
    required this.onDismiss,
    required this.onRead,
  });

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

  String _getTypeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return 'Poruka';
      case NotificationType.eventReminder:
        return 'Podsetnik dogadjaja';
      case NotificationType.friendRequest:
        return 'Zahtev za prijateljstvo';
      case NotificationType.posterRecommendation:
        return 'Preporuka oglasa';
      case NotificationType.posterShare:
        return 'Deljenje oglasa';
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Upravo sada';
    } else if (difference.inMinutes < 60) {
      return 'Pre ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Pre ${difference.inHours} h';
    } else if (difference.inDays < 7) {
      return 'Pre ${difference.inDays} d';
    } else {
      return '${dateTime.day}.${dateTime.month}.${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRead,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: notification.isRead
            ? Colors.grey[50]
            : _getColorForType(notification.type).withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Notification type icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getColorForType(notification.type),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconForType(notification.type),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Notification content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(notification.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getColorForType(notification.type)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getTypeLabel(notification.type),
                            style: TextStyle(
                              fontSize: 11,
                              color: _getColorForType(notification.type),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (!notification.isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getColorForType(notification.type),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Delete button
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    onTap: onDismiss,
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text('Obriši'),
                      ],
                    ),
                  ),
                ],
                child: const Icon(Icons.more_vert, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
