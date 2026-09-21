import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/tokens.dart';
import 'states.dart';

/// Turns a phone number, email address or URL into something you can act on.
///
/// A CRM on a phone is mostly a launcher: you look someone up in order to
/// call or email them. Showing the number as inert text makes the user copy
/// it into another app by hand.
enum ContactKind { phone, email, url, address }

class ContactActions {
  const ContactActions._();

  static Future<void> call(BuildContext context, String number) =>
      _launch(context, Uri(scheme: 'tel', path: _cleanNumber(number)),
          'No phone app on this device');

  static Future<void> sms(BuildContext context, String number) =>
      _launch(context, Uri(scheme: 'sms', path: _cleanNumber(number)),
          'No messaging app on this device');

  /// WhatsApp matters more than SMS for business contact in India.
  static Future<void> whatsapp(BuildContext context, String number) {
    final digits = _cleanNumber(number).replaceAll(RegExp(r'[^0-9]'), '');
    return _launch(
      context,
      Uri.parse('https://wa.me/$digits'),
      'Could not open WhatsApp',
    );
  }

  static Future<void> email(
    BuildContext context,
    String address, {
    String? subject,
  }) =>
      _launch(
        context,
        Uri(
          scheme: 'mailto',
          path: address.trim(),
          query: subject == null ? null : 'subject=${Uri.encodeComponent(subject)}',
        ),
        'No mail app on this device',
      );

  static Future<void> open(BuildContext context, String url) {
    var target = url.trim();
    if (!target.startsWith('http://') && !target.startsWith('https://')) {
      target = 'https://$target';
    }
    return _launch(context, Uri.parse(target), 'Could not open that link');
  }

  static Future<void> map(BuildContext context, String address) => _launch(
        context,
        Uri.parse(
          'https://maps.google.com/?q=${Uri.encodeComponent(address.trim())}',
        ),
        'Could not open maps',
      );

  static void copy(BuildContext context, String value, {String? label}) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.selectionClick();
    showToast(context, '${label ?? 'Copied'} to clipboard');
  }

  /// Strips formatting but keeps a leading `+` so international dialling works.
  static String _cleanNumber(String raw) {
    final trimmed = raw.trim();
    final plus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return plus ? '+$digits' : digits;
  }

  static Future<void> _launch(
    BuildContext context,
    Uri uri,
    String failure,
  ) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) showToast(context, failure, isError: true);
    } catch (_) {
      if (context.mounted) showToast(context, failure, isError: true);
    }
  }
}

/// A detail row whose value is actionable — tap to call / mail / open, long
/// press to copy, with the relevant shortcut buttons on the right.
class ContactRow extends StatelessWidget {
  const ContactRow({
    super.key,
    required this.label,
    required this.value,
    required this.kind,
    this.subject,
  });

  final String label;
  final String? value;
  final ContactKind kind;

  /// Prefilled subject when [kind] is email.
  final String? subject;

  IconData get _icon => switch (kind) {
        ContactKind.phone => Icons.phone_outlined,
        ContactKind.email => Icons.mail_outline_rounded,
        ContactKind.url => Icons.language_rounded,
        ContactKind.address => Icons.place_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = value?.trim();
    if (v == null || v.isEmpty) return const SizedBox.shrink();

    Future<void> primary() => switch (kind) {
          ContactKind.phone => ContactActions.call(context, v),
          ContactKind.email =>
            ContactActions.email(context, v, subject: subject),
          ContactKind.url => ContactActions.open(context, v),
          ContactKind.address => ContactActions.map(context, v),
        };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 116,
            child: Row(
              children: [
                Icon(_icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: InkWell(
              onTap: primary,
              onLongPress: () => ContactActions.copy(context, v, label: label),
              borderRadius: AppRadius.rSm,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  v,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          if (kind == ContactKind.phone) ...[
            _MiniAction(
              icon: Icons.chat_rounded,
              tooltip: 'WhatsApp',
              color: const Color(0xFF25D366),
              onTap: () => ContactActions.whatsapp(context, v),
            ),
            _MiniAction(
              icon: Icons.phone_rounded,
              tooltip: 'Call',
              onTap: primary,
            ),
          ] else
            _MiniAction(
              icon: switch (kind) {
                ContactKind.email => Icons.send_rounded,
                ContactKind.url => Icons.open_in_new_rounded,
                _ => Icons.directions_rounded,
              },
              tooltip: switch (kind) {
                ContactKind.email => 'Email',
                ContactKind.url => 'Open',
                _ => 'Directions',
              },
              onTap: primary,
            ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: AppRadius.rPill,
        child: Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: tint),
        ),
      ),
    );
  }
}

/// A row of large call / WhatsApp / email / web buttons, for the top of a
/// contact or account screen.
class ContactActionBar extends StatelessWidget {
  const ContactActionBar({
    super.key,
    this.phone,
    this.email,
    this.website,
    this.subject,
  });

  final String? phone;
  final String? email;
  final String? website;
  final String? subject;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (phone != null && phone!.trim().isNotEmpty) ...[
        _Big(
          icon: Icons.phone_rounded,
          label: 'Call',
          onTap: () => ContactActions.call(context, phone!),
        ),
        _Big(
          icon: Icons.chat_rounded,
          label: 'WhatsApp',
          color: const Color(0xFF25D366),
          onTap: () => ContactActions.whatsapp(context, phone!),
        ),
      ],
      if (email != null && email!.trim().isNotEmpty)
        _Big(
          icon: Icons.mail_rounded,
          label: 'Email',
          onTap: () => ContactActions.email(context, email!, subject: subject),
        ),
      if (website != null && website!.trim().isNotEmpty)
        _Big(
          icon: Icons.language_rounded,
          label: 'Website',
          onTap: () => ContactActions.open(context, website!),
        ),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(child: actions[i]),
        ],
      ],
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Material(
      color: tint.withValues(alpha: 0.10),
      borderRadius: AppRadius.rMd,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: AppRadius.rMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            children: [
              Icon(icon, size: 20, color: tint),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: tint,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
