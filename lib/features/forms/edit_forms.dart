import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/states.dart';
import '../../data/repository.dart';
import '../../models/work.dart';
import '../work/work_providers.dart';

/// Create a project.
class NewProjectScreen extends ConsumerStatefulWidget {
  const NewProjectScreen({super.key});

  @override
  ConsumerState<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends ConsumerState<NewProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _budget = TextEditingController();
  String _priority = 'medium';
  DateTime? _startDate;
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(projectRepoProvider).create({
        'name': _name.text.trim(),
        if (_description.text.trim().isNotEmpty)
          'description': '<p>${_description.text.trim()}</p>',
        'status': 'active',
        'priority': _priority,
        'currency': 'INR',
        if (_budget.text.trim().isNotEmpty)
          'budget': double.tryParse(_budget.text.trim()),
        if (_startDate != null) 'startDate': Fmt.apiDate(_startDate!),
        if (_dueDate != null) 'dueDate': Fmt.apiDate(_dueDate!),
      });
      ref.invalidate(projectsProvider(null));
      if (mounted) {
        showToast(context, 'Project created');
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
    return Scaffold(
      appBar: AppBar(title: const Text('New project')),
      body: BusyOverlay(
        busy: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Project name'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Give the project a name'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 'medium'),
              ),
              const SizedBox(height: AppSpacing.lg),
              DateField(
                label: 'Start date',
                value: _startDate,
                onChanged: (d) => setState(() => _startDate = d),
              ),
              const SizedBox(height: AppSpacing.lg),
              DateField(
                label: 'Due date',
                value: _dueDate,
                onChanged: (d) => setState(() => _dueDate = d),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _budget,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Budget',
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _description,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Create project'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Edit an existing task.
class EditTaskScreen extends ConsumerStatefulWidget {
  const EditTaskScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends ConsumerState<EditTaskScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  String _priority = 'medium';
  DateTime? _dueDate;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Seeds the controllers once, the first time the task resolves — doing it
  /// on every build would fight the user's typing.
  void _seed(Task task) {
    if (_loaded) return;
    _loaded = true;
    _title.text = task.title;
    _description.text = Fmt.plainText(task.description, max: 4000);
    _priority = task.priority ?? 'medium';
    _dueDate = task.endDate;
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showToast(context, 'The title cannot be empty.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(taskRepoProvider).update(widget.taskId, {
        'title': _title.text.trim(),
        'description': '<p>${_description.text.trim()}</p>',
        'priority': _priority,
        if (_dueDate != null) 'endDate': Fmt.apiDate(_dueDate!),
      });
      ref.invalidate(taskProvider(widget.taskId));
      ref.invalidate(myTasksProvider);
      if (mounted) {
        showToast(context, 'Task updated');
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
    final task = ref.watch(taskProvider(widget.taskId));

    return Scaffold(
      appBar: AppBar(title: const Text('Edit task')),
      body: AsyncView<Task>(
        value: task,
        onRetry: () => ref.invalidate(taskProvider(widget.taskId)),
        data: (t) {
          _seed(t);
          return BusyOverlay(
            busy: _saving,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              children: [
                TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  initialValue: const ['low', 'medium', 'high', 'urgent']
                          .contains(_priority)
                      ? _priority
                      : 'medium',
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                  ],
                  onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                ),
                const SizedBox(height: AppSpacing.lg),
                DateField(
                  label: 'Due date',
                  value: _dueDate,
                  onChanged: (d) => setState(() => _dueDate = d),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 10,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Save changes'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Edit an existing project.
class EditProjectScreen extends ConsumerStatefulWidget {
  const EditProjectScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<EditProjectScreen> createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends ConsumerState<EditProjectScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  String _status = 'active';
  DateTime? _dueDate;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _seed(Project project) {
    if (_loaded) return;
    _loaded = true;
    _name.text = project.name;
    _description.text = Fmt.plainText(project.description, max: 4000);
    _status = project.status ?? 'active';
    _dueDate = project.dueDate;
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showToast(context, 'The name cannot be empty.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(projectRepoProvider).update(widget.projectId, {
        'name': _name.text.trim(),
        'description': '<p>${_description.text.trim()}</p>',
        'status': _status,
        if (_dueDate != null) 'dueDate': Fmt.apiDate(_dueDate!),
      });
      ref.invalidate(projectProvider(widget.projectId));
      ref.invalidate(projectsProvider(null));
      if (mounted) {
        showToast(context, 'Project updated');
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
    final project = ref.watch(projectProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(title: const Text('Edit project')),
      body: AsyncView<Project>(
        value: project,
        onRetry: () => ref.invalidate(projectProvider(widget.projectId)),
        data: (p) {
          _seed(p);
          return BusyOverlay(
            busy: _saving,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              children: [
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  initialValue:
                      const ['active', 'on_hold', 'completed', 'archived']
                              .contains(_status)
                          ? _status
                          : 'active',
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'on_hold', child: Text('On hold')),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Completed'),
                    ),
                    DropdownMenuItem(
                      value: 'archived',
                      child: Text('Archived'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'active'),
                ),
                const SizedBox(height: AppSpacing.lg),
                DateField(
                  label: 'Due date',
                  value: _dueDate,
                  onChanged: (d) => setState(() => _dueDate = d),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 10,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Save changes'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shared date picker field.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.rMd,
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 2),
          lastDate: DateTime(now.year + 3),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
        ),
        child: Text(
          value == null ? 'Not set' : Fmt.fullDate(value),
          style: TextStyle(
            fontSize: 15,
            color: value == null
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
