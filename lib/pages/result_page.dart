import 'package:flutter/material.dart';
import 'package:ticket_scanner/pages/login_page.dart';
import '../services/api_service.dart';

class ResultPage extends StatefulWidget {
  final Map<String, dynamic> scanData;

  const ResultPage({super.key, required this.scanData});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  final _api = ApiService();
  late Future<OrderResult> _orderFuture;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _slideController.forward();

    final raw = widget.scanData['raw'] as String? ?? '';
    _orderFuture = _api.lookupTicket(raw);
    print('Looking up ticket with raw data: $raw'); // Debug log
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _done() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F0F1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: FutureBuilder<OrderResult>(
              future: _orderFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _LoadingView();
                }

                if (snapshot.hasError) {
                  return _ErrorView(
                    message: snapshot.error.toString(),
                    onDone: _done,
                  );
                }

                final result = snapshot.data!;

                if (result.sessionExpired) {
                  // Token expired — clear everything and send to login
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                  return const SizedBox.shrink();
                }

                // ── Offer redemption results ───────────────────
                if (result.isOfferRedemption) {
                  if (result.alreadyScanned) {
                    return _OfferAlreadyRedeemedView(
                      redeemedAt: result.scannedAt,
                      onDone: _done,
                    );
                  }
                  return _OfferRedeemedView(onDone: _done);
                }

                if (result.isSpeedwellChallenge) {
                  return _SpeedwellScoreEntryView(
                    offerId: result.speedwellOfferId!,
                    userId: result.speedwellUserId!,
                    offerTitle: result.speedwellOfferTitle ?? '',
                    userDisplayName: result.speedwellUserDisplayName ?? '',
                    locationName: result.speedwellLocationName ?? '',
                    api: _api,
                    onDone: _done,
                  );
                }

