import '../models/event_model.dart';
import 'skill_levels.dart';

class EventRankingService {
  // Main ranking function - returns score 0-100
  double calculateEventScore({
    required Event event,
    required List<String> userHobbies,
    required Map<String, String> userSkills,
    required String? userCity,
  }) {
    final timeScore = _calculateTimeScore(event);
    final hobbyScore = _calculateHobbyScore(event, userHobbies);
    final skillScore = _calculateSkillScore(event, userHobbies, userSkills);
    final locationScore = _calculateLocationScore(event, userCity);

    return (timeScore + hobbyScore + skillScore + locationScore).clamp(0, 100);
  }

  // Time urgency score (0-30 points)
  // Events happening sooner get higher scores
  double _calculateTimeScore(Event event) {
    final now = DateTime.now();
    final hoursUntilEvent = event.startDateTime.difference(now).inHours;

    if (hoursUntilEvent < 0) return 0; // Past events
    if (hoursUntilEvent <= 24) return 30; // Within 24 hours - maximum urgency
    if (hoursUntilEvent <= 72) return 25; // Within 3 days
    if (hoursUntilEvent <= 168) return 20; // Within 1 week
    if (hoursUntilEvent <= 336) return 15; // Within 2 weeks
    if (hoursUntilEvent <= 720) return 10; // Within 1 month
    return 5; // More than 1 month away
  }

  // Hobby/category match score (0-35 points)
  double _calculateHobbyScore(Event event, List<String> userHobbies) {
    final eventHobby = event.hobby; // "Category > Subcategory"
    final eventCategory = event.category;

    // Tier 1: Exact match (full hobby string)
    if (userHobbies.contains(eventHobby)) {
      return 35; // 100% match equivalent
    }

    // Tier 2: Same subcategory in different category (rare but possible)
    for (final hobby in userHobbies) {
      if (hobby.endsWith('> ${event.subcategory}')) {
        return 25; // 70% match equivalent
      }
    }

    // Tier 3: Same category, different subcategory
    for (final hobby in userHobbies) {
      if (hobby.startsWith('$eventCategory >')) {
        return 17; // 50% match equivalent
      }
    }

    return 0; // No match
  }

  // Skill level compatibility score (0-20 points)
  double _calculateSkillScore(
    Event event,
    List<String> userHobbies,
    Map<String, String> userSkills,
  ) {
    final requiredLevel = event.requiredSkillLevel;

    // "any" means no requirement - full points
    if (requiredLevel == 'any') return 20;

    // Check if user has this hobby
    if (!userHobbies.contains(event.hobby)) {
      // User doesn't have this hobby at all
      // Check category match
      bool hasCategory = userHobbies.any((h) => h.startsWith('${event.category} >'));
      if (!hasCategory) return 0;
      // Has category but not exact hobby - assume beginner
      return _getSkillMatchScore('beginner', requiredLevel);
    }

    // Get user's skill level for this hobby
    final userLevel = userSkills[event.hobby] ?? 'beginner';
    return _getSkillMatchScore(userLevel, requiredLevel);
  }

  double _getSkillMatchScore(String userLevel, String requiredLevel) {
    final userLevelNum = skillLevelValues[userLevel] ?? 1;
    final requiredLevelNum = skillLevelValues[requiredLevel] ?? 1;

    // Exact match or user exceeds requirement
    if (userLevelNum >= requiredLevelNum) {
      return 20;
    }

    // User is one level below
    if (userLevelNum == requiredLevelNum - 1) {
      return 10; // Partial match - might still be able to participate
    }

    // User is two levels below
    return 0;
  }

  // Location proximity score (0-15 points)
  double _calculateLocationScore(Event event, String? userCity) {
    if (userCity == null || userCity.isEmpty) {
      return 7; // Neutral score if no city set
    }

    if (event.city == userCity) {
      return 15; // Same city - maximum score
    }

    // Future enhancement: calculate distance between cities
    // For now, return 0 for different cities
    return 0;
  }

  // Rank a list of events for a user
  List<RankedEvent> rankEvents({
    required List<Event> events,
    required List<String> userHobbies,
    required Map<String, String> userSkills,
    required String? userCity,
  }) {
    final rankedEvents = events.map((event) {
      final score = calculateEventScore(
        event: event,
        userHobbies: userHobbies,
        userSkills: userSkills,
        userCity: userCity,
      );
      return RankedEvent(event: event, score: score);
    }).toList();

    // Sort by score descending
    rankedEvents.sort((a, b) => b.score.compareTo(a.score));

    return rankedEvents;
  }

  // Get display text for score
  String getScoreLabel(double score) {
    if (score >= 80) return 'Odlicno poklapanje';
    if (score >= 60) return 'Dobro poklapanje';
    if (score >= 40) return 'Delimicno poklapanje';
    return 'Slabo poklapanje';
  }
}

class RankedEvent {
  final Event event;
  final double score;

  RankedEvent({
    required this.event,
    required this.score,
  });

  int get scorePercent => score.round();
}
