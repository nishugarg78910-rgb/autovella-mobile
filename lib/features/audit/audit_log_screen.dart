import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/util/json.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/states.dart';

/// One entry in the organisation's audit trail.
class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.action,
    required this.entityType,
    this.entityName,
    this.entityId,
    this.actorName,
    this.at,
    this.changes,
    this.raw,
  });

  final String id;

  /// create | update | delete | login | …
  final String action;
  final String entityType;
  final String? entityName;
  final String? entityId;
  final String? actorName;
  final DateTime? at;

  /// Field-level diff, when the server records one.
  final Map<String, dynamic>? changes;
  final Map<String, dynamic>? raw;

  String get verb => switch (_kind) {
        'create' => 'created',
        'delete' => 'deleted',
        'update' => 'updated',
        'login' => 'signed in',
        'logout' => 'signed out',
        'approve' => 'approved',
        'reject' => 'rejected',
        _ => action.toLowerCase(),
      };

  String get _kind {
    final a = action.toLowerCase();
    if (a.contains('create') || a.contains('add')) return 'create';
    if (a.contains('delete') || a.contains('remove')) return 'delete';
    if (a.contains('update') || a.contains('edit') || a.contains('change')) {
      return 'update';
    }
    if (a.contains('login') || a.contains('signin')) return 'login';
    if (a.contains('logout')) return 'logout';
    if (a.contains('approve')) return 'approve';
    if (a.contains('reject')) return 'reject';
    return 'other';
  }

  Color get color => switch (_kind) {
        'create' => AppColors.success,
        'delete' => AppColors.danger,
        'update' => AppColors.brand600,
        'approve' => AppColors.success,
        'reject' => AppColors.danger,
        'login' || 'logout' => AppColors.brandViolet,
        _ => AppColors.slate500,
      };

  IconData get icon => switch (_kind) {
        'create' => Icons.add_circle_outline_rounded,
        'delete' => Icons.remove_circle_outline_rounded,
        'update' => Icons.edit_outlined,
        'approve' => Icons.check_circle_outline_rounded,
        'reject' => Icons.cancel_outlined,
        'login' || 'logout' => Icons.login_rounded,
        _ => Icons.circle_outlined,
      };

  /// 'create' | 'update' | 'delete' | 'other' — used by the filter chips.
  String get bucket => switch (_kind) {
        'create' => 'Created',
        'update' => 'Updated',
        'delete' => 'Deleted',
        'approve' || 'reject' => 'Decisions',
        _ => 'Other',
      };

  factory AuditEvent.fromJson(Map<String, dynamic> json) => AuditEvent(
        id: J.str(json['id']),
        action: J.str(J.pick(json, ['action', 'event', 'type']), 'change'),
        entityType: J.str(
          J.pick(json, ['entityType', 'resourceType', 'model']),
          'record',
        ),
        entityName: J.strOrNull(
          J.pick(json, ['entityName', 'name', 'title', 'resourceName']),
        ),
        entityId: J.strOrNull(J.pick(json, ['entityId', 'resourceId'])),
        actorName: J.strOrNull(
              J.pick(json, ['userName', 'actorName', 'deletedByName']),
            ) ??
            _nameOf(json['user'] ?? json['actor']),
        at: J.date(J.pick(json, ['createdAt', 'timestamp', 'at'])),
        changes: J.mapOrNull(J.pick(json, ['changes', 'diff', 'metadata'])),
        raw: json,
      );

  static String? _nameOf(dynamic value) {
    final m = J.mapOrNull(value);
    if (m == null) return null;
    final name = '${J.str(m['firstName'])} ${J.str(m['lastName'])}'.trim();
    return name.isEmpty ? J.strOrNull(m['email']) : name;
  }
}

/// The audit trail.
///
/// Each row carries a page-sized payload server-side (the actor's avatar is
/// inlined as base64), so this asks for a small page deliberately.
final auditEventsProvider =
    FutureProvider.autoDispose<List<AuditEvent>>((ref) async {
  final data = await ref.watch(apiClientProvider).get(
        Api.auditLogs,
        query: {'limit': 40},
      );
  return J.maps(ApiClient.asList(data)).map(AuditEvent.fromJson).toList();
});

