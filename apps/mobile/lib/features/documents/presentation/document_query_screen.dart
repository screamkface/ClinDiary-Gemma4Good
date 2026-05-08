import 'dart:async';

import 'package:clindiary/app/providers.dart';
import 'package:clindiary/features/documents/domain/clinical_document.dart';
import 'package:clindiary/features/documents/domain/document_query_history_entry.dart';
import 'package:clindiary/features/documents/presentation/document_ui.dart';
import 'package:clindiary/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DocumentQueryScreen extends ConsumerStatefulWidget {
  const DocumentQueryScreen({
    this.initialFolderId,
    this.initialFolderName,
    super.key,
  });

  final String? initialFolderId;
  final String? initialFolderName;

  @override
  ConsumerState<DocumentQueryScreen> createState() =>
      _DocumentQueryScreenState();
}

class _DocumentQueryScreenState extends ConsumerState<DocumentQueryScreen> {
  static const _questionSuggestions = <String>[
    'Which recent tests mention creatinine or kidney function?',
    'Are there documents with out-of-range values in the last few months?',
    'Summarize the recent reports to bring to the doctor.',
  ];

  late final TextEditingController _questionController;
  final _chatScrollController = ScrollController();
  DocumentQueryResult? _result;
  bool _isSubmitting = false;
  bool _isReindexing = false;
  String? _errorMessage;
  List<_DocumentChatMessage> _messages = const <_DocumentChatMessage>[];
  Timer? _answerStreamingTimer;
  bool _chatAutoSnapEnabled = true;

