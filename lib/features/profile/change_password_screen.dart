import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/endpoints.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';

/// Change password.
///
/// `PUT /auth/password {currentPassword, newPassword}`. The strength meter is
/// advisory — the server's only hard rule is six characters — but it nudges
/// people off "123456" without blocking them, which is the right trade for an
/// internal tool.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNext = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _next.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// 0–4, with a plain-language label.
  (int, String, Color) _strength(String value) {
    if (value.isEmpty) return (0, '', AppColors.slate400);
    var score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    score = score.clamp(0, 4);
    return switch (score) {
      0 || 1 => (score, 'Weak', AppColors.danger),
      2 => (score, 'Fair', AppColors.warning),
      3 => (score, 'Good', AppColors.brandTeal),
      _ => (score, 'Strong', AppColors.success),
    };
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).put(
        Api.changePassword,
        body: {
          'currentPassword': _current.text,
          'newPassword': _next.text,
        },
      );
      if (mounted) {
        showToast(context, 'Password updated');
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, e.message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (score, label, color) = _strength(_next.text);

    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: BusyOverlay(
        busy: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.lg,
              AppSpacing.gutter,
              AppSpacing.xxxl,
            ),
            children: [
              TextFormField(
                controller: _current,
                obscureText: _obscureCurrent,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Current password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                    icon: Icon(
                      _obscureCurrent
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Enter your current password'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _next,
                obscureText: _obscureNext,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'New password',
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscureNext = !_obscureNext),
                    icon: Icon(
                      _obscureNext
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Choose a new password';
                  if (v.length < 6) {
                    return 'At least 6 characters';
                  }
                  if (v == _current.text) {
                    return 'That is your current password';
                  }
                  return null;
                },
              ),
              if (_next.text.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: i < score
                                ? color
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      width: 46,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _confirm,
                obscureText: _obscureNext,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                  prefixIcon: Icon(Icons.check_circle_outline_rounded),
                ),
                validator: (v) =>
                    v != _next.text ? 'Passwords do not match' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: const Text('Update password'),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Changing your password does not sign you out of other '
                        'devices — the platform has no way to revoke an issued '
                        'token. Sign out anywhere you no longer use.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
