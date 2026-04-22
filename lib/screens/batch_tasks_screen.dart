import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/task.dart';
import '../models/task_submission.dart';
import '../services/api_service.dart';

class BatchTasksScreen extends StatefulWidget {
  const BatchTasksScreen({
    super.key,
    required this.batchId,
    required this.batchName,
    this.canCreate = false,
    this.canReview = false,
    this.canSubmit = false,
  });

  final String batchId;
  final String batchName;
  final bool canCreate;
  final bool canReview;
  final bool canSubmit;

  @override
  State<BatchTasksScreen> createState() => _BatchTasksScreenState();
}

class _BatchTasksScreenState extends State<BatchTasksScreen> {
  bool _loading = true;
  List<BatchTask> _tasks = const [];
  final Set<String> _openingTaskIds = <String>{};
  final Set<String> _markingDoneTaskIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tasks = await ApiService.instance.getBatchTasks(widget.batchId);
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load tasks: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openTaskEditor({BatchTask? existing}) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final description = TextEditingController(text: existing?.description ?? '');
    final fileUrl = TextEditingController(text: existing?.fileUrl ?? '');
    final driveLink = TextEditingController(text: existing?.driveLink ?? '');
    DateTime? deadline;
    if (existing?.deadline != null) {
      final d = existing!.deadline!;
      deadline = DateTime(d.year, d.month, d.day, 23, 59, 59);
    }
    bool saving = false;
    final messenger = ScaffoldMessenger.of(context);

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
            Future<void> save() async {
              final t = title.text.trim();
              if (t.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Title is required')),
                );
                return;
              }

