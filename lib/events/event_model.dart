import 'package:cloud_firestore/cloud_firestore.dart';
import 'recurrence_rule_model.dart';

class EventAccessibility {
  final bool wheelchairAccessible;
  final bool hearingAssistance;
  final bool visualAssistance;
  final String? notes;

  EventAccessibility({
    this.wheelchairAccessible = false,
    this.hearingAssistance = false,
    this.visualAssistance = false,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'wheelchairAccessible': wheelchairAccessible,
      'hearingAssistance': hearingAssistance,
      'visualAssistance': visualAssistance,
      'notes': notes,
    };
  }

  factory EventAccessibility.fromMap(Map<String, dynamic>? map) {
    if (map == null) return EventAccessibility();
    return EventAccessibility(
      wheelchairAccessible: map['wheelchairAccessible'] ?? false,
      hearingAssistance: map['hearingAssistance'] ?? false,
      visualAssistance: map['visualAssistance'] ?? false,
      notes: map['notes'],
    );
  }
}

class ScheduleItem {
  final String time;
  final String activity;

  ScheduleItem({
    required this.time,
    required this.activity,
  });

  Map<String, dynamic> toMap() {
    return {
      'time': time,
      'activity': activity,
    };
  }

  factory ScheduleItem.fromMap(Map<String, dynamic> map) {
    return ScheduleItem(
      time: map['time'] ?? '',
      activity: map['activity'] ?? '',
    );
  }
}

class Event {
  final String? id;
  final String title;
  final String description;
  final String organizerId;
  final String organizerName;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final int duration; // in minutes
  final bool isRecurring;
  final RecurrenceRule? recurrenceRule;
  final String city;
  final String address;
  final String? locationDetails;
  final int maxParticipants;
  final int currentParticipants;
  final List<String> participants;
  final String category; // Primary category (for backwards compatibility)
  final String subcategory; // Primary subcategory (for backwards compatibility)
  final String hobby; // Primary "Category > Subcategory" (for backwards compatibility)
  final List<String> categories; // All categories
  final List<String> subcategories; // All subcategories
  final List<String> hobbies; // All "Category > Subcategory" combinations
  final String requiredSkillLevel; // beginner, intermediate, advanced, any
  final String visibility; // public, private
  final EventAccessibility accessibility;
  final List<ScheduleItem> schedule;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String status; // active, cancelled, completed

  Event({
    this.id,
    required this.title,
    required this.description,
    required this.organizerId,
    required this.organizerName,
    required this.startDateTime,
    required this.endDateTime,
    required this.duration,
    this.isRecurring = false,
    this.recurrenceRule,
    required this.city,
    required this.address,
    this.locationDetails,
    required this.maxParticipants,
    this.currentParticipants = 0,
    this.participants = const [],
    required this.category,
    required this.subcategory,
    required this.hobby,
    this.categories = const [],
    this.subcategories = const [],
    this.hobbies = const [],
    this.requiredSkillLevel = 'any',
    this.visibility = 'public',
    EventAccessibility? accessibility,
    this.schedule = const [],
    this.createdAt,
    this.updatedAt,
    this.status = 'active',
  }) : accessibility = accessibility ?? EventAccessibility();

