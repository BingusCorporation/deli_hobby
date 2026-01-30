import '../models/event_model.dart';

class EventRankingService {
  static final Map<String, double> _scoreCache = {};

  double calculateEventScore({
    required Event event,
    required List<String> userHobbies,
    required String? userCity,
  }) {
    final cacheKey = '${event.id}_${userHobbies.join(',')}_$userCity';
    
    if (_scoreCache.containsKey(cacheKey)) {
      return _scoreCache[cacheKey]!;
    }

    final timeScore = _calculateTimeScore(event);
    final hobbyScore = _calculateHobbyScore(event, userHobbies);
    final locationScore = _calculateLocationScore(event, userCity);

    final totalScore = (timeScore + hobbyScore + locationScore).clamp(0, 100).toDouble();
    
    _scoreCache[cacheKey] = totalScore;
    
    return totalScore;
  }

  double _calculateTimeScore(Event event) {
    final now = DateTime.now();
    final hoursUntilEvent = event.startDateTime.difference(now).inHours;

    if (hoursUntilEvent < 0) return 0; //
    if (hoursUntilEvent <= 24) return 40; // 
    if (hoursUntilEvent <= 72) return 35; // 
    if (hoursUntilEvent <= 168) return 30; // 
    if (hoursUntilEvent <= 336) return 20; // 
    if (hoursUntilEvent <= 720) return 10; // 
    return 5; // 
  }

  double _calculateHobbyScore(Event event, List<String> userHobbies) {
    final eventHobby = event.hobby; // 
    final eventCategory = event.category;

   
    if (userHobbies.contains(eventHobby)) {
      return 50; // 
    }
    for (final hobby in userHobbies) {
      if (hobby.startsWith('$eventCategory >')) {
        return 30; // 
      }
    }

    return 0; // 
  }

  double _calculateLocationScore(Event event, String? userCity) {
    if (userCity == null || userCity.isEmpty) {
      return 5;
    }

    if (event.city == userCity) {
      return 10;
    }

    return 0;
  }

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

    rankedEvents.sort((a, b) => b.score.compareTo(a.score));

    return rankedEvents;
  }

  List<RankedEvent> rankEventsWithFriends({
    required List<RankedEvent> rankedEvents,
    required Map<String, int> friendCountsByEventId,
  }) {
    final sorted = List<RankedEvent>.from(rankedEvents);
    
    sorted.sort((a, b) {
      final aFriendsCount = friendCountsByEventId[a.event.id] ?? 0;
      final bFriendsCount = friendCountsByEventId[b.event.id] ?? 0;
      
      if ((aFriendsCount > 0) != (bFriendsCount > 0)) {
        return (bFriendsCount > 0 ? 1 : 0).compareTo(aFriendsCount > 0 ? 1 : 0);
      }
      
      if (aFriendsCount != bFriendsCount) {
        return bFriendsCount.compareTo(aFriendsCount);
      }
      
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

  String getScoreLabel(double score) {
    if (score >= 80) return 'Odlicno poklapanje';
    if (score >= 60) return 'Dobro poklapanje';
    if (score >= 40) return 'Delimicno poklapanje';
    return 'Slabo poklapanje';
  }

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
