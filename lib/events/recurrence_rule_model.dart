import 'package:cloud_firestore/cloud_firestore.dart';

enum RecurrenceType {
  daily,
  weekly,
  monthly,
  custom,
}

class RecurrenceRule {
  final RecurrenceType type;
  final int interval; // Every N days/weeks/months
  final List<int>? daysOfWeek; // For weekly: 1=Mon, 7=Sun
  final DateTime? endDate;
  final int? occurrences;

  RecurrenceRule({
    required this.type,
    this.interval = 1,
    this.daysOfWeek,
    this.endDate,
    this.occurrences,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'interval': interval,
      'daysOfWeek': daysOfWeek,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'occurrences': occurrences,
    };
  }

  factory RecurrenceRule.fromMap(Map<String, dynamic> map) {
    return RecurrenceRule(
      type: RecurrenceType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => RecurrenceType.weekly,
      ),
      interval: map['interval'] ?? 1,
      daysOfWeek: map['daysOfWeek'] != null
          ? List<int>.from(map['daysOfWeek'])
          : null,
      endDate: map['endDate'] != null
          ? (map['endDate'] as Timestamp).toDate()
          : null,
      occurrences: map['occurrences'],
    );
  }

  String getDisplayText() {
    switch (type) {
      case RecurrenceType.daily:
        return interval == 1 ? 'Svaki dan' : 'Svaka $interval dana';
      case RecurrenceType.weekly:
        if (interval == 1) {
          return 'Svake nedelje';
        }
        return 'Svake $interval nedelje';
      case RecurrenceType.monthly:
        return interval == 1 ? 'Svaki mesec' : 'Svaka $interval meseca';
      case RecurrenceType.custom:
        return 'Prilagodjeno';
    }
  }
}