  bool get isFull => currentParticipants >= maxParticipants;
  bool get isPrivate => visibility == 'private';
  bool get isPublic => visibility == 'public';
  int get spotsLeft => maxParticipants - currentParticipants;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'startDateTime': Timestamp.fromDate(startDateTime),
      'endDateTime': Timestamp.fromDate(endDateTime),
      'duration': duration,
      'isRecurring': isRecurring,
      'recurrenceRule': recurrenceRule?.toMap(),
      'city': city,
      'address': address,
      'locationDetails': locationDetails,
      'maxParticipants': maxParticipants,
      'currentParticipants': currentParticipants,
      'participants': participants,
      'category': category,
      'subcategory': subcategory,
      'hobby': hobby,
      'categories': categories.isNotEmpty ? categories : [category],
      'subcategories': subcategories.isNotEmpty ? subcategories : [subcategory],
      'hobbies': hobbies.isNotEmpty ? hobbies : [hobby],
      'requiredSkillLevel': requiredSkillLevel,
      'visibility': visibility,
      'accessibility': accessibility.toMap(),
      'schedule': schedule.map((s) => s.toMap()).toList(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': status,
    };
  }

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Event.fromMap(data, doc.id);
  }

  factory Event.fromMap(Map<String, dynamic> map, [String? docId]) {
    return Event(
      id: docId ?? map['id'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      organizerId: map['organizerId'] ?? '',
      organizerName: map['organizerName'] ?? '',
      startDateTime: map['startDateTime'] != null
          ? (map['startDateTime'] as Timestamp).toDate()
          : DateTime.now(),
      endDateTime: map['endDateTime'] != null
          ? (map['endDateTime'] as Timestamp).toDate()
          : DateTime.now(),
      duration: map['duration'] ?? 60,
      isRecurring: map['isRecurring'] ?? false,
      recurrenceRule: map['recurrenceRule'] != null
          ? RecurrenceRule.fromMap(map['recurrenceRule'])
          : null,
      city: map['city'] ?? '',
      address: map['address'] ?? '',
      locationDetails: map['locationDetails'],
      maxParticipants: map['maxParticipants'] ?? 10,
      currentParticipants: map['currentParticipants'] ?? 0,
      participants: map['participants'] != null
          ? List<String>.from(map['participants'])
          : [],
      category: map['category'] ?? '',
      subcategory: map['subcategory'] ?? '',
      hobby: map['hobby'] ?? '',
      categories: map['categories'] != null
          ? List<String>.from(map['categories'])
          : [map['category'] ?? ''],
      subcategories: map['subcategories'] != null
          ? List<String>.from(map['subcategories'])
          : [map['subcategory'] ?? ''],
      hobbies: map['hobbies'] != null
          ? List<String>.from(map['hobbies'])
          : [map['hobby'] ?? ''],
      requiredSkillLevel: map['requiredSkillLevel'] ?? 'any',
      visibility: map['visibility'] ?? 'public',
      accessibility: EventAccessibility.fromMap(map['accessibility']),
      schedule: map['schedule'] != null
          ? (map['schedule'] as List)
              .map((s) => ScheduleItem.fromMap(s))
              .toList()
          : [],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      status: map['status'] ?? 'active',
    );
  }

  Event copyWith({
    String? id,
    String? title,
    String? description,
    String? organizerId,
    String? organizerName,
    DateTime? startDateTime,
    DateTime? endDateTime,
    int? duration,
    bool? isRecurring,
    RecurrenceRule? recurrenceRule,
    String? city,
    String? address,
    String? locationDetails,
    int? maxParticipants,
    int? currentParticipants,
    List<String>? participants,
    String? category,
    String? subcategory,
    String? hobby,
    List<String>? categories,
    List<String>? subcategories,
    List<String>? hobbies,
    String? requiredSkillLevel,
    String? visibility,
    EventAccessibility? accessibility,
    List<ScheduleItem>? schedule,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      duration: duration ?? this.duration,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      city: city ?? this.city,
      address: address ?? this.address,
      locationDetails: locationDetails ?? this.locationDetails,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      participants: participants ?? this.participants,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      hobby: hobby ?? this.hobby,
      categories: categories ?? this.categories,
      subcategories: subcategories ?? this.subcategories,
      hobbies: hobbies ?? this.hobbies,
      requiredSkillLevel: requiredSkillLevel ?? this.requiredSkillLevel,
      visibility: visibility ?? this.visibility,
      accessibility: accessibility ?? this.accessibility,
      schedule: schedule ?? this.schedule,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }
}
