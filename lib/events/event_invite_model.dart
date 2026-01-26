import 'package:cloud_firestore/cloud_firestore.dart';

class EventInvite {
  final String? id;
  final String eventId;
  final String inviteeId;
  final String inviteeName;
  final String inviterId;
  final String status; // pending, accepted, declined
  final DateTime? createdAt;
  final DateTime? respondedAt;

  EventInvite({
    this.id,
    required this.eventId,
    required this.inviteeId,
    required this.inviteeName,
    required this.inviterId,
    this.status = 'pending',
    this.createdAt,
    this.respondedAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'inviteeId': inviteeId,
      'inviteeName': inviteeName,
      'inviterId': inviterId,
      'status': status,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'respondedAt': respondedAt != null
          ? Timestamp.fromDate(respondedAt!)
          : null,
    };
  }

  factory EventInvite.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventInvite.fromMap(data, doc.id);
  }

  factory EventInvite.fromMap(Map<String, dynamic> map, [String? docId]) {
    return EventInvite(
      id: docId ?? map['id'],
      eventId: map['eventId'] ?? '',
      inviteeId: map['inviteeId'] ?? '',
      inviteeName: map['inviteeName'] ?? '',
      inviterId: map['inviterId'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      respondedAt: map['respondedAt'] != null
          ? (map['respondedAt'] as Timestamp).toDate()
          : null,
    );
  }

  EventInvite copyWith({
    String? id,
    String? eventId,
    String? inviteeId,
    String? inviteeName,
    String? inviterId,
    String? status,
    DateTime? createdAt,
    DateTime? respondedAt,
  }) {
    return EventInvite(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      inviteeId: inviteeId ?? this.inviteeId,
      inviteeName: inviteeName ?? this.inviteeName,
      inviterId: inviterId ?? this.inviterId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }
}
