import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event_model.dart';
import 'event_invite_model.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Simple cache for frequently accessed events (5 minute TTL)
  static final Map<String, _CacheEntry> _eventCache = {};
  static final Map<String, _CacheEntry> _friendCountCache = {};

  String get _currentUserId => _auth.currentUser?.uid ?? '';

  // Collection references
  CollectionReference get _eventsCollection => _firestore.collection('events');

  // ============ CREATE ============

  Future<String> createEvent(Event event) async {
    final docRef = await _eventsCollection.add(event.toMap());
    return docRef.id;
  }

  // ============ READ ============

  Stream<List<Event>> getPublicEvents({
    String? city,
    String? category,
    String? subcategory,
    DateTime? startAfter,
  }) {
    // Simple query - only filter by visibility to avoid needing composite index
    // Additional filtering and sorting done in memory
    Query query = _eventsCollection.where('visibility', isEqualTo: 'public');

    return query.snapshots().map((snapshot) {
      List<Event> events = snapshot.docs
          .map((doc) => Event.fromFirestore(doc))
          .where((event) => event.status == 'active')
          .toList();

      // Filter by city if specified
      if (city != null && city.isNotEmpty) {
        events = events.where((e) => e.city == city).toList();
      }

      // Filter by category if specified
      if (category != null && category.isNotEmpty) {
        events = events.where((e) => e.category == category).toList();
      }

      // Filter by subcategory if specified
      if (subcategory != null && subcategory.isNotEmpty) {
        events = events.where((e) => e.subcategory == subcategory).toList();
      }

      // Filter by start date if specified
      if (startAfter != null) {
        events = events.where((e) => e.startDateTime.isAfter(startAfter)).toList();
      }

      // Sort by start date
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

    // Sort by start date
    events.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

    // Apply limit
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

  // User's events (organized)
  Stream<List<Event>> getMyOrganizedEvents() {
    return _eventsCollection
        .where('organizerId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
      // Sort in memory instead of Firestore to avoid composite index
      events.sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
      return events;
    });
  }

  // User's events (participating)
  Stream<List<Event>> getMyParticipatingEvents() {
    return _eventsCollection
        .where('participants', arrayContains: _currentUserId)
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs
          .map((doc) => Event.fromFirestore(doc))
          .where((e) => e.status == 'active')
          .toList();
      // Sort in memory
      events.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
      return events;
    });
  }

  // ============ UPDATE ============

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

  // ============ DELETE ============

  Future<void> deleteEvent(String eventId) async {
    // First delete all invites
    final invitesSnapshot =
        await _eventsCollection.doc(eventId).collection('invites').get();
    for (final doc in invitesSnapshot.docs) {
      await doc.reference.delete();
    }
    // Then delete the event
    await _eventsCollection.doc(eventId).delete();
  }

  // ============ INVITES ============

  Future<void> sendInvite(String eventId, String inviteeId,
      String inviteeName) async {
    final eventDoc = _eventsCollection.doc(eventId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(eventDoc);
      if (!snapshot.exists) {
        throw Exception('Event ne postoji');
      }

      final event = Event.fromFirestore(snapshot);

      // Validation: Cannot invite the event organizer
      if (inviteeId == event.organizerId) {
        throw Exception('Ne možeš pozvati organizatora događaja');
      }

      // Validation: Cannot invite someone already participating
      if (event.participants.contains(inviteeId)) {
        throw Exception('Taj korisnik je već prijavljen na događaj');
      }

      // Get the invites subcollection to check for existing invites
      final invitesSnapshot = await eventDoc
          .collection('invites')
          .where('inviteeId', isEqualTo: inviteeId)
          .where('status', isEqualTo: 'pending')
          .get();

      // Validation: Cannot invite the same person twice (duplicate pending invite)
      if (invitesSnapshot.docs.isNotEmpty) {
        throw Exception('Već je poslata pozivnica ovom korisniku');
      }

      final invite = EventInvite(
        eventId: eventId,
        inviteeId: inviteeId,
        inviteeName: inviteeName,
        inviterId: _currentUserId,
      );

      // Add the invite within the transaction
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
          // If collectionGroup fails, return empty and log
          return Stream<QuerySnapshot>.error(error);
        })
        .map((snapshot) {
          return snapshot.docs.map((doc) => EventInvite.fromFirestore(doc)).toList();
        });
  }

  // Fallback method to query invites by iterating events (slower but works without indexes)
  Future<List<EventInvite>> getMyPendingInvitesFallback() async {
    try {
      final invites = <EventInvite>[];
      
      // Get all events
      final eventsSnapshot = await _eventsCollection.get();
      
      for (final eventDoc in eventsSnapshot.docs) {
        // Get invites for this event
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

  // ============ HELPERS ============

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

  /// Get count of user's friends participating in an event
  /// Returns 0 if query fails (graceful degradation)
  /// Uses caching to avoid repeated queries
  Future<int> getMyFriendsParticipatingCount(String eventId) async {
    // Check cache first
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

      // Get user's friends
      final friendshipsSnapshot = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: _currentUserId)
          .limit(500) // Reasonable limit
          .get();

      final friendIds = friendshipsSnapshot.docs
          .map((doc) => doc.data()['friendId'] as String)
          .toList();

      if (friendIds.isEmpty) {
        _friendCountCache[cacheKey] = _CacheEntry(0);
        return 0;
      }

      // Count how many friends are in the event's participants
      int count = 0;
      for (final friendId in friendIds) {
        if (event.participants.contains(friendId)) {
          count++;
        }
      }
      
      // Cache the result
      _friendCountCache[cacheKey] = _CacheEntry(count);
      return count;
    } catch (e) {
      print('Error getting friends participating count: $e');
      return 0; // Graceful degradation
    }
  }

  /// Stream version for real-time updates
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

  /// Clear cache for a specific event
  static void clearFriendCountCache(String userId, String eventId) {
    _friendCountCache.remove('${userId}_$eventId');
  }

  /// Clear all caches
  static void clearAllCaches() {
    _eventCache.clear();
    _friendCountCache.clear();
  }
}

/// Simple cache entry with timestamp
class _CacheEntry {
  final dynamic value;
  final DateTime timestamp;
  static const Duration ttl = Duration(minutes: 5);

  _CacheEntry(this.value) : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}
