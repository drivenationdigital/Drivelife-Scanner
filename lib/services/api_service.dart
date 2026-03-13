import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String baseUrl = 'https://www.carevents.com/uk';
  static const String namespace = '/wp-json/ticket-scanner/v1';
  static const String appNamespace = '/wp-json/app/v2';

  static String get loginUrl => '$baseUrl$namespace/login';
  static String get redeemOfferUrl => '$baseUrl$appNamespace/redeem-offer';

  static String ticketUrl(String qr, {bool fallback = false}) =>
      '$baseUrl$namespace/ticket/$qr';
}

class _Keys {
  static const String token = 'ts_token';
  static const String user = 'ts_user';
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AuthUser {
  final int id;
  final String displayName;
  final String username;

  const AuthUser({
    required this.id,
    required this.displayName,
    required this.username,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: (json['id'] as num).toInt(),
    displayName: json['display_name'] as String? ?? '',
    username: json['username'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'display_name': displayName,
    'username': username,
  };
}

class WooLineItem {
  final String name;
  final int quantity;
  final String? price;
  final Map<String, String> meta;
  final bool scanned; // true = this is the ticket that was just scanned

  const WooLineItem({
    required this.name,
    required this.quantity,
    this.price,
    required this.meta,
    this.scanned = false,
  });

  factory WooLineItem.fromJson(Map<String, dynamic> json) {
    final rawMeta = json['meta'];
    final meta = (rawMeta is Map)
        ? rawMeta.map((k, v) => MapEntry(k.toString(), v.toString()))
        : <String, String>{};

    return WooLineItem(
      name: json['name'] as String? ?? 'Ticket',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: json['price'] as String?,
      meta: meta,
      scanned: json['scanned'] as bool? ?? false,
    );
  }
}

class WooOrder {
  final int id;
  final String status;
  final String customerName;
  final int scanCount;
  final List<WooLineItem> lineItems;

  const WooOrder({
    required this.id,
    required this.status,
    required this.customerName,
    required this.scanCount,
    required this.lineItems,
  });

  factory WooOrder.fromJson(Map<String, dynamic> json) => WooOrder(
    id: (json['id'] as num).toInt(),
    status: json['status'] as String? ?? '',
    customerName: json['customer_name'] as String? ?? '',
    scanCount: (json['scan_count'] as num?)?.toInt() ?? 1,
    lineItems: (json['line_items'] as List<dynamic>? ?? [])
        .map((e) => WooLineItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class OrderResult {
  final bool valid;
  final bool alreadyScanned;
  final bool sessionExpired;
  final bool isOfferRedemption; // ← new
  final String? scannedAt;
  final WooOrder? order;
  final String? errorMessage;

  const OrderResult.success(this.order)
    : valid = true,
      alreadyScanned = false,
      sessionExpired = false,
      isOfferRedemption = false,
      scannedAt = null,
      errorMessage = null;

  const OrderResult.alreadyScanned(this.order, this.scannedAt)
    : valid = true,
      alreadyScanned = true,
      sessionExpired = false,
      isOfferRedemption = false,
      errorMessage = null;

  const OrderResult.failure(this.errorMessage)
    : valid = false,
      alreadyScanned = false,
      sessionExpired = false,
      isOfferRedemption = false,
      scannedAt = null,
      order = null;

  const OrderResult.expired()
    : valid = false,
      alreadyScanned = false,
      sessionExpired = true,
      isOfferRedemption = false,
      scannedAt = null,
      order = null,
      errorMessage = 'Session expired.';

  // ↓ New constructors for offer redemption flow
  const OrderResult.offerRedeemed()
    : valid = true,
      alreadyScanned = false,
      sessionExpired = false,
      isOfferRedemption = true,
      scannedAt = null,
      order = null,
      errorMessage = null;

  const OrderResult.offerAlreadyRedeemed(this.scannedAt)
    : valid = true,
      alreadyScanned = true,
      sessionExpired = false,
      isOfferRedemption = true,
      order = null,
      errorMessage = null;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;
  AuthUser? _currentUser;

  AuthUser? get currentUser => _currentUser;
  bool get isLoggedIn => _token != null;

  /// Restores a saved session from device storage.
  /// Returns true if a valid token was found.
  Future<bool> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_Keys.token);
    final savedUser = prefs.getString(_Keys.user);

    if (savedToken == null || savedUser == null) return false;

    _token = savedToken;
    _currentUser = AuthUser.fromJson(
      jsonDecode(savedUser) as Map<String, dynamic>,
    );
    return true;
  }

  Future<AuthUser> login(String username, String password) async {
    late http.Response response;

    try {
      response = await http
          .post(
            Uri.parse(ApiConfig.loginUrl),
            headers: _headers,
            body: jsonEncode({
              'username': username.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ApiException(
        'Could not reach the server. Check your connection.',
      );
    }

    final data = _decodeBody(response);
    print('Login response: $data'); // Debug log

    if (response.statusCode == 200 && data['success'] == true) {
      _token = data['token'] as String?;
      _currentUser = AuthUser.fromJson(data['user'] as Map<String, dynamic>);

      // Persist to device storage
      await _saveSession();

      return _currentUser!;
    }

    final serverError = data['error'] as String?;
    throw ApiException(
      serverError ?? 'Login failed. Please try again.',
      statusCode: response.statusCode,
    );
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    await _clearSession();
  }

  Future<OrderResult> lookupTicket(String rawQr) async {
    if (_token == null) {
      return const OrderResult.failure(
        'Not authenticated. Please log in again.',
      );
    }

    final result = await _fetchTicket(rawQr, fallback: false);

    if (result != null && (result.valid || result.sessionExpired)) {
      return result;
    }

    // Primary lookup failed — try the offer redemption endpoint as fallback
    final offerResult = await _redeemOffer(rawQr);
    print('Offer redemption result: $offerResult'); // Debug log
    if (offerResult != null) return offerResult;

    return result ??
        const OrderResult.failure(
          'Could not reach the server. Check your connection.',
        );
  }

  Future<OrderResult?> _redeemOffer(String rawQr) async {
    late http.Response response;

    try {
      response = await http
          .post(
            Uri.parse(ApiConfig.redeemOfferUrl),
            headers: _headers,
            body: jsonEncode({'payload': rawQr}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      return null;
    }

    if (response.statusCode == 401) {
      await logout();
      return const OrderResult.expired();
    }

    late Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
      print('Redeem offer response: $data'); // Debug log
    } catch (_) {
      return null;
    }

    final success = data['success'] as bool? ?? false;

    if (success) {
      return const OrderResult.offerRedeemed();
    }

    final error = data['error'] as String?;

    if (error == 'already_redeemed') {
      return OrderResult.offerAlreadyRedeemed(data['redeemed_at'] as String?);
    }

    return null;
  }

  Future<OrderResult?> _fetchTicket(
    String rawQr, {
    required bool fallback,
  }) async {
    late http.Response response;

    try {
      // Both endpoints accept the raw QR value — straightliners parses
      // the STR-prefixed format, carevents decrypts it via make_crypt
      final encoded = Uri.encodeComponent(rawQr);
      response = await http
          .get(
            Uri.parse(ApiConfig.ticketUrl(encoded, fallback: fallback)),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      return null;
    }

    if (response.statusCode == 401) {
      await logout();
      return const OrderResult.expired();
    }

    late Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return const OrderResult.failure(
        'Received an unreadable response from the server.',
      );
    }

    if (response.statusCode == 200) {
      final isValid = data['valid'] as bool? ?? false;
      if (!isValid) {
        return OrderResult.failure(
          data['reason'] as String? ?? 'Ticket is not valid.',
        );
      }
      final order = WooOrder.fromJson(data['order'] as Map<String, dynamic>);

      // Pass through already_scanned warning if carevents returned it
      if (data['already_scanned'] == true && data['scanned_at'] != null) {
        return OrderResult.alreadyScanned(order, data['scanned_at'] as String);
      }

      return OrderResult.success(order);
    }

    final error =
        data['error'] as String? ??
        'Unexpected error (${response.statusCode}).';
    return OrderResult.failure(error);
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_Keys.token, _token!);
    await prefs.setString(_Keys.user, jsonEncode(_currentUser!.toJson()));
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_Keys.token);
    await prefs.remove(_Keys.user);
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException(
        'Received an unreadable response from the server.',
      );
    }
  }
}