  String? get _folderId => widget.initialFolderId;
  String? get _folderName => widget.initialFolderName;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController();
  }

  @override
  void dispose() {
    _answerStreamingTimer?.cancel();
    _chatScrollController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final question = _questionController.text.trim();
    FocusManager.instance.primaryFocus?.unfocus();
    if (question.length < 3) {
      setState(
        () => _errorMessage = 'Write a slightly more specific question.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _result = null;
      _questionController.clear();
      _messages = [
        ..._messages,
        _DocumentChatMessage.user(question),
        const _DocumentChatMessage.assistant('', isStreaming: true),
      ];
    });
    _scrollChatToBottom();
    var streamingStarted = false;

    try {
      final result = await ref
          .read(documentsRepositoryProvider)
          .queryDocuments(question: question, folderId: _folderId);
      if (!mounted) {
        return;
      }

      // Save to history
      final historyEntry = DocumentQueryHistoryEntry.fromQueryResult(
        question: question,
        result: result,
      );
      unawaited(
        ref
            .read(documentQueryHistoryStoreProvider)
            .appendEntry(historyEntry)
            .catchError((_) {
              // Query results should remain visible even if the local history cache is unavailable.
            }),
      );

      setState(() => _result = result);
      streamingStarted = true;
      _streamAnswer(result.answer);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _replaceLastAssistantMessage(
          'I could not read the files this time. Try again or refresh the index.',
          isStreaming: false,
        );
      });
    } finally {
      if (mounted && !streamingStarted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _streamAnswer(String answer) {
    _answerStreamingTimer?.cancel();
    var index = 0;
    final chunkSize = answer.length > 900 ? 10 : 5;
    _answerStreamingTimer = Timer.periodic(const Duration(milliseconds: 24), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      index = (index + chunkSize).clamp(0, answer.length);
      final completed = index >= answer.length;
      setState(() {
        _replaceLastAssistantMessage(
          answer.substring(0, index),
          isStreaming: !completed,
        );
        if (completed) {
          _isSubmitting = false;
        }
      });
      _scrollChatToBottom();
      if (completed) {
        timer.cancel();
      }
    });
  }

  void _replaceLastAssistantMessage(String text, {required bool isStreaming}) {
    final messages = [..._messages];
    for (var index = messages.length - 1; index >= 0; index--) {
      if (!messages[index].isUser) {
        messages[index] = _DocumentChatMessage.assistant(
          text,
          isStreaming: isStreaming,
        );
        _messages = messages;
        return;
      }
    }
    _messages = [
      ...messages,
      _DocumentChatMessage.assistant(text, isStreaming: isStreaming),
    ];
  }

  void _scrollChatToBottom() {
    if (!_chatAutoSnapEnabled) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) {
        return;
      }
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _reindex() async {
    setState(() => _isReindexing = true);
    try {
      final queued = await ref
          .read(documentsRepositoryProvider)
          .reindexDocuments();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            queued == 1
                ? 'Indexing started for 1 document.'
                : 'Indexing started for $queued documents.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isReindexing = false);
      }
    }
  }

  void _openCitation(DocumentQueryCitation citation) {
    context.push('/app/documents/${citation.documentId}');
  }

  void _openHistory() {
    context.push('/app/documents/ask/history');
  }

  String _sourceSummary(DocumentQueryResult result) {
    final files = result.retrievedDocuments == 1
        ? '1 file'
        : '${result.retrievedDocuments} files';
    final passages = result.retrievedChunks == 1
        ? '1 useful part'
        : '${result.retrievedChunks} useful parts';
    return '$files • $passages';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', 'en_US');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'View history',
            onPressed: _openHistory,
          ),
          TextButton.icon(
            onPressed: _isReindexing ? null : _reindex,
            icon: _isReindexing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_outlined),
            label: Text(_isReindexing ? 'Updating...' : 'Refresh'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DocumentChatPanel(
            messages: _messages,
            controller: _chatScrollController,
            folderName: _folderName,
            isSubmitting: _isSubmitting,
            questionController: _questionController,
            suggestions: _questionSuggestions,
            errorMessage: _errorMessage,
            onSubmit: _submit,
            onUserScroll: () {
              if (_chatAutoSnapEnabled) {
                setState(() => _chatAutoSnapEnabled = false);
              }
            },
          ),
          const SizedBox(height: 12),
          if (_result != null) ...[
            SectionCard(
              title: 'Files used',
              subtitle: _sourceSummary(_result!),
              child: Column(
                children: _result!.citations.isEmpty
                    ? const [
                        Text(
                          'No citations available. Try refreshing the index or rephrasing the question.',
                        ),
                      ]
                    : _result!.citations
                          .map(
                            (citation) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Card.outlined(
                                margin: EdgeInsets.zero,
                                child: ListTile(
                                  onTap: () => _openCitation(citation),
                                  contentPadding: const EdgeInsets.all(12),
                                  leading: CircleAvatar(
                                    child: Icon(
                                      documentIcon(
                                        documentType: citation.documentType,
                                        mimeType: 'application/pdf',
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    citation.documentTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          documentTypeLabel(
                                            citation.documentType,
                                          ),
                                          if (citation.folderName != null)
                                            citation.folderName!,
                                          if (citation.examDate != null)
                                            dateFormat.format(
                                              citation.examDate!.toLocal(),
                                            ),
                                        ].join(' • '),
                                      ),
                                      if (citation.chunkLabel != null &&
                                          citation.chunkLabel!
                                              .trim()
                                              .isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            citation.chunkLabel!,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelMedium,
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          citation.excerpt,
                                          maxLines: 5,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DocumentChatMessage {
  const _DocumentChatMessage._({
    required this.text,
    required this.isUser,
    this.isStreaming = false,
  });

  const _DocumentChatMessage.user(String text)
    : this._(text: text, isUser: true);

  const _DocumentChatMessage.assistant(String text, {bool isStreaming = false})
    : this._(text: text, isUser: false, isStreaming: isStreaming);

  final String text;
  final bool isUser;
  final bool isStreaming;
}

class _DocumentChatPanel extends StatelessWidget {
  const _DocumentChatPanel({
    required this.messages,
    required this.controller,
    required this.folderName,
    required this.isSubmitting,
    required this.questionController,
    required this.suggestions,
    required this.errorMessage,
    required this.onSubmit,
    required this.onUserScroll,
  });

  final List<_DocumentChatMessage> messages;
  final ScrollController controller;
  final String? folderName;
  final bool isSubmitting;
  final TextEditingController questionController;
  final List<String> suggestions;
  final String? errorMessage;
  final VoidCallback onSubmit;
  final VoidCallback onUserScroll;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF202544), Color(0xFF15192B)]
              : const [Color(0xFFF0F2FF), Color(0xFFEFFFF9)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.folder_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ask your files',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      folderName == null
                          ? 'Searching all your saved files.'
                          : 'Searching in $folderName.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DocumentSafetyPill(
                icon: Icons.folder_open_outlined,
                label: folderName ?? 'All files',
              ),
              const _DocumentSafetyPill(
                icon: Icons.link_outlined,
                label: 'Shows sources',
              ),
              const _DocumentSafetyPill(
                icon: Icons.health_and_safety_outlined,
                label: 'No diagnosis',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 320,
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(
                alpha: isDark ? 0.62 : 0.78,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: NotificationListener<UserScrollNotification>(
              onNotification: (notification) {
                if (notification.direction != ScrollDirection.idle) {
                  onUserScroll();
                }
                return false;
              },
              child: messages.isEmpty
                  ? const _DocumentChatWelcome()
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) =>
                          _DocumentChatBubble(message: messages[index]),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: suggestions
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(item),
                        onPressed: isSubmitting
                            ? null
                            : () => questionController.text = item,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(errorMessage!, style: TextStyle(color: colorScheme.error)),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: questionController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Ask about your files',
                    hintText: 'Example: what should I bring to the doctor?',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: isSubmitting ? null : onSubmit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DocumentChatWelcome extends StatelessWidget {
  const _DocumentChatWelcome();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(Icons.search_rounded, color: colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Text(
              'Ask one simple question.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'I will answer only from files I can cite back to you.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentChatBubble extends StatelessWidget {
  const _DocumentChatBubble({required this.message});

  final _DocumentChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final bubbleColor = isUser
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.72);
    final foreground = isUser ? colorScheme.onPrimary : colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isUser ? 20 : 6),
              bottomRight: Radius.circular(isUser ? 6 : 20),
            ),
          ),
          child: message.isStreaming && message.text.isEmpty
              ? const _DocumentTypingDots()
              : SelectableText(
                  message.isStreaming ? '${message.text}|' : message.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    height: 1.42,
                  ),
                ),
        ),
      ),
    );
  }
}

class _DocumentTypingDots extends StatefulWidget {
  const _DocumentTypingDots();

  @override
  State<_DocumentTypingDots> createState() => _DocumentTypingDotsState();
}

class _DocumentTypingDotsState extends State<_DocumentTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final active = (_controller.value * 3).floor();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final isActive = index == active;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: isActive ? 8 : 6,
              height: isActive ? 8 : 6,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: isActive ? 0.9 : 0.35),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

class _DocumentSafetyPill extends StatelessWidget {
  const _DocumentSafetyPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
