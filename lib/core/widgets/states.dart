import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../theme/tokens.dart';

/// Friendly empty state. Every list screen supplies its own copy so the user
/// is told what *this* screen would contain, never a bare "No data".
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: compact ? AppSpacing.xxl : AppSpacing.xxxl * 2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 48 : 64,
              height: compact ? 48 : 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: compact ? 22 : 28,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state that distinguishes the three cases a user can actually act on:
/// offline, forbidden, and everything else.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;

    final IconData icon;
    final String title;
    if (api?.isNetwork == true) {
      icon = Icons.wifi_off_rounded;
      title = 'You appear to be offline';
    } else if (api?.isForbidden == true) {
      icon = Icons.lock_outline_rounded;
      title = 'Not available to your role';
    } else if (api?.isNotFound == true) {
      icon = Icons.search_off_rounded;
      title = 'Not found';
    } else {
      icon = Icons.error_outline_rounded;
      title = 'Something went wrong';
    }

    return EmptyState(
      icon: icon,
      title: title,
      message: api?.message ?? error.toString(),
      // A 403 will not change on retry, so do not invite the user to bounce
      // off it. The MCP contract says the same: never retry a 403.
      actionLabel: (onRetry != null && api?.isForbidden != true)
          ? 'Try again'
          : null,
      onAction: onRetry,
    );
  }
}

/// Shimmering placeholder block.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppRadius.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(base, base.withValues(alpha: 0.4), _controller.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Placeholder rows shown while a list loads, shaped like the real rows so
/// the layout does not jump when data arrives.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.rLg,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Skeleton(width: 28, height: 28, radius: 14),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Skeleton(width: double.infinity, height: 13)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Skeleton(width: 180, height: 11),
            const SizedBox(height: AppSpacing.sm),
            const Skeleton(width: 110, height: 11),
          ],
        ),
      ),
    );
  }
}

/// Renders an [AsyncValue] with consistent loading and error treatments.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => loading ?? const SkeletonList(),
      error: (error, _) => ErrorView(error: error, onRetry: onRetry),
    );
  }
}

/// Full-screen blocking spinner for submits.
class BusyOverlay extends StatelessWidget {
  const BusyOverlay({super.key, required this.busy, required this.child});

  final bool busy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

/// Snackbar helpers so success/failure feedback is uniform.
void showToast(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
              size: 18,
              color: isError ? AppColors.dangerSoft : AppColors.successSoft,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
}
