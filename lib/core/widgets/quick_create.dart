import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/auth/auth_controller.dart';
import '../api/endpoints.dart';
import '../theme/tokens.dart';

/// One thing the user can create, and what it needs permission-wise.
class _CreateAction {
  const _CreateAction(
    this.label,
    this.subtitle,
    this.icon,
    this.route,
    this.module, {
    this.feature,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final String route;
  final String module;
  final String? feature;
}

const _actions = [
  _CreateAction('Task', 'Something that needs doing',
      Icons.add_task_rounded, '/tasks/new', 'tasks'),
  _CreateAction('Time entry', 'Log hours against a project',
      Icons.schedule_rounded, '/timesheets/new', 'timesheets',
      feature: 'timesheets'),
  _CreateAction('Expense', 'Snap a receipt and file it',
      Icons.receipt_long_rounded, '/expenses', 'expenses',
      feature: 'expenses'),
  _CreateAction('Leave request', 'Book time off',
      Icons.beach_access_rounded, '/time-off/new', 'timeOff',
      feature: 'time_off'),
  _CreateAction('Project', 'A new piece of work',
      Icons.folder_open_rounded, '/projects/new', 'projects'),
];

/// The create sheet, reachable from anywhere.
///
/// A phone app should never make someone navigate to a list in order to add
/// something. Only actions the role can actually perform are shown — an
/// option that fails with a 403 is worse than no option.
Future<void> showQuickCreate(BuildContext context, WidgetRef ref) async {
  HapticFeedback.selectionClick();
  final user = ref.read(currentUserProvider);

  final available = _actions.where((a) {
    if (user == null) return false;
    if (a.feature != null &&
        !(user.organization?.hasFeature(a.feature!) ?? true)) {
      return false;
    }
    return user.permissions.canCreate(a.module);
  }).toList();

  if (available.isEmpty) return;

  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Create',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
          ),
          for (final a in available)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
                  borderRadius: AppRadius.rMd,
                ),
                child: Icon(
                  a.icon,
                  size: 19,
                  color: Theme.of(sheetContext).colorScheme.primary,
                ),
              ),
              title: Text(
                a.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(a.subtitle),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push(a.route);
              },
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

/// Shares a record through the system sheet.
///
/// The link points at the web app, which is where a colleague who receives it
/// will open it — deep-linking into someone else's phone app would fail for
/// anyone who has not installed it.
Future<void> shareRecord({
  required String title,
  required String path,
  String? subtitle,
}) async {
  final url = '${Api.baseUrl}$path';
  final body = subtitle == null ? '$title\n$url' : '$title\n$subtitle\n$url';
  await Share.share(body, subject: title);
}

/// An app-bar share button for a record.
class ShareButton extends StatelessWidget {
  const ShareButton({
    super.key,
    required this.title,
    required this.path,
    this.subtitle,
  });

  final String title;
  final String path;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Share',
      icon: const Icon(Icons.ios_share_rounded),
      onPressed: () {
        HapticFeedback.selectionClick();
        shareRecord(title: title, path: path, subtitle: subtitle);
      },
    );
  }
}
