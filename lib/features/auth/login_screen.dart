import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/states.dart';
import 'auth_controller.dart';

/// Sign-in.
///
/// Centred on the page with the brand lockup above the form — the previous
/// build had no logo at all and pinned the form to the top, which read as
/// unfinished on a tall phone.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _remember = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final ok = await ref.read(authProvider.notifier).signIn(
          identifier: _identifier.text,
          password: _password.text,
          remember: _remember,
        );
    if (!ok && mounted) {
      final error = ref.read(authProvider).error;
      if (error != null) showToast(context, error, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    final busy = auth.isSubmitting;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                      vertical: AppSpacing.xxxl,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AutovellaLockup(
                            height: 72,
                            showTagline: true,
                          ),
                          const SizedBox(height: AppSpacing.xxxl),
                          Text(
                            'Welcome back',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Sign in to your account to continue.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxxl),
                          TextFormField(
                            controller: _identifier,
                            enabled: !busy,
                            autofillHints: const [AutofillHints.username],
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Username or email',
                              hintText: 'Enter your username or email',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter your username or email'
                                : null,
                            onFieldSubmitted: (_) =>
                                _passwordFocus.requestFocus(),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextFormField(
                            controller: _password,
                            focusNode: _passwordFocus,
                            enabled: !busy,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                                tooltip:
                                    _obscure ? 'Show password' : 'Hide password',
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Enter your password'
                                : null,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: AppRadius.rSm,
                                  onTap: busy
                                      ? null
                                      : () =>
                                          setState(() => _remember = !_remember),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: _remember,
                                        onChanged: busy
                                            ? null
                                            : (v) => setState(
                                                  () => _remember = v ?? true,
                                                ),
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Keep me signed in',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed:
                                    busy ? null : () => _forgotPassword(context),
                                child: const Text('Forgot password?'),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton(
                            onPressed: busy ? null : _submit,
                            child: busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Sign In'),
                          ),
                          const SizedBox(height: AppSpacing.xxxl),
                          Text(
                            '© ${DateTime.now().year} Autovella',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _forgotPassword(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset your password'),
        content: const Text(
          'Password resets are handled on the web app. Open autovella.cloud '
          'and choose "Forgot password?" to receive a reset link by email.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
