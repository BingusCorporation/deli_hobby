import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum NotificationType {
  message,
  eventReminder,
  friendRequest,
  posterRecommendation,
  posterShare,
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String? relatedId; // Event ID, User ID, Poster ID, etc.
  final DateTime createdAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.relatedId,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'type': type.name,
      'relatedId': relatedId,
      'createdAt': createdAt,
      'isRead': isRead,
    };
  }

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.message,
      ),
      relatedId: data['relatedId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static void Function(AppNotification)? onNotificationReceived;

  NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  Future<void> initialize() async {
    try {
      NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted notification permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        print('User granted provisional notification permission');
      } else {
        print('User declined or has not yet granted notification permission');
      }

      await updateFCMToken();

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Foreground message received: ${message.notification?.title}');
        _handleForegroundMessage(message);
      });

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('App opened from notification: ${message.data}');
        _handleNotificationTap(message);
      });
    } catch (e) {
      print('Error initializing FCM: $e');
    }
  }

  Future<void> updateFCMToken() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final fcmToken = await _firebaseMessaging.getToken();
      if (fcmToken != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': fcmToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('FCM token updated: $fcmToken');
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      final appNotification = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: notification.title ?? 'Obavest',
        body: notification.body ?? '',
        type: _parseNotificationType(message.data['type']),
        relatedId: message.data['relatedId'],
        createdAt: DateTime.now(),
      );

      onNotificationReceived?.call(appNotification);

      _saveNotificationToFirestore(appNotification);
    }
  }

  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    print('Handling background message: ${message.data}');
  }

  void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'];
    final relatedId = message.data['relatedId'];

    switch (type) {
      case 'message':

        break;
      case 'eventReminder':

        break;
      case 'posterShare':

        break;
      case 'friendRequest':

        break;
      default:
        break;
    }
  }

  Future<void> _saveNotificationToFirestore(AppNotification notification) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add(notification.toFirestore());
    } catch (e) {
      print('Error saving notification: $e');
    }
  }

  Future<void> createNotification({
    required String title,
    required String body,
    required NotificationType type,
    String? relatedId,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final notification = AppNotification(
        id: '', 
        title: title,
        body: body,
        type: type,
        relatedId: relatedId,
        createdAt: DateTime.now(),
      );

      await _saveNotificationToFirestore(notification);
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  Stream<List<AppNotification>> getNotificationsStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => AppNotification.fromFirestore(doc)).toList();
    });
  }


  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final notifications = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }


  Future<void> deleteNotification(String notificationId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }


  Future<int> getUnreadCount() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return 0;

      final result = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .count()
          .get();

      return result.count ?? 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  NotificationType _parseNotificationType(String? type) {
    switch (type) {
      case 'message':
        return NotificationType.message;
      case 'eventReminder':
        return NotificationType.eventReminder;
      case 'friendRequest':
        return NotificationType.friendRequest;
      case 'posterRecommendation':
        return NotificationType.posterRecommendation;
      case 'posterShare':
        return NotificationType.posterShare;
      default:
        return NotificationType.message;
    }
  }
}
