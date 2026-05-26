import 'package:flutter/material.dart';

import '../models/course.dart';
import '../services/api_service.dart';
import '../utils/ui_utils.dart';

class ModuleQuizScreen extends StatefulWidget {
  const ModuleQuizScreen({
    super.key,
    required this.course,
    required this.module,
    required this.initialState,
    required this.shouldStoreResult,
  });

  final Course course;
  final CourseModule module;
  final Map<String, dynamic> initialState;
  final bool shouldStoreResult;

  @override
  State<ModuleQuizScreen> createState() => _ModuleQuizScreenState();
}

class _ModuleQuizScreenState extends State<ModuleQuizScreen> {
  final Map<int, String> _answers = <int, String>{};
  List<CourseQuizQuestion> _questions = const [];
  int _index = 0;
  int _score = 0;
  bool _submitted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startAttempt();
  }

  int get _attempts => (widget.initialState['attempts'] as num?)?.toInt() ?? 0;
  int get _failedAttempts =>
      (widget.initialState['failed_attempts'] as num?)?.toInt() ?? 0;
  int get _bestScore =>
      (widget.initialState['best_score'] as num?)?.toInt() ?? 0;
  bool get _locked =>
      widget.initialState['locked'] == true ||
      widget.initialState['rewatch_required'] == true;

  int get _passScore {
    final configured = widget.course.quizPassScore;
    return configured > 0 ? configured : 3;
  }

  bool get _isLastQuestion => _index >= _questions.length - 1;
  bool get _hasAnsweredCurrent => _answers[_index] != null;

  void _startAttempt() {
    final all = widget.module.quizQuestions
        .where((q) => q.question.trim().isNotEmpty)
        .toList(growable: true);
    all.shuffle();
    setState(() {
      _questions = all.take(5).toList(growable: false);
      _answers.clear();
      _index = 0;
      _score = 0;
      _submitted = false;
    });
  }

  Future<void> _submit() async {
    if (_questions.isEmpty) return;
    var score = 0;
    for (var i = 0; i < _questions.length; i++) {
      if ((_answers[i] ?? '').toUpperCase() ==
          _questions[i].correctAnswer.toUpperCase()) {
        score += 1;
      }
    }

    setState(() {
      _score = score;
      _submitted = true;
    });

    if (!widget.shouldStoreResult) return;

    setState(() => _saving = true);
    try {
      final result = await ApiService.instance.completeQuiz(
        courseId: widget.course.id,
        score: score,
        total: _questions.length,
        passScore: _passScore,
        moduleId: widget.module.id,
        moduleOrder: widget.module.orderIndex,
        moduleTitle: widget.module.title,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      showTopNotification(context, 'Failed to store quiz marks: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canAttempt = widget.module.quizQuestions.length >= 10 && !_locked;
    final progress = _questions.isEmpty
        ? 0.0
        : (_index + 1) / _questions.length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Module Quiz'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _StatusPill(
                icon: Icons.workspace_premium_outlined,
                label: 'Best $_bestScore',
                color: scheme.secondary,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _QuizHero(
              module: widget.module,
              questionCount: widget.module.quizQuestions.length,
              passScore: _passScore,
              attempts: _attempts,
              failedAttempts: _failedAttempts,
            ),
            const SizedBox(height: 16),
            if (widget.module.quizQuestions.length < 10)
              const _NoticeCard(
                icon: Icons.pending_actions_rounded,
                title: 'Quiz is being prepared',
                text:
                    'The mentor needs to add at least 10 questions before students can attempt this module quiz.',
              )
            else if (_locked)
              const _NoticeCard(
                icon: Icons.lock_outline_rounded,
                title: 'Retake locked',
                text:
                    'You have reached 3 failed attempts. Rewatch this module lesson to unlock another try.',
                isError: true,
              )
            else if (canAttempt)
              _submitted
                  ? _ResultCard(
                      score: _score,
                      total: _questions.length,
                      passScore: _passScore,
                      questions: _questions,
                      answers: _answers,
                      onRetry: _saving ? null : _startAttempt,
                      saving: _saving,
                    )
                  : _QuestionPanel(
                      question: _questions[_index],
                      index: _index,
                      total: _questions.length,
                      progress: progress,
                      selected: _answers[_index],
                      answeredCount: _answers.length,
                      onSelect: (value) =>
                          setState(() => _answers[_index] = value),
                      onPrevious: _index > 0
                          ? () => setState(() => _index -= 1)
                          : null,
                      onNext: !_isLastQuestion && _hasAnsweredCurrent
                          ? () => setState(() => _index += 1)
                          : null,
                      onSubmit: _isLastQuestion && _hasAnsweredCurrent
                          ? _submit
                          : null,
                      saving: _saving,
                    ),
          ],
        ),
      ),
    );
  }
}

