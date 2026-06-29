import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../services/mechanic_chat_service.dart';
import 'chat_store.dart';

/// Asisten Montir — chat konsultasi kendaraan dengan AI.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.vehicles});
  final List<Vehicle> vehicles;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatMessage {
  _ChatMessage({
    required this.role, // 'user' | 'assistant'
    required this.text,
    this.typewriter = false,
  });
  final String role;
  String text;
  bool typewriter;
}

class _ChatPageState extends State<ChatPage> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _messages = <_ChatMessage>[];
  bool _loading = false;

  late String _conversationId;
  List<ChatConversation> _conversations = [];

  static const _suggestions = [
    'Kapan waktunya ganti oli?',
    'Motor saya boros bensin, kenapa ya?',
    'Servis rutin apa saja yang perlu?',
    'Tips biar bensin lebih irit?',
  ];

  static const _greeting = 'Halo! Saya asisten montir BensinKu. '
      'Tanya apa saja soal kendaraanmu — servis, oli, BBM, '
      'atau masalah mesin. Saya bantu sebisanya. 🔧';

  @override
  void initState() {
    super.initState();
    _conversationId = _newId();
    _messages.add(_ChatMessage(
      role: 'assistant',
      text: _greeting,
      typewriter: true,
    ));
    _loadConversations();
  }

  String _newId() =>
      DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _loadConversations() async {
    final list = await ChatStore.load();
    if (mounted) setState(() => _conversations = list);
  }

  String _titleFromMessages() {
    final firstUser = _messages.firstWhere(
      (m) => m.role == 'user',
      orElse: () => _ChatMessage(role: 'user', text: 'Percakapan baru'),
    );
    final t = firstUser.text.trim();
    return t.length <= 42 ? t : '${t.substring(0, 42)}…';
  }

  Future<void> _persist() async {
    // Simpan hanya kalau sudah ada pesan user (bukan cuma sapaan).
    if (!_messages.any((m) => m.role == 'user')) return;
    final convo = ChatConversation(
      id: _conversationId,
      title: _titleFromMessages(),
      updatedAt: DateTime.now(),
      messages: _messages
          .map((m) => {'role': m.role, 'text': m.text})
          .toList(),
    );
    final updated = await ChatStore.upsert(convo);
    if (mounted) setState(() => _conversations = updated);
  }

  void _startNewChat() {
    setState(() {
      _conversationId = _newId();
      _messages
        ..clear()
        ..add(_ChatMessage(
            role: 'assistant', text: _greeting, typewriter: true));
      _loading = false;
    });
  }

  void _loadConversation(ChatConversation convo) {
    setState(() {
      _conversationId = convo.id;
      _loading = false;
      _messages
        ..clear()
        ..addAll(convo.messages.map((m) => _ChatMessage(
              role: m['role'] ?? 'assistant',
              text: m['text'] ?? '',
              typewriter: false,
            )));
    });
    _scrollToBottom(animate: false);
  }

  Future<void> _openHistory() async {
    await _loadConversations();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppEditorial.canvas,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => _HistorySheet(
        conversations: _conversations,
        currentId: _conversationId,
        onSelect: (c) {
          Navigator.of(ctx).pop();
          _loadConversation(c);
        },
        onDelete: (c) async {
          final updated = await ChatStore.delete(c.id);
          if (mounted) setState(() => _conversations = updated);
        },
      ),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  String get _vehicleContext {
    final vs = widget.vehicles;
    if (vs.isEmpty) return 'Pengguna belum menambahkan kendaraan.';
    final b = StringBuffer('Kendaraan pengguna:\n');
    for (final v in vs) {
      final head = <String>[v.type.label];
      if (v.makeModel != null && v.makeModel!.trim().isNotEmpty) {
        head.add(v.makeModel!.trim());
      }
      head.add(v.name);
      final specs = <String>[];
      if (v.manufacturingYear != null) specs.add('tahun ${v.manufacturingYear}');
      if (v.engineCc != null) specs.add('${v.engineCc} cc');
      if (v.transmission != null) specs.add(v.transmission!.label);
      if (v.bodyType != null) specs.add(v.bodyType!.label);
      if (v.recommendedRon != null) specs.add('RON ${v.recommendedRon}');
      if (v.tankCapacityLiters != null) {
        specs.add('tangki ${v.tankCapacityLiters} L');
      }
      b.writeln(
          '- ${head.join(' ')}${specs.isEmpty ? '' : ' (${specs.join(', ')})'}');
    }
    return b.toString();
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _loading) return;

    HapticFeedback.lightImpact();
    _input.clear();
    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _loading = true;
    });
    _scrollToBottom();

    // Bangun riwayat untuk dikirim (batasi 20 terakhir agar ringan).
    final history = _messages
        .where((m) => m.text.trim().isNotEmpty)
        .map((m) => {'role': m.role, 'content': m.text})
        .toList();
    final trimmed = history.length > 20
        ? history.sublist(history.length - 20)
        : history;

    try {
      final reply = await MechanicChatService.ask(
        history: trimmed,
        vehicleContext: _vehicleContext,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _messages.add(_ChatMessage(
            role: 'assistant', text: reply, typewriter: true));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _messages.add(_ChatMessage(
          role: 'assistant',
          text:
              'Maaf, asisten sedang tidak bisa dihubungi. Coba lagi sebentar '
              'ya. (${e.toString()})',
          typewriter: true,
        ));
      });
    }
    _scrollToBottom();
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final showSuggestions = _messages.length <= 1 && !_loading;

    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppEditorial.brand,
                shape: BoxShape.circle,
              ),
              child: const Icon(PhosphorIconsRegular.wrench,
                  size: 21, color: AppEditorial.ink),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Asisten Montir',
                    style: AppEditorial.heading(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    )),
                Text(
                  _loading ? 'sedang mengetik…' : 'Konsultasi kendaraan',
                  style: AppEditorial.sans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: _loading
                        ? AppEditorial.brandDeep
                        : AppEditorial.inkMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Riwayat chat',
            icon: const Icon(PhosphorIconsRegular.clockCounterClockwise),
            onPressed: _openHistory,
          ),
          IconButton(
            tooltip: 'Chat baru',
            icon: const Icon(PhosphorIconsRegular.pencilSimple),
            onPressed: _startNewChat,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (context, i) {
                if (_loading && i == _messages.length) {
                  return const _AppearAnim(
                    child: _ThinkingBubble(),
                  );
                }
                final m = _messages[i];
                return _AppearAnim(
                  child: _MessageBubble(
                    message: m,
                    onType: () => _scrollToBottom(animate: false),
                  ),
                );
              },
            ),
          ),
          if (showSuggestions)
            _Suggestions(items: _suggestions, onTap: _send),
          _InputBar(
            controller: _input,
            enabled: !_loading,
            onSend: () => _send(_input.text),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bubble
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onType});
  final _ChatMessage message;
  final VoidCallback onType;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isUser ? AppEditorial.brand : AppEditorial.cream,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 6),
          bottomRight: Radius.circular(isUser ? 6 : 18),
        ),
        boxShadow: isUser ? null : AppEditorial.softShadow,
      ),
      child: isUser
          ? Text(
              message.text,
              style: AppEditorial.sans(
                fontSize: 14.5,
                height: 1.45,
                color: AppEditorial.ink,
              ),
            )
          : (message.typewriter
              ? _Typewriter(
                  text: message.text,
                  onTick: onType,
                  onDone: () => message.typewriter = false,
                  style: AppEditorial.sans(
                    fontSize: 14.5,
                    height: 1.5,
                    color: AppEditorial.ink,
                  ),
                )
              : Text.rich(
                  TextSpan(
                    style: AppEditorial.sans(
                      fontSize: 14.5,
                      height: 1.5,
                      color: AppEditorial.ink,
                    ),
                    children: mdSpans(message.text),
                  ),
                )),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const _AssistantAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Align(
              alignment:
                  isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                ),
                child: bubble,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: AppEditorial.brandTint,
        shape: BoxShape.circle,
      ),
      child: const Icon(PhosphorIconsRegular.wrench,
          size: 18, color: AppEditorial.brandDeep),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thinking (titik 3)