                // ── Ticket results ─────────────────────────────
                if (!result.valid) {
                  return _InvalidView(
                    reason: result.errorMessage ?? 'Ticket not found.',
                    onDone: _done,
                  );
                }
                return _ValidView(
                  order: result.order!,
                  onDone: _done,
                  alreadyScanned: result.alreadyScanned,
                  scannedAt: result.scannedAt,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// States
// ─────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFFAE9159)),
          SizedBox(height: 20),
          Text(
            'Verifying ticket…',
            style: TextStyle(color: Colors.white60, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onDone;

  const _ErrorView({required this.message, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return _StatusShell(
      icon: Icons.wifi_off_rounded,
      iconColor: Colors.orange,
      label: 'Connection Error',
      sublabel: message,
      onDone: onDone,
    );
  }
}

class _InvalidView extends StatelessWidget {
  final String reason;
  final VoidCallback onDone;

  const _InvalidView({required this.reason, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return _StatusShell(
      icon: Icons.cancel_rounded,
      iconColor: const Color(0xFFFF5252),
      label: 'Invalid Ticket',
      sublabel: reason,
      onDone: onDone,
    );
  }
}

class _StatusShell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sublabel;
  final VoidCallback onDone;

  const _StatusShell({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _DragHandle(),
          const Spacer(),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            sublabel,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const Spacer(),
          _DoneButton(onDone: onDone),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Valid ticket view
// ─────────────────────────────────────────────────────────────────

class _ValidView extends StatelessWidget {
  final WooOrder order;
  final VoidCallback onDone;
  final bool alreadyScanned;
  final String? scannedAt;

  const _ValidView({
    required this.order,
    required this.onDone,
    this.alreadyScanned = false,
    this.scannedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        _DragHandle(),
        const SizedBox(height: 20),

        // ── Status banner ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF00C853).withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00C853).withOpacity(0.35),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF00C853),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Valid Ticket',
                        style: TextStyle(
                          color: Color(0xFF00C853),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Order #${order.id}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),

        // ── Already scanned warning ────────────────────────────
        if (alreadyScanned)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      scannedAt != null
                          ? 'Already redeemed on $scannedAt'
                          : 'This ticket has already been scanned.',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Ticket list ────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            itemCount: order.lineItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = order.lineItems[index];
              return _TicketCard(item: item, index: index);
            },
          ),
        ),

        // ── Done button ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: _DoneButton(onDone: onDone),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  final WooLineItem item;
  final int index;

  const _TicketCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFAE9159);
    final cardColor = item.scanned
        ? accent.withOpacity(0.08)
        : const Color(0xFF1A1A2E);
    final borderColor = item.scanned
        ? accent.withOpacity(0.55)
        : const Color(0xFF1E1E1E);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: item.scanned ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                // Show "Scanned" badge on the active ticket, price on others
                if (item.scanned)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accent.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'This ticket',
                      style: TextStyle(
                        color: Color(0xFFAE9159),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (item.price != null)
                  Text(
                    item.price!,
                    style: const TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),

          // Meta rows
          if (item.meta.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: item.meta.entries
                    .map((e) => _MetaRow(label: e.key, value: e.value))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  final VoidCallback onDone;

  const _DoneButton({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onDone,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Done — Scan Next Ticket'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Offer redemption views
// ─────────────────────────────────────────────────────────────────

class _OfferRedeemedView extends StatelessWidget {
  final VoidCallback onDone;
  const _OfferRedeemedView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return _StatusShell(
      icon: Icons.local_offer_rounded,
      iconColor: const Color(0xFF00C853),
      label: 'Offer Redeemed!',
      sublabel: 'This offer has been successfully redeemed.',
      onDone: onDone,
    );
  }
}

class _OfferAlreadyRedeemedView extends StatelessWidget {
  final String? redeemedAt;
  final VoidCallback onDone;
  const _OfferAlreadyRedeemedView({required this.onDone, this.redeemedAt});

  @override
  Widget build(BuildContext context) {
    final detail = redeemedAt != null
        ? 'This offer was already redeemed on $redeemedAt.'
        : 'This offer has already been redeemed.';

    return _StatusShell(
      icon: Icons.block_rounded,
      iconColor: Colors.orange,
      label: 'Already Redeemed',
      sublabel: detail,
      onDone: onDone,
    );
  }
}

// ── _SpeedwellScoreEntryView ───────────────────────────────────────────────
class _SpeedwellScoreEntryView extends StatefulWidget {
  final int offerId;
  final int userId;
  final String offerTitle;
  final String userDisplayName;
  final ApiService api;
  final VoidCallback onDone;
  final String locationName;

  const _SpeedwellScoreEntryView({
    required this.offerId,
    required this.userId,
    required this.offerTitle,
    required this.userDisplayName,
    required this.api,
    required this.onDone,
    required this.locationName,
  });

  @override
  State<_SpeedwellScoreEntryView> createState() =>
      _SpeedwellScoreEntryViewState();
}

class _SpeedwellScoreEntryViewState extends State<_SpeedwellScoreEntryView> {
  final _scoreController = TextEditingController();
  final _locationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _submitting = false;
  String? _submitError;

  // Pre-fill in initState
  @override
  void initState() {
    super.initState();
    if (widget.locationName.isNotEmpty) {
      _locationController.text = widget.locationName;
    }
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final success = await widget.api.logSpeedwellScore(
      offerId: widget.offerId,
      userId: widget.userId,
      score: double.parse(_scoreController.text.trim()),
      location: _locationController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      // Replace this view with the success screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _SpeedwellSuccessScreen(
            userDisplayName: widget.userDisplayName,
            score: double.parse(_scoreController.text.trim()),
            onDone: widget.onDone,
          ),
        ),
      );
    } else {
      setState(() {
        _submitting = false;
        _submitError = 'Failed to log score. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        28,
        32,
        28,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.speed_rounded,
                    color: Color(0xFFFFD700),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Speedwall Challenge',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        widget.offerTitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Player info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white54,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.userDisplayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _label('Score'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _scoreController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
              decoration: _inputDecoration(hint: 'e.g. 450'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter a score';
                final n = double.tryParse(v.trim());
                if (n == null || n <= 0) return 'Must be a positive number';
                return null;
              },
            ),

            const SizedBox(height: 20),

            _label('Location'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: Colors.white.withOpacity(0.35),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _locationController.text.isNotEmpty
                        ? _locationController.text
                        : 'No location set',
                    style: TextStyle(
                      color: _locationController.text.isNotEmpty
                          ? Colors.white.withOpacity(0.6)
                          : Colors.white.withOpacity(0.25),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

            if (_submitError != null) ...[
              const SizedBox(height: 14),
              Text(
                _submitError!,
                style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13),
              ),
            ],

            const SizedBox(height: 32), // ← was Spacer()

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: const Color(
                    0xFFFFD700,
                  ).withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Log Score',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: widget.onDone,
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      color: Colors.white.withOpacity(0.55),
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    ),
  );

  InputDecoration _inputDecoration({required String hint}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 16),
    filled: true,
    fillColor: Colors.white.withOpacity(0.06),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
    ),
    errorStyle: const TextStyle(color: Color(0xFFFF6B6B)),
  );
}

// ── _SpeedwellSuccessScreen ────────────────────────────────────────────────

class _SpeedwellSuccessScreen extends StatelessWidget {
  final String userDisplayName;
  final double score;
  final VoidCallback onDone;

  const _SpeedwellSuccessScreen({
    required this.userDisplayName,
    required this.score,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Trophy icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFFFD700),
                  size: 52,
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Score Logged!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                userDisplayName,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 24),

              // Score badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '$score Av. Hit Time',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.08),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