              setDialogState(() => saving = true);
              var closedDialog = false;
              try {
                if (existing == null) {
                  await ApiService.instance.createTask(
                    batchId: widget.batchId,
                    title: t,
                    description: description.text.trim(),
                    fileUrl: fileUrl.text.trim().isEmpty ? null : fileUrl.text.trim(),
                    driveLink: driveLink.text.trim().isEmpty ? null : driveLink.text.trim(),
                    deadline: deadline,
                  );
                } else {
                  await ApiService.instance.updateTask(
                    taskId: existing.id,
                    batchId: widget.batchId,
                    title: t,
                    description: description.text.trim(),
                    fileUrl: fileUrl.text.trim().isEmpty ? null : fileUrl.text.trim(),
                    driveLink: driveLink.text.trim().isEmpty ? null : driveLink.text.trim(),
                    deadline: deadline,
                  );
                }
                if (!mounted) return;
                closedDialog = true;
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
                await _load();
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to save task: $e')),
                );
              } finally {
                if (mounted && !closedDialog && dialogContext.mounted) {
                  try {
                    setDialogState(() => saving = false);
                  } catch (_) {}
                }
              }
            }

            return AlertDialog(
              title: Text(existing == null ? 'Create Task' : 'Edit Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: description,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: 'Description / Question'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: fileUrl,
                      decoration: const InputDecoration(labelText: 'File URL (optional)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: driveLink,
                      decoration: const InputDecoration(labelText: 'Submission Drive Link (optional)'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: dialogContext,
                                initialDate: DateTime.now().add(const Duration(days: 1)),
                                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                lastDate: DateTime.now().add(const Duration(days: 3650)),
                              );
                              if (picked == null) return;
                              setDialogState(() {
                                deadline = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
                              });
                            },
                            icon: const Icon(Icons.event_outlined),
                            label: Text(
                              deadline == null
                                  ? 'Deadline'
                                  : '${deadline!.day}/${deadline!.month}/${deadline!.year}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(existing == null ? 'Create' : 'Save'),
                ),
              ],
            );
            },
          );
        },
      );
    } finally {
      title.dispose();
      description.dispose();
      fileUrl.dispose();
      driveLink.dispose();
    }
  }

  Future<void> _openMentorSubmissionLink(BatchTask task) async {
    final messenger = ScaffoldMessenger.of(context);
    final raw = (task.driveLink ?? '').trim();
    final uri = Uri.tryParse(raw);
    final valid = raw.isNotEmpty && uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    if (!valid) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Submission link not available. Contact mentor.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _openingTaskIds.add(task.id));

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!opened) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Unable to open submission link.')),
        );
        return;
      }

      // Optional enhancement: mark that student attempted/opened submission link.
      try {
        await ApiService.instance.submitTask(
          taskId: task.id,
          driveLink: raw,
          fileType: 'link',
          markDone: false,
        );
      } catch (_) {
        // Best effort only.
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('Submission link opened.')),
      );
      await _load();
    } finally {
      if (mounted) {
        setState(() => _openingTaskIds.remove(task.id));
      }
    }
  }

  Future<void> _markTaskDone(BatchTask task) async {
    final messenger = ScaffoldMessenger.of(context);
    final raw = (task.driveLink ?? '').trim();
    if (!mounted) return;
    setState(() => _markingDoneTaskIds.add(task.id));

    try {
      await ApiService.instance.submitTask(
        taskId: task.id,
        driveLink: raw.isEmpty ? null : raw,
        fileType: 'link',
        markDone: true,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Marked as done.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to mark done: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _markingDoneTaskIds.remove(task.id));
      }
    }
  }

  Future<void> _openSubmissions(BatchTask task) async {
    List<TaskSubmission> submissions = const [];
    bool loading = true;
    final messenger = ScaffoldMessenger.of(context);

    try {
      submissions = await ApiService.instance.getTaskSubmissions(task.id);
    } catch (_) {
      submissions = const [];
    } finally {
      loading = false;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        Future<void> fetch(StateSetter setState) async {
          if (!sheetContext.mounted) return;
          setState(() => loading = true);
          try {
            submissions = await ApiService.instance.getTaskSubmissions(task.id);
          } catch (_) {
            submissions = const [];
          } finally {
            if (sheetContext.mounted) {
              setState(() => loading = false);
            }
          }
        }

        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> review(TaskSubmission submission, String nextStatus) async {
              final feedback = TextEditingController(text: submission.feedback ?? '');
              await showDialog<void>(
                context: sheetContext,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: Text('${nextStatus == 'validated' ? 'Validate' : 'Reject'} Submission'),
                    content: TextField(
                      controller: feedback,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Feedback'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          try {
                            await ApiService.instance.reviewSubmission(
                              submissionId: submission.id,
                              status: nextStatus,
                              feedback: feedback.text.trim().isEmpty ? null : feedback.text.trim(),
                            );
                            if (!sheetContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            await fetch(setState);
                          } catch (e) {
                            if (!sheetContext.mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text('Review failed: $e')),
                            );
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  );
                },
              );
              feedback.dispose();
            }

            return SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.8,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('Submissions', style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF6B7280))),
                    const SizedBox(height: 12),
                    if (loading)
                      const Expanded(child: Center(child: CircularProgressIndicator()))
                    else if (submissions.isEmpty)
                      Expanded(
                        child: Center(
                          child: Text('No submissions yet', style: GoogleFonts.poppins()),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: submissions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final s = submissions[index];
                            final statusColor = s.status == 'validated'
                                ? const Color(0xFF16A34A)
                                : s.status == 'rejected'
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFFD97706);
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          s.studentName ?? 'Student',
                                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          s.status.toUpperCase(),
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Submitted: ${s.submittedAt.toLocal()}',
                                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF6B7280)),
                                  ),
                                  if (s.studentDone) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Student marked done${s.doneAt != null ? ' at ${s.doneAt!.toLocal()}' : ''}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: const Color(0xFF166534),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  if (s.fileUrl != null && s.fileUrl!.isNotEmpty)
                                    Text(
                                      'File: ${_friendlyFileName(s.fileUrl!)} (${s.fileType ?? 'file'})',
                                      style: GoogleFonts.poppins(fontSize: 11),
                                    ),
                                  if (s.driveLink != null && s.driveLink!.isNotEmpty)
                                    Text(
                                      'Drive: ${s.driveLink}',
                                      style: GoogleFonts.poppins(fontSize: 11),
                                    ),
                                  if (s.fileUrl != null && s.fileUrl!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    _InlineResourceActions(value: s.fileUrl!, label: 'File'),
                                  ],
                                  if (s.driveLink != null && s.driveLink!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    _InlineResourceActions(value: s.driveLink!, label: 'Drive'),
                                  ],
                                  if (s.feedback != null && s.feedback!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Feedback: ${s.feedback}',
                                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF374151)),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => review(s, 'validated'),
                                        icon: const Icon(Icons.check_circle_outline, size: 16),
                                        label: const Text('Validate'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: () => review(s, 'rejected'),
                                        icon: const Icon(Icons.cancel_outlined, size: 16),
                                        label: const Text('Reject'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'validated':
        return const Color(0xFF16A34A);
      case 'rejected':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFD97706);
    }
  }

  String _friendlyFileName(String path) {
    final cleaned = path.trim();
    if (cleaned.isEmpty) return 'attachment';
    final uri = Uri.tryParse(cleaned);
    final segments = uri?.pathSegments ?? const <String>[];
    if (segments.isNotEmpty) return segments.last;
    final slash = cleaned.lastIndexOf('/');
    final backslash = cleaned.lastIndexOf('\\');
    final idx = slash > backslash ? slash : backslash;
    if (idx >= 0 && idx + 1 < cleaned.length) return cleaned.substring(idx + 1);
    return cleaned;
  }

  Future<void> _openBatchAnnouncement() async {
    final title = TextEditingController();
    final message = TextEditingController();
    bool sending = false;
    final messenger = ScaffoldMessenger.of(context);

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> send() async {
                final msg = message.text.trim();
                if (msg.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Announcement message is required.')),
                  );
                  return;
                }

                setDialogState(() => sending = true);
                var closed = false;
                try {
                  await ApiService.instance.sendBatchAnnouncement(
                    batchId: widget.batchId,
                    title: title.text.trim().isEmpty ? 'Batch Announcement' : title.text.trim(),
                    message: msg,
                  );
                  if (!mounted) return;
                  closed = true;
                  if (Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop();
                  }
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Batch announcement sent.')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to send announcement: $e')),
                  );
                } finally {
                  if (mounted && !closed && dialogContext.mounted) {
                    try {
                      setDialogState(() => sending = false);
                    } catch (_) {}
                  }
                }
              }

              return AlertDialog(
                title: const Text('Batch Announcement'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: title,
                        decoration: const InputDecoration(labelText: 'Title (optional)'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: message,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(labelText: 'Message'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: sending ? null : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: sending ? null : send,
                    child: sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      title.dispose();
      message.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.batchName} To-Do'),
        actions: [
          if (widget.canCreate)
            IconButton(
              tooltip: 'Announce to Batch Students',
              onPressed: _openBatchAnnouncement,
              icon: const Icon(Icons.campaign_outlined),
            ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: widget.canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _openTaskEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Create Task'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? Center(
                  child: Text(
                    'No tasks yet',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      final statusColor = _statusColor(task.mySubmissionStatus);
                      final status = task.mySubmissionStatus ?? 'pending';
                      final rawDrive = (task.driveLink ?? '').trim();
                      final driveUri = Uri.tryParse(rawDrive);
                      final hasValidDriveLink =
                          rawDrive.isNotEmpty &&
                          driveUri != null &&
                          (driveUri.scheme == 'http' || driveUri.scheme == 'https');
                      final opening = _openingTaskIds.contains(task.id);
                        final markingDone = _markingDoneTaskIds.contains(task.id);
                        final hasAttemptedSubmission =
                          task.mySubmissionSubmittedAt != null ||
                          (task.mySubmissionDriveLink != null && task.mySubmissionDriveLink!.isNotEmpty);
                        final isMarkedDone = task.mySubmissionStudentDone ?? false;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    task.title,
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (widget.canReview)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDBEAFE),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${task.submissionCount} submitted / ${task.attemptCount} attempts',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  )
                                else if (widget.canSubmit)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                if (widget.canCreate && !widget.canSubmit) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => _openTaskEditor(existing: task),
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    tooltip: 'Edit Task',
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(task.description, style: GoogleFonts.poppins(fontSize: 12)),
                            const SizedBox(height: 8),
                            if (task.deadline != null)
                              Text(
                                'Deadline: ${task.deadline!.day}/${task.deadline!.month}/${task.deadline!.year}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: task.isOverdue
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF6B7280),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (task.fileUrl != null && task.fileUrl!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Attachment: ${_friendlyFileName(task.fileUrl!)}',
                                style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF374151)),
                              ),
                              const SizedBox(height: 4),
                              _InlineResourceActions(value: task.fileUrl!, label: 'Attachment'),
                            ],
                            if (task.driveLink != null && task.driveLink!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Submission Link: ${task.driveLink}',
                                style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF374151)),
                              ),
                              const SizedBox(height: 4),
                              _InlineResourceActions(value: task.driveLink!, label: 'Submission Link'),
                            ],
                            if (task.mySubmissionFeedback != null && task.mySubmissionFeedback!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Feedback: ${task.mySubmissionFeedback}',
                                style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF047857)),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (widget.canSubmit)
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: (!hasValidDriveLink || opening)
                                          ? null
                                          : () => _openMentorSubmissionLink(task),
                                      icon: opening
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.open_in_new_rounded),
                                      label: Text(
                                        opening
                                            ? 'Opening...'
                                            : (hasValidDriveLink ? 'Submit' : 'Submit Unavailable'),
                                      ),
                                    ),
                                  ),
                                if (widget.canSubmit) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: (!hasAttemptedSubmission || isMarkedDone || markingDone)
                                          ? null
                                          : () => _markTaskDone(task),
                                      icon: markingDone
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.check_circle_outline, size: 18),
                                      label: Text(
                                        isMarkedDone
                                            ? 'Done'
                                            : (markingDone ? 'Saving...' : 'Mark as Done'),
                                      ),
                                    ),
                                  ),
                                ],
                                if (widget.canReview) ...[
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _openSubmissions(task),
                                      icon: const Icon(Icons.fact_check_outlined),
                                      label: const Text('View Submissions'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (widget.canSubmit && !hasAttemptedSubmission) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Open submission link first, then mark as done after uploading.',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            if (widget.canSubmit && !hasValidDriveLink) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Submission link not available. Contact mentor.',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFFB91C1C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _InlineResourceActions extends StatelessWidget {
  const _InlineResourceActions({required this.value, required this.label});

  final String value;
  final String label;

  bool get _isHttp {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label copied')),
            );
          },
          icon: const Icon(Icons.copy_outlined, size: 16),
          label: const Text('Copy'),
        ),
        if (_isHttp)
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('URL copied. Open it in browser.')),
              );
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open'),
          ),
      ],
    );
  }
}
