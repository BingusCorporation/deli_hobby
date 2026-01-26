import '../models/event_model.dart';

class EventRankingService {
  // Memoization cache for event scores
  static final Map<String, double> _scoreCache = {};

  // Main ranking function - simplified, score 0-100
  double calculateEventScore({
    required Event event,
    required List<String> userHobbies,
    required String? userCity,
  }) {
    // Create cache key
    final cacheKey = '${event.id}_${userHobbies.join(',')}_$userCity';
    
    // Check cache first
    if (_scoreCache.containsKey(cacheKey)) {
      return _scoreCache[cacheKey]!;
    }

    final timeScore = _calculateTimeScore(event);
    final hobbyScore = _calculateHobbyScore(event, userHobbies);
    final locationScore = _calculateLocationScore(event, userCity);

    final totalScore = (timeScore + hobbyScore + locationScore).clamp(0, 100).toDouble();
    
    // Cache the score
    _scoreCache[cacheKey] = totalScore;
    
    return totalScore;
  }

  // Time urgency score (0-40 points)
  // Events happening sooner get higher scores
  double _calculateTimeScore(Event event) {
    final now = DateTime.now();
    final hoursUntilEvent = event.startDateTime.difference(now).inHours;

    if (hoursUntilEvent < 0) return 0; // Past events
    if (hoursUntilEvent <= 24) return 40; // Within 24 hours - maximum urgency
    if (hoursUntilEvent <= 72) return 35; // Within 3 days
    if (hoursUntilEvent <= 168) return 30; // Within 1 week
    if (hoursUntilEvent <= 336) return 20; // Within 2 weeks
    if (hoursUntilEvent <= 720) return 10; // Within 1 month
    return 5; // More than 1 month away
  }

  // Hobby/category match score (0-50 points)
  double _calculateHobbyScore(Event event, List<String> userHobbies) {
    final eventHobby = event.hobby; // "Category > Subcategory"
    final eventCategory = event.category;

    // Tier 1: Exact match (full hobby string)
    if (userHobbies.contains(eventHobby)) {
      return 50; // Perfect match
    }

    // Tier 2: Same category, different subcategory
    for (final hobby in userHobbies) {
      if (hobby.startsWith('$eventCategory >')) {
        return 30; // Category match
      }
    }

    return 0; // No match
  }

  // Location proximity score (0-10 points)
  double _calculateLocationScore(Event event, String? userCity) {
    if (userCity == null || userCity.isEmpty) {
      return 5; // Neutral score if no city set
    }

    if (event.city == userCity) {
      return 10; // Same city - bonus score
    }

    return 0; // Different city
  }

  // Rank a list of events for a user
  List<RankedEvent> rankEvents({
    required List<Event> events,
    required List<String> userHobbies,
    required String? userCity,
  }) {
    final rankedEvents = events.map((event) {
      final score = calculateEventScore(
        event: event,
        userHobbies: userHobbies,
        userCity: userCity,
      );
      return RankedEvent(event: event, score: score);
    }).toList();

    // Sort by score descending
    rankedEvents.sort((a, b) => b.score.compareTo(a.score));

    return rankedEvents;
  }

  // Enhanced ranking with friend-based prioritization
  List<RankedEvent> rankEventsWithFriends({
    required List<RankedEvent> rankedEvents,
    required Map<String, int> friendCountsByEventId,
  }) {
    // Create a new list and sort by:
    // 1. Has friends participating (friends > 0)
    // 2. Number of friends (descending)
    // 3. Original score (descending)
    final sorted = List<RankedEvent>.from(rankedEvents);
    
    sorted.sort((a, b) {
      final aFriendsCount = friendCountsByEventId[a.event.id] ?? 0;
      final bFriendsCount = friendCountsByEventId[b.event.id] ?? 0;
      
      // If both have friends or both don't, sort by friend count first
      if ((aFriendsCount > 0) != (bFriendsCount > 0)) {
        return (bFriendsCount > 0 ? 1 : 0).compareTo(aFriendsCount > 0 ? 1 : 0);
      }
      
      // If same friend status, sort by friend count (more friends first)
      if (aFriendsCount != bFriendsCount) {
        return bFriendsCount.compareTo(aFriendsCount);
      }
      
      // If same friend count, sort by score
      return b.score.compareTo(a.score);
    });
    
    return sorted.map((rankedEvent) {
      final friendCount = friendCountsByEventId[rankedEvent.event.id] ?? 0;
      return RankedEvent(
        event: rankedEvent.event,
        score: rankedEvent.score,
        friendsParticipating: friendCount,
      );
    }).toList();
  }

  // Get display text for score
  String getScoreLabel(double score) {
    if (score >= 80) return 'Odlicno poklapanje';
    if (score >= 60) return 'Dobro poklapanje';
    if (score >= 40) return 'Delimicno poklapanje';
    return 'Slabo poklapanje';
  }

  // Clear score cache
  static void clearScoreCache() {
    _scoreCache.clear();
  }
}

class RankedEvent {
  final Event event;
  final double score;
  final int friendsParticipating;

  RankedEvent({
    required this.event,
    required this.score,
    this.friendsParticipating = 0,
  });

  int get scorePercent => score.round();
}
