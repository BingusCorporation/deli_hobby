import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event_model.dart';
import 'event_invite_model.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static final Map<String, _CacheEntry> _eventCache = {};
  static final Map<String, _CacheEntry> _friendCountCache = {};

  String get _currentUserId => _auth.currentUser?.uid ?? '';

  CollectionReference get _eventsCollection => _firestore.collection('events');

  Future<String> createEvent(Event event) async {
    final docRef = await _eventsCollection.add(event.toMap());
    return docRef.id;
  }

  Stream<List<Event>> getPublicEvents({
    String? city,
    String? category,
    String? subcategory,
    DateTime? startAfter,
  }) {

    Query query = _eventsCollection.where('visibility', isEqualTo: 'public');

    return query.snapshots().map((snapshot) {
      List<Event> events = snapshot.docs
          .map((doc) => Event.fromFirestore(doc))
          .where((event) => event.status == 'active')
          .toList();


      if (city != null && city.isNotEmpty) {
        events = events.where((e) => e.city == city).toList();
      }


      if (category != null && category.isNotEmpty) {
        events = events.where((e) => e.category == category).toList();
      }

      if (subcategory != null && subcategory.isNotEmpty) {
        events = events.where((e) => e.subcategory == subcategory).toList();
      }

      if (startAfter != null) {
        events = events.where((e) => e.startDateTime.isAfter(startAfter)).toList();
      }

      events.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

      return events;
    });
  }

  Future<List<Event>> getUpcomingPublicEvents({int limit = 20}) async {
    final now = DateTime.now();
    final snapshot = await _eventsCollection
        .where('visibility', isEqualTo: 'public')
        .get();

    List<Event> events = snapshot.docs
        .map((doc) => Event.fromFirestore(doc))
        .where((e) => e.status == 'active' && e.startDateTime.isAfter(now))
        .toList();

    events.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

    if (events.length > limit) {
      events = events.take(limit).toList();
    }

    return events;
  }

  Stream<Event?> getEventStream(String eventId) {
    return _eventsCollection.doc(eventId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Event.fromFirestore(doc);
    });
  }

  Future<Event?> getEvent(String eventId) async {
    final doc = await _eventsCollection.doc(eventId).get();
    if (!doc.exists) return null;
    return Event.fromFirestore(doc);
  }

  Stream<List<Event>> getMyOrganizedEvents() {
    return _eventsCollection
        .where('organizerId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
      events.sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
      return events;
    });
  }

  Stream<List<Event>> getMyParticipatingEvents() {
    return _eventsCollection
        .where('participants', arrayContains: _currentUserId)
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs
          .map((doc) => Event.fromFirestore(doc))
          .where((e) => e.status == 'active')
          .toList();
      events.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
      return events;
    });
  }


  Future<void> updateEvent(String eventId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _eventsCollection.doc(eventId).update(updates);
  }

  Future<void> joinEvent(String eventId) async {
    final eventDoc = _eventsCollection.doc(eventId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(eventDoc);
      if (!snapshot.exists) {
        throw Exception('Event ne postoji');
      }

      final event = Event.fromFirestore(snapshot);

      if (event.isFull) {
        throw Exception('Event je popunjen');
      }

      if (event.participants.contains(_currentUserId)) {
        throw Exception('Vec si prijavljen na ovaj event');
      }

      transaction.update(eventDoc, {
        'participants': FieldValue.arrayUnion([_currentUserId]),
        'currentParticipants': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> leaveEvent(String eventId) async {
    final eventDoc = _eventsCollection.doc(eventId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(eventDoc);
      if (!snapshot.exists) {
        throw Exception('Event ne postoji');
      }

      final event = Event.fromFirestore(snapshot);

      if (!event.participants.contains(_currentUserId)) {
        throw Exception('Nisi prijavljen na ovaj event');
      }

      transaction.update(eventDoc, {
        'participants': FieldValue.arrayRemove([_currentUserId]),
        'currentParticipants': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> cancelEvent(String eventId) async {
    await updateEvent(eventId, {'status': 'cancelled'});
  }


  Future<void> deleteEvent(String eventId) async {
    final invitesSnapshot =
        await _eventsCollection.doc(eventId).collection('invites').get();
    for (final doc in invitesSnapshot.docs) {
      await doc.reference.delete();
    }
    await _eventsCollection.doc(eventId).delete();
  }


  Future<void> sendInvite(String eventId, String inviteeId,
      String inviteeName) async {
    final eventDoc = _eventsCollection.doc(eventId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(eventDoc);
      if (!snapshot.exists) {
        throw Exception('Event ne postoji');
      }

      final event = Event.fromFirestore(snapshot);

      if (inviteeId == event.organizerId) {
        throw Exception('Ne možeš pozvati organizatora događaja');
      }

      if (event.participants.contains(inviteeId)) {
        throw Exception('Taj korisnik je već prijavljen na događaj');
      }

      final invitesSnapshot = await eventDoc
          .collection('invites')
          .where('inviteeId', isEqualTo: inviteeId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (invitesSnapshot.docs.isNotEmpty) {
        throw Exception('Već je poslata pozivnica ovom korisniku');
      }

      final invite = EventInvite(
        eventId: eventId,
        inviteeId: inviteeId,
        inviteeName: inviteeName,
        inviterId: _currentUserId,
      );

      transaction.set(
        eventDoc.collection('invites').doc(),
        invite.toMap(),
      );
    });
  }

  Future<void> respondToInvite(
      String eventId, String inviteId, bool accept) async {
    await _eventsCollection.doc(eventId).collection('invites').doc(inviteId).update({
      'status': accept ? 'accepted' : 'declined',
      'respondedAt': FieldValue.serverTimestamp(),
    });

    if (accept) {
      await joinEvent(eventId);
    }
  }

  Stream<List<EventInvite>> getEventInvites(String eventId) {
    return _eventsCollection
        .doc(eventId)
        .collection('invites')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => EventInvite.fromFirestore(doc)).toList();
    });
  }

  Stream<List<EventInvite>> getMyPendingInvites() {
    return _firestore
        .collectionGroup('invites')
        .where('inviteeId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .handleError((error) {
          print('CollectionGroup query error: $error');
          return Stream<QuerySnapshot>.error(error);
        })
        .map((snapshot) {
          return snapshot.docs.map((doc) => EventInvite.fromFirestore(doc)).toList();
        });
  }

  Stream<int> getMyPendingInvitesCountStream() {
    return _firestore
        .collectionGroup('invites')
        .where('inviteeId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .handleError((error) {
          print('CollectionGroup query error: $error');
          return Stream<QuerySnapshot>.error(error);
        })
        .map((snapshot) => snapshot.docs.length);
  }

  Future<List<EventInvite>> getMyPendingInvitesFallback() async {
    try {
      final invites = <EventInvite>[];
      
      final eventsSnapshot = await _eventsCollection.get();
      
      for (final eventDoc in eventsSnapshot.docs) {
        final invitesSnapshot = await eventDoc.reference
            .collection('invites')
            .where('inviteeId', isEqualTo: _currentUserId)
            .where('status', isEqualTo: 'pending')
            .get();
        
        for (final inviteDoc in invitesSnapshot.docs) {
          invites.add(EventInvite.fromFirestore(inviteDoc));
        }
      }
      
      return invites;
    } catch (e) {
      print('Fallback invite query error: $e');
      return [];
    }
  }


  bool isOrganizer(Event event) {
    return event.organizerId == _currentUserId;
  }

  bool isParticipant(Event event) {
    return event.participants.contains(_currentUserId);
  }

  bool canJoin(Event event) {
    return !event.isFull &&
        !isParticipant(event) &&
        !isOrganizer(event) &&
        event.status == 'active';
  }


  Future<int> getMyFriendsParticipatingCount(String eventId) async {
    final cacheKey = '${_currentUserId}_$eventId';
    if (_friendCountCache.containsKey(cacheKey)) {
      final cached = _friendCountCache[cacheKey]!;
      if (!cached.isExpired) {
        return cached.value;
      }
    }

    try {
      final event = await getEvent(eventId);
      if (event == null || event.participants.isEmpty) {
        _friendCountCache[cacheKey] = _CacheEntry(0);
        return 0;
      }

      final friendshipsSnapshot = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: _currentUserId)
          .limit(500)
          .get();

      final friendIds = friendshipsSnapshot.docs
          .map((doc) => doc.data()['friendId'] as String)
          .toList();

      if (friendIds.isEmpty) {
        _friendCountCache[cacheKey] = _CacheEntry(0);
        return 0;
      }

      int count = 0;
      for (final friendId in friendIds) {
        if (event.participants.contains(friendId)) {
          count++;
        }
      }
      
      _friendCountCache[cacheKey] = _CacheEntry(count);
      return count;
    } catch (e) {
      print('Error getting friends participating count: $e');
      return 0; 
    }
  }

  Stream<int> getMyFriendsParticipatingCountStream(String eventId) {
    return _eventsCollection.doc(eventId).snapshots().asyncMap((eventDoc) async {
      if (!eventDoc.exists) return 0;
      
      final event = Event.fromFirestore(eventDoc);
      if (event.participants.isEmpty) return 0;

      try {
        final friendshipsSnapshot = await _firestore
            .collection('friendships')
            .where('userId', isEqualTo: _currentUserId)
            .limit(500)
            .get();

        final friendIds = friendshipsSnapshot.docs
            .map((doc) => doc.data()['friendId'] as String)
            .toList();

        int count = 0;
        for (final friendId in friendIds) {
          if (event.participants.contains(friendId)) {
            count++;
          }
        }
        return count;
      } catch (e) {
        print('Error in friend count stream: $e');
        return 0;
      }
    });
  }

  static void clearFriendCountCache(String userId, String eventId) {
    _friendCountCache.remove('${userId}_$eventId');
  }

  static void clearAllCaches() {
    _eventCache.clear();
    _friendCountCache.clear();
  }
}

class _CacheEntry {
  final dynamic value;
  final DateTime timestamp;
  static const Duration ttl = Duration(minutes: 5);

  _CacheEntry(this.value) : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}
