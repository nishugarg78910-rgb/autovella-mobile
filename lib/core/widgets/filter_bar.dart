import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// How a list is ordered.
enum SortOrder { dueDate, priority, project, recentlyUpdated, title }

extension SortOrderLabel on SortOrder {
  String get label => switch (this) {
        SortOrder.dueDate => 'Due date',
        SortOrder.priority => 'Priority',
        SortOrder.project => 'Project',
        SortOrder.recentlyUpdated => 'Recently updated',
        SortOrder.title => 'Title',
      };

  IconData get icon => switch (this) {
        SortOrder.dueDate => Icons.event_outlined,
        SortOrder.priority => Icons.flag_outlined,
        SortOrder.project => Icons.folder_outlined,
        SortOrder.recentlyUpdated => Icons.history_rounded,
        SortOrder.title => Icons.sort_by_alpha_rounded,
      };
}

/// A horizontal row of filter chips with a sort control on the right.
///
/// Sits under the app bar rather than behind a menu: on a list you scan every
/// day, the current filter should be visible without opening anything, and
/// clearing it should be one tap.
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.chips,
    required this.selected,
    required this.onSelect,
    this.sort,
    this.onSort,
  });

  /// Label → count. A count of null hides the badge.
  final Map<String, int?> chips;
  final String selected;
  final ValueChanged<String> onSelect;
  final SortOrder? sort;
  final ValueChanged<SortOrder>? onSort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
                vertical: 4,
              ),
              children: [
                for (final entry in chips.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        entry.value == null
                            ? entry.key
                            : '${entry.key} ${entry.value}',
                      ),
                      selected: selected == entry.key,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        onSelect(entry.key);
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (sort != null && onSort != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: PopupMenuButton<SortOrder>(
                tooltip: 'Sort',
                initialValue: sort,
                onSelected: (value) {
                  HapticFeedback.selectionClick();
                  onSort!(value);
                },
                itemBuilder: (context) => [
                  for (final o in SortOrder.values)
                    PopupMenuItem(
                      value: o,
                      child: Row(
                        children: [
                          Icon(o.icon, size: 17),
                          const SizedBox(width: AppSpacing.md),
                          Text(o.label),
                          if (o == sort) ...[
                            const Spacer(),
                            const Icon(Icons.check_rounded, size: 16),
                          ],
                        ],
                      ),
                    ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: AppRadius.rPill,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(sort!.icon, size: 14),
                      const SizedBox(width: 5),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 15,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
