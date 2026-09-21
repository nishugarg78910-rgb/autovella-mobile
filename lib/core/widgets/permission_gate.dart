import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import 'atoms.dart';

/// A [DetailRow] that disappears when the signed-in role cannot read the
/// field.
///
/// The platform supports per-field grants, so a Sales role may see a deal's
/// `amount` but not a project's `budget`. Hiding the row is the correct
/// behaviour — showing a blank is a hint, and showing the value is a leak.
class GuardedRow extends ConsumerWidget {
  const GuardedRow({
    super.key,
    required this.module,
    required this.field,
    required this.label,
    this.value,
    this.child,
    this.icon,
  });

  final String module;
  final String field;
  final String label;
  final String? value;
  final Widget? child;
  final IconData? icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);
    if (!perms.canReadField(module, field)) return const SizedBox.shrink();
    return DetailRow(label: label, value: value, icon: icon, child: child);
  }
}

/// Shows [child] only when the role may read [field] of [module].
class GuardedField extends ConsumerWidget {
  const GuardedField({
    super.key,
    required this.module,
    required this.field,
    required this.child,
  });

  final String module;
  final String field;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);
    if (!perms.canReadField(module, field)) return const SizedBox.shrink();
    return child;
  }
}

/// Shows [child] only when the role may perform [action] on [module].
class GuardedAction extends ConsumerWidget {
  const GuardedAction({
    super.key,
    required this.module,
    this.action = 'update',
    required this.child,
  });

  final String module;
  final String action;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);
    if (!perms.can(module, action)) return const SizedBox.shrink();
    return child;
  }
}
