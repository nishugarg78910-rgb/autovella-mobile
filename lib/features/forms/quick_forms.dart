import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/states.dart';
import '../../data/repository.dart';
import '../../models/work.dart';
import '../psa/psa_providers.dart';
import '../work/work_providers.dart';
import 'edit_forms.dart' show DateField;

/// Create a task.
///
/// Kept to the fields someone can sensibly fill on a phone: what, where, when
/// and how urgent. Everything else (dependencies, custom fields, estimates)
/// is left to the detail screen or the web app rather than making a phone
/// form that nobody finishes.
class NewTaskScreen extends ConsumerStatefulWidget {
  const NewTaskScreen({super.key, this.projectId});

  final String? projectId;

  @override
  ConsumerState<NewTaskScreen> createState() => _NewTaskScreenState();
}

class _NewTaskScreenState extends ConsumerState<NewTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  String? _projectId;
  String _priority = 'medium';
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _projectId = widget.projectId;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_projectId == null) {
      showToast(context, 'Pick a project for this task.', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(taskRepoProvider).create({
        'title': _title.text.trim(),
        'projectId': _projectId,
        if (_description.text.trim().isNotEmpty)
          'description': '<p>${_description.text.trim()}</p>',
        'priority': _priority,
        'status': 'todo',
        if (_dueDate != null) 'endDate': Fmt.apiDate(_dueDate!),
      });
      ref.invalidate(myTasksProvider);
      if (_projectId != null) {
        ref.invalidate(projectTasksProvider(_projectId!));
      }
      if (mounted) {
        showToast(context, 'Task created');
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
    final projects = ref.watch(projectsProvider(null));

    return Scaffold(
      appBar: AppBar(title: const Text('New task')),
      body: BusyOverlay(
        busy: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: [
              TextFormField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'What needs doing?',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Give the task a title' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              projects.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Could not load projects.'),
                data: (items) => DropdownButtonFormField<String>(
                  initialValue: _projectId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Project'),
                  items: [
                    for (final p in items)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _projectId = v),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: _priority,
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
                child: const Text('Create task'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Log time against a project or task.
class NewTimesheetScreen extends ConsumerStatefulWidget {
  const NewTimesheetScreen({super.key});

  @override
  ConsumerState<NewTimesheetScreen> createState() => _NewTimesheetScreenState();
}

class _NewTimesheetScreenState extends ConsumerState<NewTimesheetScreen> {
  final _hours = TextEditingController();
  final _notes = TextEditingController();
  String? _projectId;
  String? _taskId;
  DateTime _date = DateTime.now();
  bool _billable = true;
  bool _saving = false;

  @override
  void dispose() {
    _hours.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final hours = double.tryParse(_hours.text.trim());
    if (hours == null || hours <= 0) {
      showToast(context, 'Enter how many hours you worked.', isError: true);
      return;
    }
    if (_projectId == null) {
      showToast(context, 'Pick a project.', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(timesheetRepoProvider).create({
        'projectId': _projectId,
        if (_taskId != null) 'taskId': _taskId,
        'hours': hours,
        'date': Fmt.apiDate(_date),
        'isBillable': _billable,
        if (_notes.text.trim().isNotEmpty) 'description': _notes.text.trim(),
      });
      ref.invalidate(timesheetsProvider);
      if (mounted) {
        showToast(context, 'Time logged');
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
    final projects = ref.watch(projectsProvider(null));
    final tasks = _projectId == null
        ? null
        : ref.watch(projectTasksProvider(_projectId!));

    return Scaffold(
      appBar: AppBar(title: const Text('Log time')),
      body: BusyOverlay(
        busy: _saving,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            TextField(
              controller: _hours,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Hours',
                hintText: '7.5',
                suffixText: 'h',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            DateField(
              label: 'Date',
              value: _date,
              onChanged: (d) => setState(() => _date = d ?? _date),
            ),
            const SizedBox(height: AppSpacing.lg),
            projects.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Could not load projects.'),
              data: (items) => DropdownButtonFormField<String>(
                initialValue: _projectId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Project'),
                items: [
                  for (final p in items)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _projectId = v;
                  // Task list belongs to the project, so clear a stale pick.
                  _taskId = null;
                }),
              ),
            ),
            if (tasks != null) ...[
              const SizedBox(height: AppSpacing.lg),
              tasks.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (items) => items.isEmpty
                    ? const SizedBox.shrink()
                    : DropdownButtonFormField<String>(
                        initialValue: _taskId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Task (optional)',
                        ),
                        items: [
                          for (final Task t in items)
                            DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                t.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _taskId = v),
                      ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              value: _billable,
              onChanged: (v) => setState(() => _billable = v),
              title: const Text('Billable'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What did you work on?',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Log time'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Request leave.
class NewTimeOffScreen extends ConsumerStatefulWidget {
  const NewTimeOffScreen({super.key});

  @override
  ConsumerState<NewTimeOffScreen> createState() => _NewTimeOffScreenState();
}

class _NewTimeOffScreenState extends ConsumerState<NewTimeOffScreen> {
  final _reason = TextEditingController();
  String _type = 'Annual leave';
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  bool _saving = false;

  static const _types = [
    'Annual leave',
    'Sick leave',
    'Casual leave',
    'Unpaid leave',
    'Work from home',
  ];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  int get _days => _end.difference(_start).inDays + 1;

  Future<void> _save() async {
    if (_end.isBefore(_start)) {
      showToast(context, 'The end date cannot be before the start.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(timeOffRepoProvider).create({
        'type': _type,
        'startDate': Fmt.apiDate(_start),
        'endDate': Fmt.apiDate(_end),
        'days': _days,
        if (_reason.text.trim().isNotEmpty) 'reason': _reason.text.trim(),
      });
      ref.invalidate(myTimeOffProvider);
      if (mounted) {
        showToast(context, 'Leave requested');
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
      appBar: AppBar(title: const Text('Request time off')),
      body: BusyOverlay(
        busy: _saving,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final t in _types)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: AppSpacing.lg),
            DateField(
              label: 'From',
              value: _start,
              onChanged: (d) => setState(() {
                _start = d ?? _start;
                // Keep the range valid as the user moves the start date.
                if (_end.isBefore(_start)) _end = _start;
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            DateField(
              label: 'To',
              value: _end,
              onChanged: (d) => setState(() => _end = d ?? _end),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '$_days ${_days == 1 ? 'day' : 'days'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _reason,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Submit request'),
            ),
          ],
        ),
      ),
    );
  }
}