class _QuizHero extends StatelessWidget {
  const _QuizHero({
    required this.module,
    required this.questionCount,
    required this.passScore,
    required this.attempts,
    required this.failedAttempts,
  });

  final CourseModule module;
  final int questionCount;
  final int passScore;
  final int attempts;
  final int failedAttempts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withAlpha(45),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.quiz_rounded, color: scheme.onPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Module ${module.orderIndex}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onPrimary.withAlpha(210),
                      ),
                    ),
                    Text(
                      module.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                icon: Icons.shuffle_rounded,
                label: '5 random',
                color: scheme.onPrimary,
                onColor: scheme.primary,
              ),
              _StatusPill(
                icon: Icons.check_circle_outline_rounded,
                label: 'Pass $passScore/5',
                color: scheme.onPrimary,
                onColor: scheme.primary,
              ),
              _StatusPill(
                icon: Icons.library_books_outlined,
                label: '$questionCount questions',
                color: scheme.onPrimary,
                onColor: scheme.primary,
              ),
              _StatusPill(
                icon: Icons.refresh_rounded,
                label: '$attempts attempts',
                color: scheme.onPrimary,
                onColor: scheme.primary,
              ),
              _StatusPill(
                icon: Icons.error_outline_rounded,
                label: '$failedAttempts/3 failed',
                color: scheme.onPrimary,
                onColor: scheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({
    required this.question,
    required this.index,
    required this.total,
    required this.progress,
    required this.selected,
    required this.answeredCount,
    required this.onSelect,
    required this.onPrevious,
    required this.onNext,
    required this.onSubmit,
    required this.saving,
  });

  final CourseQuizQuestion question;
  final int index;
  final int total;
  final double progress;
  final String? selected;
  final int answeredCount;
  final ValueChanged<String> onSelect;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onSubmit;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final options = [
      ('A', question.optionA),
      ('B', question.optionB),
      ('C', question.optionC),
      ('D', question.optionD),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Question ${index + 1} of $total',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text('$answeredCount answered', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: scheme.primary.withAlpha(24),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            question.question,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          ...options.map((option) {
            final isSelected = selected == option.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OptionTile(
                letter: option.$1,
                text: option.$2,
                selected: isSelected,
                onTap: saving ? null : () => onSelect(option.$1),
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: saving ? null : onPrevious,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Previous'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: saving ? null : (onNext ?? onSubmit),
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          onNext == null
                              ? Icons.done_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                  label: Text(onNext == null ? 'Submit Quiz' : 'Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected ? scheme.primary : scheme.outline;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withAlpha(18) : scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(selected ? 160 : 70)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                letter,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected
                      ? scheme.onPrimary
                      : scheme.onSurface.withAlpha(190),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.score,
    required this.total,
    required this.passScore,
    required this.questions,
    required this.answers,
    required this.onRetry,
    required this.saving,
  });

  final int score;
  final int total;
  final int passScore;
  final List<CourseQuizQuestion> questions;
  final Map<int, String> answers;
  final VoidCallback? onRetry;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final passed = score >= passScore;
    final accent = passed ? const Color(0xFF10B981) : scheme.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withAlpha(22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  passed
                      ? Icons.emoji_events_outlined
                      : Icons.replay_circle_filled_outlined,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passed ? 'Module quiz passed' : 'Try again',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Score $score/$total. Passing score is $passScore/$total.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : score / total,
              minHeight: 9,
              backgroundColor: accent.withAlpha(24),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 16),
          ...questions.asMap().entries.map((entry) {
            final idx = entry.key;
            final question = entry.value;
            final chosen = answers[idx] ?? '-';
            final correct =
                chosen.toUpperCase() == question.correctAnswer.toUpperCase();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 20,
                    color: correct ? const Color(0xFF10B981) : scheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Q${idx + 1}: correct ${question.correctAnswer}, your answer $chosen',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: const Text('Start another attempt'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
    this.onColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final foreground = onColor ?? color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(onColor == null ? 20 : 230),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.text,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = isError ? scheme.error : scheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(text, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
