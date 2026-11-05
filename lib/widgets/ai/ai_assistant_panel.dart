import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/ai_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AiAssistantPanel
//
// The full right-side AI chat panel.  Designed to be inserted as a fixed-width
// column inside AppLayout's main Row, beside the content column.
//
// Responsibilities:
//   • Render the conversation history (user right, AI left).
//   • Show suggested questions when the conversation is empty.
//   • Send messages to AiService and display responses.
//   • Show a loading indicator while the AI is processing.
//   • Show an error state with a Retry button on failure.
//   • Fully support light and dark mode via AppTheme / AppColors.
//   • Scroll the chat list to the latest message automatically.
//
// Width is driven externally (AiPanelLayout in app_layout.dart) so this widget
// is always Expanded / fixed-width — it never decides its own width.
// ─────────────────────────────────────────────────────────────────────────────

class AiAssistantPanel extends StatefulWidget {
  /// The route that is currently active — passed to AiService for context.
  final String currentRoute;

  /// Called when the user taps the close (×) button.
  final VoidCallback onClose;

  const AiAssistantPanel({
    super.key,
    required this.currentRoute,
    required this.onClose,
  });

  @override
  State<AiAssistantPanel> createState() => _AiAssistantPanelState();
}

class _AiAssistantPanelState extends State<AiAssistantPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  final List<AiMessage> _messages = [];
  bool _isLoading = false;
  String? _lastFailedQuestion; // stored for Retry

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ── Send a message ────────────────────────────────────────────────────────

  Future<void> _send(String question) async {
    final q = question.trim();
    if (q.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(AiMessage(role: AiMessageRole.user, text: q));
      _isLoading = true;
      _lastFailedQuestion = null;
    });
    _inputController.clear();
    _scrollToBottom();

    final response = await AiService.query(
      question: q,
      currentRoute: widget.currentRoute,
    );

    if (!mounted) return;

    if (response.status == AiResponseStatus.ok) {
      setState(() {
        _messages.add(AiMessage(role: AiMessageRole.assistant, text: response.text));
        _isLoading = false;
      });
    } else {
      setState(() {
        _lastFailedQuestion = q;
        _isLoading = false;
        _messages.add(AiMessage(
          role: AiMessageRole.assistant,
          text: response.text,
        ));
      });
    }

    _scrollToBottom();
    _inputFocus.requestFocus();
  }

  Future<void> _retry() async {
    if (_lastFailedQuestion == null) return;
    // Remove the last error message bubble before retrying
    if (_messages.isNotEmpty &&
        _messages.last.role == AiMessageRole.assistant) {
      setState(() => _messages.removeLast());
    }
    await _send(_lastFailedQuestion!);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppConstants.animNormal,
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark     = brightness == Brightness.dark;

    // Panel background: slightly elevated from page bg, matching topbar tone.
    final panelBg = isDark
        ? const Color(0xFF1C1A27)
        : AppColors.surface;
    final borderCol = AppTheme.border(brightness);

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        border: Border(
          left: BorderSide(color: borderCol, width: 1),
        ),
      ),
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          _PanelHeader(onClose: widget.onClose, brightness: brightness),

          // ── Chat area ─────────────────────────────────────────────────────
          Expanded(
            child: _messages.isEmpty && !_isLoading
                ? _SuggestionsView(
                    currentRoute: widget.currentRoute,
                    onSuggest: _send,
                    brightness: brightness,
                  )
                : _ChatList(
                    messages: _messages,
                    isLoading: _isLoading,
                    lastFailedQuestion: _lastFailedQuestion,
                    onRetry: _retry,
                    scrollController: _scrollController,
                    brightness: brightness,
                  ),
          ),

          // ── Input area ────────────────────────────────────────────────────
          _InputArea(
            controller: _inputController,
            focusNode: _inputFocus,
            isLoading: _isLoading,
            onSend: _send,
            brightness: brightness,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel header
// ─────────────────────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final VoidCallback onClose;
  final Brightness brightness;

  const _PanelHeader({required this.onClose, required this.brightness});

  @override
  Widget build(BuildContext context) {
    final isDark      = brightness == Brightness.dark;
    final borderCol   = AppTheme.border(brightness);
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);

    // Subtle gradient accent behind the header.
    final headerBg = isDark
        ? const Color(0xFF1C1A27)
        : AppColors.surface;

    return Container(
      height: AppConstants.topBarHeight,
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(bottom: BorderSide(color: borderCol, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Sparkle icon badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFFBB5CF8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: const Center(
              child: Text(
                '✨',
                style: TextStyle(fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Title + subtitle
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Marketing AI',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                Text(
                  'Your AI marketing analyst',
                  style: TextStyle(
                    color: textSec,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Close button
          _IconBtn(
            icon: Icons.close,
            tooltip: 'Close AI Assistant',
            onTap: onClose,
            brightness: brightness,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggestions view — shown when the conversation is empty
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestionsView extends StatelessWidget {
  final String currentRoute;
  final ValueChanged<String> onSuggest;
  final Brightness brightness;

  const _SuggestionsView({
    required this.currentRoute,
    required this.onSuggest,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final suggestions = AiSuggestions.forRoute(currentRoute);
    final textSec = AppTheme.textSecondary(brightness);
    final textPrimary = AppTheme.textPrimary(brightness);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      children: [
        // Welcome copy
        Center(
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFFBB5CF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('✨', style: TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Marketing AI',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ask anything about your\nmarketing data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSec, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'Suggested questions',
          style: TextStyle(
            color: textSec,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),

        // Suggestion chips
        for (final s in suggestions) ...[
          _SuggestionChip(
            text: s,
            onTap: () => onSuggest(s),
            brightness: brightness,
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _SuggestionChip extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final Brightness brightness;

  const _SuggestionChip({
    required this.text,
    required this.onTap,
    required this.brightness,
  });

  @override
  State<_SuggestionChip> createState() => _SuggestionChipState();
}

class _SuggestionChipState extends State<_SuggestionChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.brightness == Brightness.dark;
    final bg = _hovered
        ? (isDark
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.primaryLighter)
        : (isDark
            ? const Color(0xFF252235)
            : AppColors.background);
    final border = _hovered
        ? AppColors.primary.withValues(alpha: 0.5)
        : AppTheme.border(widget.brightness);
    final textCol = _hovered
        ? AppColors.primary
        : AppTheme.textPrimary(widget.brightness);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_outlined,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    color: textCol,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat list — the conversation history
// ─────────────────────────────────────────────────────────────────────────────

class _ChatList extends StatelessWidget {
  final List<AiMessage> messages;
  final bool isLoading;
  final String? lastFailedQuestion;
  final VoidCallback onRetry;
  final ScrollController scrollController;
  final Brightness brightness;

  const _ChatList({
    required this.messages,
    required this.isLoading,
    required this.lastFailedQuestion,
    required this.onRetry,
    required this.scrollController,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: messages.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          // Loading bubble
          return _LoadingBubble(brightness: brightness);
        }
        final msg = messages[index];
        final isLastAndFailed = index == messages.length - 1 &&
            lastFailedQuestion != null &&
            msg.role == AiMessageRole.assistant;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: msg.role == AiMessageRole.user
              ? _UserBubble(message: msg, brightness: brightness)
              : _AiBubble(
                  message: msg,
                  brightness: brightness,
                  showRetry: isLastAndFailed,
                  onRetry: onRetry,
                ),
        );
      },
    );
  }
}

// ── User message bubble ───────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final AiMessage message;
  final Brightness brightness;

  const _UserBubble({required this.message, required this.brightness});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Flexible so the bubble never exceeds available width
        Flexible(
          child: LayoutBuilder(builder: (context, constraints) {
            return Container(
              // Cap at 80% of available width; never overflow the panel
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.80),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF8B6CF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft:     Radius.circular(14),
                  topRight:    Radius.circular(14),
                  bottomLeft:  Radius.circular(14),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            );
          }),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 13,
          backgroundColor: AppColors.primaryLight,
          child: const Text(
            'HT',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ── AI message bubble ─────────────────────────────────────────────────────────

class _AiBubble extends StatelessWidget {
  final AiMessage message;
  final Brightness brightness;
  final bool showRetry;
  final VoidCallback onRetry;

  const _AiBubble({
    required this.message,
    required this.brightness,
    required this.showRetry,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    final bubbleBg = isDark
        ? const Color(0xFF252235)
        : AppColors.surfaceVariant;
    final bubbleBorder = isDark
        ? const Color(0xFF312E47)
        : AppColors.border;
    final textCol = AppTheme.textPrimary(brightness);
    final isError = message.text.startsWith('Unable to analyze') ||
        message.text.startsWith("I don't have enough information");

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // AI avatar badge — fixed size, never flexible
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFFBB5CF8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text('✨', style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(width: 8),

        // Flexible so the bubble never exceeds available width
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                // No hardcoded maxWidth — fills Flexible and wraps text
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isError
                      ? (isDark
                          ? AppColors.danger.withValues(alpha: 0.12)
                          : AppColors.dangerBg)
                      : bubbleBg,
                  borderRadius: const BorderRadius.only(
                    topLeft:     Radius.circular(4),
                    topRight:    Radius.circular(14),
                    bottomLeft:  Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  border: Border.all(
                    color: isError
                        ? AppColors.danger.withValues(alpha: 0.3)
                        : bubbleBorder,
                    width: 1,
                  ),
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: isError ? AppColors.danger : textCol,
                    fontSize: 12.5,
                    height: 1.55,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              if (showRetry) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusSmall),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, size: 12, color: AppColors.danger),
                        SizedBox(width: 4),
                        Text(
                          'Retry',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Loading bubble ─────────────────────────────────────────────────────────────

class _LoadingBubble extends StatefulWidget {
  final Brightness brightness;
  const _LoadingBubble({required this.brightness});

  @override
  State<_LoadingBubble> createState() => _LoadingBubbleState();
}

class _LoadingBubbleState extends State<_LoadingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.brightness == Brightness.dark;
    final bubbleBg = isDark
        ? const Color(0xFF252235)
        : AppColors.surfaceVariant;
    final borderCol = isDark
        ? const Color(0xFF312E47)
        : AppColors.border;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFFBB5CF8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('✨', style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(width: 8),
          // Flexible prevents the loading bubble content from overflowing
          // the available panel width at any size.
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bubbleBg,
                borderRadius: const BorderRadius.only(
                  topLeft:     Radius.circular(4),
                  topRight:    Radius.circular(14),
                  bottomLeft:  Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
                border: Border.all(color: borderCol),
              ),
              child: FadeTransition(
                opacity: _fade,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Dot(delay: 0,   color: AppColors.primary),
                    const SizedBox(width: 4),
                    _Dot(delay: 160, color: AppColors.primary),
                    const SizedBox(width: 4),
                    _Dot(delay: 320, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Marketing AI is analyzing…',
                        style: TextStyle(
                          color: AppTheme.textSecondary(widget.brightness),
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  final Color color;
  const _Dot({required this.delay, required this.color});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input area
// ─────────────────────────────────────────────────────────────────────────────

class _InputArea extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final ValueChanged<String> onSend;
  final Brightness brightness;

  const _InputArea({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final isDark    = brightness == Brightness.dark;
    final borderCol = AppTheme.border(brightness);
    final fillColor = isDark ? const Color(0xFF252235) : AppColors.background;
    final textCol   = AppTheme.textPrimary(brightness);
    final hintCol   = AppTheme.textSecondary(brightness);

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderCol, width: 1)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: TextStyle(fontSize: 13, color: textCol),
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              enabled: !isLoading,
              onSubmitted: isLoading ? null : onSend,
              decoration: InputDecoration(
                hintText: 'Ask anything about your marketing data…',
                hintStyle: TextStyle(color: hintCol, fontSize: 12),
                filled: true,
                fillColor: fillColor,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusMedium),
                  borderSide: BorderSide(color: borderCol),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusMedium),
                  borderSide: BorderSide(color: borderCol),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusMedium),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusMedium),
                  borderSide: BorderSide(
                      color: borderCol.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          _SendButton(
            isLoading: isLoading,
            onTap: () => onSend(controller.text),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _SendButton({required this.isLoading, required this.onTap});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final canSend = !widget.isLoading;
    final bg = canSend
        ? (_hovered
            ? const Color(0xFF5A3DD0)
            : AppColors.primary)
        : AppColors.primary.withValues(alpha: 0.4);

    return Tooltip(
      message: widget.isLoading ? 'Analyzing…' : 'Send',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        cursor: canSend
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: canSend ? widget.onTap : null,
          child: AnimatedContainer(
            duration: AppConstants.animFast,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: widget.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(
                    Icons.send_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable small icon button used in the header
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Brightness brightness;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.brightness,
  });

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppConstants.animFast,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hovered
                  ? AppTheme.hoverFill(widget.brightness)
                  : Colors.transparent,
              borderRadius:
                  BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: AppTheme.iconColor(widget.brightness),
            ),
          ),
        ),
      ),
    );
  }
}
