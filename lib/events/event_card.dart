import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event_model.dart';
import 'skill_badge.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final int? matchScore;
  final VoidCallback? onTap;
  final bool showOrganizer;

  const EventCard({
    super.key,
    required this.event,
    this.matchScore,
    this.onTap,
    this.showOrganizer = true,
  });

  Color _getMatchColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.blue;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays == 0) {
      return 'Danas, ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Sutra, ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE, HH:mm', 'sr').format(date);
    } else {
      return DateFormat('dd.MM.yyyy HH:mm').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Title + Match score
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Category chips
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children:
                              (event.hobbies.isNotEmpty
                                      ? event.hobbies
                                      : [event.hobby])
                                  .take(3) // Show max 3 categories
                                  .map(
                                    (hobby) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        hobby,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                        if (event.hobbies.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '+${event.hobbies.length - 3} jos',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (matchScore != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getMatchColor(matchScore!),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$matchScore%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Date and time
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(event.startDateTime),
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                  if (event.isRecurring) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.repeat, size: 14, color: Colors.grey[500]),
                  ],
                ],
              ),

              const SizedBox(height: 6),

              // Location
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${event.city} - ${event.address}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Bottom row: Participants, Skill level, Visibility
              Row(
                children: [
                  // Participants
                  Icon(Icons.people, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${event.currentParticipants}/${event.maxParticipants}',
                    style: TextStyle(
                      color: event.isFull ? Colors.red : Colors.grey[700],
                      fontSize: 13,
                      fontWeight: event.isFull
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Skill level
                  if (event.requiredSkillLevel != 'any') ...[
                    SkillBadge(
                      skillLevel: event.requiredSkillLevel,
                      showLabel: true,
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Svi nivoi',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),

                  const Spacer(),

                  // Visibility badge
                  if (event.isPrivate)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock,
                            size: 12,
                            color: Colors.purple.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Privatno',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // Organizer info
              if (showOrganizer) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.grey[300],
                      child: const Icon(Icons.person, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Organizator: ${event.organizerName}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
