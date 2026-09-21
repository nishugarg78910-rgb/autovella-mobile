import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/endpoints.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/util/json.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';

/// A soft-deleted record.
class DeletedItem {
  const DeletedItem({
    required this.id,
    required this.name,
    required this.type,
    this.deletedAt,
    this.deletedByName,
    this.expiresAt,
    this.detail,
  });

  final String id;
  final String name;
  final String type;
  final DateTime? deletedAt;
  final String? deletedByName;

  /// Records are purged automatically; this is when this one goes.
  final DateTime? expiresAt;

  int get daysLeft {
    if (expiresAt == null) return 0;
    final d = expiresAt!.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }

  /// Whatever else the row carries, shown on the detail sheet.
  final Map<String, dynamic>? detail;

  IconData get icon => switch (type.toLowerCase()) {
        'project' => Icons.folder_outlined,
        'task' => Icons.check_circle_outline_rounded,
        'deal' => Icons.handshake_outlined,
        'account' => Icons.business_outlined,
        'contact' => Icons.person_outline_rounded,
        'invoice' => Icons.receipt_long_rounded,
        'expense' => Icons.account_balance_wallet_outlined,
        'sprint' => Icons.directions_run_rounded,
        _ => Icons.description_outlined,
      };

  /// Field names verified against a live response:
  /// `{entityType, entityName, deletedBy (an id), deletedByName, deletedAt,
  ///   expiresAt}`. An earlier build looked for `name` and treated
  /// `deletedBy` as an object, so every row rendered as "Untitled" with no
  /// detail — which is exactly how the screen looked on device.
  factory DeletedItem.fromJson(Map<String, dynamic> json) => DeletedItem(
        id: J.str(json['id']),
        name: J.str(
          J.pick(json, ['entityName', 'name', 'title', 'invoiceNumber']),
          'Untitled',
        ),
        type: J.str(
          J.pick(json, ['entityType', 'type', 'resourceType']),
          'record',
        ),
        deletedAt: J.date(json['deletedAt']),
        deletedByName: J.strOrNull(
          J.pick(json, ['deletedByName', 'deletedByUserName']),
        ),
        expiresAt: J.date(json['expiresAt']),
        detail: json,
      );
}

final recycleBinProvider =
    FutureProvider.autoDispose<List<DeletedItem>>((ref) async {
  final data = await ref.watch(apiClientProvider).get(
        Api.recycleBin,
        query: {'limit': 100},
      );
  return J.maps(ApiClient.asList(data)).map(DeletedItem.fromJson).toList();
});

/// Recycle bin.
///
/// The earlier version listed rows with no information and nothing to tap.
/// Each row now says what the record was, who deleted it and when, opens a
/// detail sheet, and can be restored.
class RecycleBinScreen extends ConsumerStatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  ConsumerState<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends ConsumerState<RecycleBinScreen> {
  final _busy = <String>{};

  Future<void> _restore(DeletedItem item) async {
    setState(() => _busy.add(item.id));
    try {
      await ref.read(apiClientProvider).post(Api.recycleRestore(item.id));
      ref.invalidate(recycleBinProvider);
      if (mounted) showToast(context, '${item.name} restored');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  void _open(DeletedItem item) {
    final fields = <MapEntry<String, String>>[];
    item.detail?.forEach((key, value) {
      if (value == null || value is Map || value is List) return;
      if (const {'id', 'organizationId'}.contains(key)) return;
      final text = '$value';
      if (text.isEmpty) return;
      fields.add(MapEntry(_humanise(key), text));
    });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                Icon(item.icon, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ToneChip.status(item.type),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  DetailRow(
                    label: 'Deleted',
                    icon: Icons.schedule_rounded,
                    value: Fmt.dateTime(item.deletedAt),
                  ),
                  DetailRow(
                    label: 'Deleted by',
                    icon: Icons.person_outline_rounded,
                    value: item.deletedByName,
                  ),
                  DetailRow(
                    label: 'Purges',
                    icon: Icons.auto_delete_outlined,
                    value: item.expiresAt == null
                        ? null
                        : '${Fmt.fullDate(item.expiresAt)} '
                            '(in ${item.daysLeft}d)',
                  ),
                  for (final f in fields.take(14))
                    DetailRow(label: f.key, value: f.value),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _restore(item);
              },
              icon: const Icon(Icons.restore_rounded, size: 18),
              label: const Text('Restore'),
            ),
          ],
        ),
      ),
    );
  }

  static String _humanise(String key) => key
      .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ')
      .replaceAll('_', ' ')
      .trim()
      .replaceRange(0, 1, key.isEmpty ? '' : key[0].toUpperCase());

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(recycleBinProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recycle bin')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recycleBinProvider);
          await ref.read(recycleBinProvider.future);
        },
        child: AsyncView<List<DeletedItem>>(
          value: items,
          onRetry: () => ref.invalidate(recycleBinProvider),
          data: (rows) {
            if (rows.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.delete_outline_rounded,
                    title: 'Recycle bin is empty',
                    message:
                        'Deleted records stay here until they are restored or '
                        'permanently removed.',
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.xxxl,
              ),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) {
                final item = rows[i];
                final busy = _busy.contains(item.id);
                return AppCard(
                  onTap: () => _open(item),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: AppRadius.rMd,
                        ),
                        child: Icon(item.icon, size: 18),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                ToneChip.status(item.type, dense: true),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    [
                                      if (item.deletedByName != null)
                                        item.deletedByName!,
                                      Fmt.relative(item.deletedAt),
                                    ].where((e) => e.isNotEmpty).join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(fontSize: 11.5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: busy ? null : () => _restore(item),
                        icon: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.restore_rounded, size: 20),
                        tooltip: 'Restore',
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
