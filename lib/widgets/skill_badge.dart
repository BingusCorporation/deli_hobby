import 'package:flutter/material.dart';
import '../data/skill_levels.dart';

class SkillBadge extends StatelessWidget {
  final String skillLevel;
  final bool showLabel;
  final double size;

  const SkillBadge({
    super.key,
    required this.skillLevel,
    this.showLabel = false,
    this.size = 20,
  });

  Color get _color {
    switch (skillLevel) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get _shortLabel => skillLevelLabelsShort[skillLevel] ?? '?';
  String get _fullLabel => skillLevels[skillLevel] ?? skillLevel;

  @override
  Widget build(BuildContext context) {
    if (showLabel) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _color),
        ),
        child: Text(
          _fullLabel,
          style: TextStyle(
            color: _color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          _shortLabel,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class HobbyChipWithSkill extends StatelessWidget {
  final String hobby;
  final String? skillLevel;
  final bool isEditing;
  final VoidCallback? onDeleted;

  const HobbyChipWithSkill({
    super.key,
    required this.hobby,
    this.skillLevel,
    this.isEditing = false,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              hobby,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (skillLevel != null) ...[
            const SizedBox(width: 6),
            SkillBadge(skillLevel: skillLevel!, size: 18),
          ],
        ],
      ),
      deleteIcon: isEditing ? const Icon(Icons.close, size: 16) : null,
      onDeleted: isEditing ? onDeleted : null,
    );
  }
}
