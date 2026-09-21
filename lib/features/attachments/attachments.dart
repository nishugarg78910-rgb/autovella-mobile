import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/endpoints.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';
import '../../data/repository.dart';
import '../../models/work.dart';

/// Which record's attachments to load.
class AttachmentQuery {
  const AttachmentQuery({required this.entityType, required this.entityId});

  final String entityType;
  final String entityId;

  @override
  bool operator ==(Object other) =>
      other is AttachmentQuery &&
      other.entityType == entityType &&
      other.entityId == entityId;

  @override
  int get hashCode => Object.hash(entityType, entityId);
}

final attachmentsProvider = FutureProvider.autoDispose
    .family<List<Attachment>, AttachmentQuery>((ref, q) {
  return ref.watch(attachmentRepoProvider).list(
    filters: {
      'entityType': q.entityType,
      'entityId': q.entityId,
      '${q.entityType}Id': q.entityId,
    },
  );
});

/// Attachments for a record: thumbnails for images, a row per file, tap to
/// preview or open.
class AttachmentsSection extends ConsumerStatefulWidget {
  const AttachmentsSection({
    super.key,
    required this.entityType,
    required this.entityId,
    this.canUpload = true,
  });

  final String entityType;
  final String entityId;
  final bool canUpload;

  @override
  ConsumerState<AttachmentsSection> createState() => _AttachmentsSectionState();
}

class _AttachmentsSectionState extends ConsumerState<AttachmentsSection> {
  bool _uploading = false;

  AttachmentQuery get _query => AttachmentQuery(
        entityType: widget.entityType,
        entityId: widget.entityId,
      );

  Future<void> _add() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2400,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      await ref.read(apiClientProvider).upload(
        Api.attachments,
        filePath: picked.path,
        fields: {
          'entityType': widget.entityType,
          'entityId': widget.entityId,
        },
      );
      ref.invalidate(attachmentsProvider(_query));
      if (mounted) showToast(context, 'Attached');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _open(Attachment file) async {
    final url = _absolute(file.url);
    if (url == null) {
      showToast(context, 'This file has no download link.', isError: true);
      return;
    }
    if (file.isImage) {
      showDialog<void>(
        context: context,
        builder: (_) => _ImageViewer(url: url, name: file.name),
      );
      return;
    }
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        showToast(context, 'Could not open this file.', isError: true);
      }
    } catch (_) {
      if (mounted) showToast(context, 'Could not open this file.', isError: true);
    }
  }

  /// Attachment URLs come back relative on some records.
  static String? _absolute(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '${Api.baseUrl}${url.startsWith('/') ? '' : '/'}$url';
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(attachmentsProvider(_query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          'Files',
          action: widget.canUpload ? (_uploading ? 'Uploading…' : 'Add') : null,
          onAction: _uploading ? null : _add,
        ),
        files.when(
          loading: () => const Skeleton(height: 64, radius: AppRadius.lg),
          // Attachments are secondary; a failure here should not shout.
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) {
              return AppCard(
                child: EmptyState(
                  compact: true,
                  icon: Icons.attach_file_rounded,
                  title: 'No files',
                  message: widget.canUpload
                      ? 'Photograph a whiteboard or attach a document.'
                      : null,
                ),
              );
            }

            final images = items.where((f) => f.isImage).toList();
            final others = items.where((f) => !f.isImage).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (images.isNotEmpty)
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (context, i) => _Thumb(
                        file: images[i],
                        url: _absolute(images[i].url),
                        onTap: () => _open(images[i]),
                      ),
                    ),
                  ),
                if (images.isNotEmpty && others.isNotEmpty)
                  const SizedBox(height: AppSpacing.md),
                for (final f in others) ...[
                  _FileRow(file: f, onTap: () => _open(f)),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.file, required this.url, required this.onTap});

  final Attachment file;
  final String? url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: AppRadius.rMd,
        child: Container(
          width: 96,
          color: scheme.surfaceContainerHighest,
          child: url == null
              ? const Icon(Icons.image_outlined)
              : CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined, size: 20),
                  placeholder: (_, __) => const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file, required this.onTap});

  final Attachment file;
  final VoidCallback onTap;

  IconData get _icon {
    final name = file.name.toLowerCase();
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (name.endsWith('.csv') || name.endsWith('.xlsx')) {
      return Icons.table_chart_rounded;
    }
    if (name.endsWith('.doc') || name.endsWith('.docx')) {
      return Icons.description_rounded;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(_icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    file.readableSize,
                    if (file.uploadedBy != null) file.uploadedBy!.fullName,
                    Fmt.relative(file.createdAt),
                  ].where((e) => e.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.open_in_new_rounded, size: 17),
        ],
      ),
    );
  }
}

/// Full-screen image preview with pinch-to-zoom.
class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.url, required this.name});

  final String url;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 40,
                  ),
                  placeholder: (_, __) => const CircularProgressIndicator(),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(
                    Icons.open_in_new_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