// ─────────────────────────────────────────────────────────────────────────────

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _AssistantAvatar(),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppEditorial.cream,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: AppEditorial.softShadow,
            ),
            child: const _ThreeDots(),
          ),
        ],
      ),
    );
  }
}

class _ThreeDots extends StatefulWidget {
  const _ThreeDots();

  @override
  State<_ThreeDots> createState() => _ThreeDotsState();
}

class _ThreeDotsState extends State<_ThreeDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_c.value + i * 0.2) % 1.0;
            final t = (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
            return Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
              child: Transform.translate(
                offset: Offset(0, -3 * t),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      AppEditorial.inkMuted,
                      AppEditorial.brandDeep,
                      t,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typewriter
// ─────────────────────────────────────────────────────────────────────────────

class _Typewriter extends StatefulWidget {
  const _Typewriter({
    required this.text,
    required this.style,
    required this.onTick,
    required this.onDone,
  });

  final String text;
  final TextStyle style;
  final VoidCallback onTick;
  final VoidCallback onDone;

  @override
  State<_Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<_Typewriter> {
  Timer? _timer;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      // Reveal beberapa karakter per tick supaya teks panjang tidak lama.
      _count = (_count + 2).clamp(0, widget.text.length);
      if (mounted) setState(() {});
      widget.onTick();
      if (_count >= widget.text.length) {
        t.cancel();
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _complete() {
    _timer?.cancel();
    setState(() => _count = widget.text.length);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _complete, // ketuk untuk langsung tampilkan penuh
      child: Text.rich(
        TextSpan(
          style: widget.style,
          children: mdSpans(widget.text.substring(0, _count)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entrance animation (fade + slide up)
// ─────────────────────────────────────────────────────────────────────────────

class _AppearAnim extends StatefulWidget {
  const _AppearAnim({required this.child});
  final Widget child;

  @override
  State<_AppearAnim> createState() => _AppearAnimState();
}

class _AppearAnimState extends State<_AppearAnim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggestions + input
// ─────────────────────────────────────────────────────────────────────────────

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.items, required this.onTap});
  final List<String> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => onTap(items[i]),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppEditorial.cream,
              borderRadius: BorderRadius.circular(AppEditorial.rPill),
              border: Border.all(color: AppEditorial.hairline, width: 1),
            ),
            child: Text(
              items[i],
              style: AppEditorial.sans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppEditorial.inkSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppEditorial.canvasSoft,
        border: const Border(
          top: BorderSide(color: AppEditorial.hairlineSoft, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: AppEditorial.sans(fontSize: 14.5),
                  decoration: InputDecoration(
                    hintText: 'Tanya soal kendaraanmu…',
                    filled: true,
                    fillColor: AppEditorial.cream,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppEditorial.rPill),
                      borderSide: const BorderSide(
                          color: AppEditorial.hairline, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppEditorial.rPill),
                      borderSide: const BorderSide(
                          color: AppEditorial.hairline, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppEditorial.rPill),
                      borderSide:
                          const BorderSide(color: AppEditorial.ink, width: 1.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(enabled: enabled, onTap: onSend),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: enabled ? AppEditorial.brand : AppEditorial.hairline,
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppEditorial.brand.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          PhosphorIconsRegular.arrowUp,
          color: enabled ? AppEditorial.ink : AppEditorial.inkMuted,
          size: 22,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Markdown ringan → InlineSpan (bold / italic / `code`)
// ─────────────────────────────────────────────────────────────────────────────

final RegExp _mdRe = RegExp(
  r'\*\*(.+?)\*\*|__(.+?)__|\*(.+?)\*|`([^`]+?)`',
  dotAll: true,
);

/// Parse subset markdown (untuk balasan AI) jadi daftar InlineSpan.
/// Mendukung **tebal**, *miring*, dan `kode`. Marker yang belum lengkap
/// (mis. saat typewriter di tengah) dirender apa adanya sampai penutupnya muncul.
List<InlineSpan> mdSpans(String text) {
  // Bersihkan heading markdown "### " jadi tebal-baris sederhana: cukup buang '#'.
  final cleaned = text.replaceAllMapped(
    RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true),
    (_) => '',
  );

  final spans = <InlineSpan>[];
  var last = 0;
  for (final m in _mdRe.allMatches(cleaned)) {
    if (m.start > last) {
      spans.add(TextSpan(text: cleaned.substring(last, m.start)));
    }
    final bold = m.group(1) ?? m.group(2);
    final italic = m.group(3);
    final code = m.group(4);
    if (bold != null) {
      spans.add(TextSpan(
        text: bold,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ));
    } else if (italic != null) {
      spans.add(TextSpan(
        text: italic,
        style: const TextStyle(fontStyle: FontStyle.italic),
      ));
    } else if (code != null) {
      spans.add(TextSpan(
        text: code,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppEditorial.brandDeep,
        ),
      ));
    }
    last = m.end;
  }
  if (last < cleaned.length) {
    spans.add(TextSpan(text: cleaned.substring(last)));
  }
  return spans;
}

// ─────────────────────────────────────────────────────────────────────────────
// History sheet
// ─────────────────────────────────────────────────────────────────────────────

class _HistorySheet extends StatefulWidget {
  const _HistorySheet({
    required this.conversations,
    required this.currentId,
    required this.onSelect,
    required this.onDelete,
  });

  final List<ChatConversation> conversations;
  final String currentId;
  final ValueChanged<ChatConversation> onSelect;
  final ValueChanged<ChatConversation> onDelete;

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  late final List<ChatConversation> _items =
      List<ChatConversation>.from(widget.conversations);

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Baru saja';
    if (d.inMinutes < 60) return '${d.inMinutes} mnt lalu';
    if (d.inHours < 24) return '${d.inHours} jam lalu';
    if (d.inDays < 7) return '${d.inDays} hari lalu';
    return '${(d.inDays / 7).floor()} mgg lalu';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppEditorial.hairline,
                  borderRadius: BorderRadius.circular(AppEditorial.rPill),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text('Riwayat chat',
                      style: AppEditorial.heading(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      )),
                  const Spacer(),
                  Text('${_items.length}',
                      style: AppEditorial.sans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppEditorial.inkMuted,
                      )),
                ],
              ),
            ),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                child: Text(
                  'Belum ada riwayat. Percakapan akan tersimpan otomatis.',
                  textAlign: TextAlign.center,
                  style: AppEditorial.sans(
                    fontSize: 13,
                    color: AppEditorial.inkMuted,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = _items[i];
                    final selected = c.id == widget.currentId;
                    return Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? AppEditorial.brandTint
                            : AppEditorial.cream,
                        borderRadius:
                            BorderRadius.circular(AppEditorial.rTiny),
                        border: Border.all(
                          color: selected
                              ? AppEditorial.brand
                              : AppEditorial.hairline,
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        onTap: () => widget.onSelect(c),
                        contentPadding:
                            const EdgeInsets.fromLTRB(14, 4, 6, 4),
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: AppEditorial.brandTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                              PhosphorIconsRegular.chatCircle,
                              size: 18,
                              color: AppEditorial.brandDeep),
                        ),
                        title: Text(
                          c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppEditorial.heading(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          _ago(c.updatedAt),
                          style: AppEditorial.sans(
                            fontSize: 11.5,
                            color: AppEditorial.inkMuted,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(PhosphorIconsRegular.trash,
                              size: 20, color: AppEditorial.inkMuted),
                          onPressed: () {
                            widget.onDelete(c);
                            setState(() => _items.removeAt(i));
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