/// Audit log.
///
/// Rebuilt as an activity timeline rather than an undifferentiated list: the
/// question people bring here is "who changed this, and when", so the actor
/// and the verb lead, entries group by day, and every row opens the full
/// record of what changed.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(auditEventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit log')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(auditEventsProvider);
          await ref.read(auditEventsProvider.future);
        },
        child: AsyncView<List<AuditEvent>>(
          value: events,
          onRetry: () => ref.invalidate(auditEventsProvider),
          data: (all) {
            if (all.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.history_rounded,
                    title: 'No activity recorded',
                    message:
                        'Every change made in your organisation is logged here.',
                  ),
                ],
              );
            }

            final buckets = <String, int>{};
            for (final e in all) {
              buckets[e.bucket] = (buckets[e.bucket] ?? 0) + 1;
            }

            final filtered = _filter == 'All'
                ? all
                : all.where((e) => e.bucket == _filter).toList();

            // Group by calendar day.
            final byDay = <DateTime, List<AuditEvent>>{};
            for (final e in filtered) {
              final d = e.at ?? DateTime.now();
              byDay
                  .putIfAbsent(DateTime(d.year, d.month, d.day), () => [])
                  .add(e);
            }
            final days = byDay.keys.toList()
              ..sort((a, b) => b.compareTo(a));

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.xxxl,
              ),
              children: [
                AppCard(
                  child: StackedBar(
                    segments: [
                      for (final entry in buckets.entries)
                        BarDatum(
                          label: entry.key,
                          value: entry.value.toDouble(),
                          caption: '${entry.value}',
                          color: _bucketColor(entry.key),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final chip in ['All', ...buckets.keys])
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ChoiceChip(
                            label: Text(
                              chip == 'All' ? 'All ${all.length}' : chip,
                            ),
                            selected: _filter == chip,
                            onSelected: (_) => setState(() => _filter = chip),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final day in days) ...[
                  _DayHeader(day: day, count: byDay[day]!.length),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < byDay[day]!.length; i++)
                          _EventRow(
                            event: byDay[day]![i],
                            isLast: i == byDay[day]!.length - 1,
                            onTap: () => _open(byDay[day]![i]),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  static Color _bucketColor(String bucket) => switch (bucket) {
        'Created' => AppColors.success,
        'Updated' => AppColors.brand600,
        'Deleted' => AppColors.danger,
        'Decisions' => AppColors.brandViolet,
        _ => AppColors.slate400,
      };

  void _open(AuditEvent event) {
    final fields = <MapEntry<String, String>>[];
    event.raw?.forEach((key, value) {
      if (value == null || value is List) return;
      if (const {'id', 'organizationId'}.contains(key)) return;
      // Avatars arrive as 200 KB base64 strings; never render one as text.
      final text = '$value';
      if (text.startsWith('data:image')) return;
      if (value is Map) return;
      if (text.isEmpty) return;
      fields.add(MapEntry(_humanise(key), text));
    });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: event.color.withValues(alpha: 0.12),
                    borderRadius: AppRadius.rMd,
                  ),
                  child: Icon(event.icon, size: 18, color: event.color),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${event.actorName ?? 'Someone'} ${event.verb} '
                        '${event.entityType}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        Fmt.dateTime(event.at),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (event.entityName != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Text(
                  event.entityName!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
            if (event.changes?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xl),
              const SectionLabel('What changed'),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    for (final c in event.changes!.entries)
                      DetailRow(
                        label: _humanise(c.key),
                        value: '${c.value}',
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Record'),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  for (final f in fields.take(20))
                    DetailRow(label: f.key, value: f.value),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _humanise(String key) {
    final spaced = key
        .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ')
        .replaceAll('_', ' ')
        .trim();
    if (spaced.isEmpty) return key;
    return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.count});

  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.xs),
      child: Row(
        children: [
          Text(
            Fmt.friendlyDate(day).toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 11,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '· $count',
            style: theme.textTheme.labelSmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// A timeline row: a coloured rail, the actor and verb, and the time.
class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.isLast,
    required this.onTap,
  });

  final AuditEvent event;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.rSm,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: event.color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(event.icon, size: 13, color: event.color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium,
                        children: [
                          TextSpan(
                            text: event.actorName ?? 'Someone',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: ' ${event.verb} '),
                          TextSpan(
                            text: event.entityName ?? event.entityType,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          Fmt.time(event.at),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 11.5),
                        ),
                        const SizedBox(width: 6),
                        ToneChip.status(event.entityType, dense: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
