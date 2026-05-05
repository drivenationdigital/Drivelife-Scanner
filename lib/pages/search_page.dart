import 'dart:async';
import 'package:flutter/material.dart';
import '../routes.dart';
import '../services/api_service.dart';
import 'login_page.dart';

/// Search-by-text fallback for ticket lookup.
///
/// Lets the operator type a surname, email or order number, view a list
/// of matching [WooOrder]s, and tap one to land on the same result
/// screen the scanner uses.
///
/// On tap, navigates with `{'order': WooOrder}` rather than `{'raw': qr}`
/// because the search response already contains the full order — no
/// reason to round-trip through the QR endpoint and no reason to
/// increment scan_count just for a preview.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _accent = Color(0xFFAE9159);
  static const _bg = Color(0xFF0E0E0E);
  static const _card = Color(0xFF1C1C1C);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<WooOrder> _results = const [];
  bool _hasSearched = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    final query = _controller.text.trim();

    // Reflect the clear-button state immediately
    setState(() {});

    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _error = null;
        _hasSearched = false;
        _loading = false;
        _lastQuery = '';
      });
      return;
    }

    if (query.length < 2) return; // avoid spamming the API on a single char

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _loading = true;
      _error = null;
      _lastQuery = query;
    });

    final result = await ApiService().searchOrders(query);
    if (!mounted || _lastQuery != query) return; // stale response — ignore

    if (result.sessionExpired) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
      return;
    }

    if (result.errorMessage != null) {
      setState(() {
        _error = result.errorMessage;
        _loading = false;
        _hasSearched = true;
      });
      return;
    }

    setState(() {
      _results = result.orders;
      _loading = false;
      _hasSearched = true;
    });
  }

  void _onOrderTap(WooOrder order) {
    Navigator.pushNamed(
      context,
      AppRoutes.result,
      arguments: {'order': order},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Search Orders',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchField(),
          const SizedBox(height: 4),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  // ── Search field ─────────────────────────────────────────────
  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) {
          final q = v.trim();
          if (q.isNotEmpty) _performSearch(q);
        },
        style: const TextStyle(color: Colors.white, fontSize: 16),
        cursorColor: _accent,
        decoration: InputDecoration(
          hintText: 'Surname, email or order #',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white54,
                  ),
                  onPressed: _controller.clear,
                )
              : null,
          filled: true,
          fillColor: _card,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── Results / states ─────────────────────────────────────────
  Widget _buildResults() {
    if (_loading && _results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _accent),
      );
    }
    if (_error != null) {
      return _buildEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Something went wrong',
        message: _error!,
      );
    }
    if (!_hasSearched) {
      return _buildEmptyState(
        icon: Icons.search_rounded,
        title: 'Find an order',
        message: 'Type a surname, email, or order number to begin.',
      );
    }
    if (_results.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inbox_rounded,
        title: 'No matches',
        message: 'No orders found for "${_controller.text.trim()}".',
      );
    }

    return RefreshIndicator(
      color: _accent,
      backgroundColor: _card,
      onRefresh: () async {
        if (_controller.text.trim().isNotEmpty) {
          await _performSearch(_controller.text.trim());
        }
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _OrderCard(
          order: _results[i],
          onTap: () => _onOrderTap(_results[i]),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _accent, size: 32),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Order card
// ─────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final WooOrder order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ticketCount = order.lineItems.length;
    final hasEmail = order.email != null && order.email!.isNotEmpty;
    final isCompleted = _isCompleted(order.status);

    return Material(
      color: const Color(0xFF1C1C1C),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFAE9159).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(order.customerName),
                  style: const TextStyle(
                    color: Color(0xFFAE9159),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      order.customerName.isEmpty
                          ? 'Unnamed customer'
                          : order.customerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasEmail) ...[
                      const SizedBox(height: 3),
                      Text(
                        order.email!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Chip(label: '#${order.id}'),
                        _Chip(
                          label:
                              '$ticketCount ${ticketCount == 1 ? "ticket" : "tickets"}',
                        ),
                        if (order.scanCount > 0)
                          _Chip(
                            label:
                                '${order.scanCount} ${order.scanCount == 1 ? "scan" : "scans"}',
                            tone: _ChipTone.warn,
                          ),
                        if (!isCompleted)
                          _Chip(
                            label: _statusLabel(order.status),
                            tone: _ChipTone.danger,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  bool _isCompleted(String status) {
    const ok = {'wc-completed', 'completed', 'wc-processing', 'processing'};
    return ok.contains(status);
  }

  String _statusLabel(String status) {
    final clean = status.startsWith('wc-') ? status.substring(3) : status;
    if (clean.isEmpty) return 'Unknown';
    return clean[0].toUpperCase() + clean.substring(1);
  }
}

enum _ChipTone { neutral, warn, danger }

class _Chip extends StatelessWidget {
  final String label;
  final _ChipTone tone;
  const _Chip({required this.label, this.tone = _ChipTone.neutral});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      _ChipTone.warn => (
        const Color(0xFFAE9159).withOpacity(0.18),
        const Color(0xFFD9B97A),
      ),
      _ChipTone.danger => (
        const Color(0xFFB04A4A).withOpacity(0.20),
        const Color(0xFFE99B9B),
      ),
      _ChipTone.neutral => (
        Colors.white.withOpacity(0.06),
        Colors.white70,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
