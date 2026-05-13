import 'dart:async';

import 'package:flutter/material.dart';

class GenerationPhaseLabel extends StatefulWidget {
  const GenerationPhaseLabel({
    required this.isActive,
    required this.idleLabel,
    this.startedAt,
    this.thinkingLabel = 'Thinking...',
    this.writingLabel = 'Writing...',
    this.refiningLabel = 'Refining...',
    this.showProgress = false,
    this.style,
    super.key,
  });

  final bool isActive;
  final DateTime? startedAt;
  final String idleLabel;
  final String thinkingLabel;
  final String writingLabel;
  final String refiningLabel;
  final bool showProgress;
  final TextStyle? style;

  @override
  State<GenerationPhaseLabel> createState() => _GenerationPhaseLabelState();
}

class _GenerationPhaseLabelState extends State<GenerationPhaseLabel> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _resetElapsed();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant GenerationPhaseLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive ||
        oldWidget.startedAt != widget.startedAt) {
      _resetElapsed();
    }
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    if (widget.isActive) {
      _timer ??= Timer.periodic(const Duration(milliseconds: 350), (_) {
        if (mounted) {
          _elapsed += const Duration(milliseconds: 350);
          setState(() {});
        }
      });
      return;
    }

    _timer?.cancel();
    _timer = null;
  }

  void _resetElapsed() {
    final startedAt = widget.startedAt;
    if (startedAt == null) {
      _elapsed = Duration.zero;
      return;
    }

    final calculatedElapsed = DateTime.now().difference(startedAt);
    _elapsed = calculatedElapsed.isNegative ? Duration.zero : calculatedElapsed;
  }

  String get _label {
    if (!widget.isActive) {
      return widget.idleLabel;
    }

    final phaseLabel = _phaseLabel;
    if (!widget.showProgress) {
      return phaseLabel;
    }

    return '$phaseLabel ${_progressPercent.toString()}%';
  }

  String get _phaseLabel {
    if (widget.startedAt == null) {
      return widget.thinkingLabel;
    }

    if (_elapsed < const Duration(seconds: 2)) {
      return widget.thinkingLabel;
    }
    if (_elapsed < const Duration(seconds: 5)) {
      return widget.writingLabel;
    }
    return widget.refiningLabel;
  }

  int get _progressPercent {
    final elapsedMs = _elapsed.inMilliseconds;

    if (elapsedMs <= 0) {
      return 5;
    }

    if (elapsedMs < 2000) {
      final phaseProgress = elapsedMs / 2000;
      return (5 + (phaseProgress * 40)).round().clamp(5, 45);
    }

    if (elapsedMs < 5000) {
      final phaseProgress = (elapsedMs - 2000) / 3000;
      return (45 + (phaseProgress * 40)).round().clamp(45, 85);
    }

    final tailProgress = ((elapsedMs - 5000) / 10000).clamp(0.0, 1.0);
    return (85 + (tailProgress * 14)).round().clamp(85, 99);
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = widget.style ?? DefaultTextStyle.of(context).style;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Text(
        _label,
        key: ValueKey<String>(_label),
        style: labelStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
