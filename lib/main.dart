import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const KarmadiloApp());

class KarmadiloApp extends StatefulWidget {
  const KarmadiloApp({super.key});

  @override
  State<KarmadiloApp> createState() => _KarmadiloAppState();
}

class _KarmadiloAppState extends State<KarmadiloApp> {
  late final MarketController controller;

  @override
  void initState() {
    super.initState();
    controller = MarketController()..start();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'کارمادیلو',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
      ),
      home: SplashGate(controller: controller),
    );
  }
}

class SplashGate extends StatefulWidget {
  final MarketController controller;
  const SplashGate({super.key, required this.controller});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController animationController;
  late final Animation<double> fade;
  late final Animation<double> scale;
  late final Animation<Offset> slide;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    );
    fade = CurvedAnimation(
      parent: animationController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    scale = Tween<double>(begin: 0.84, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );
    slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.1, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    animationController.forward();
    Future<void>.delayed(const Duration(milliseconds: 1550), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => HomePage(controller: widget.controller),
          transitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(
              scale: scale,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 58),
                child: Image.asset(
                  'assets/karmadilo_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text(
                    'کارمادیلو',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MarketQuote {
  final String id;
  final String name;
  final String value;
  final String note;
  final double? change;
  final bool isLoading;
  final bool hasError;
  final DateTime? updatedAt;
  final String? source;

  const MarketQuote({
    required this.id,
    required this.name,
    this.value = '—',
    this.note = '',
    this.change,
    this.isLoading = false,
    this.hasError = false,
    this.updatedAt,
    this.source,
  });

  MarketQuote copyWith({
    String? value,
    String? note,
    double? change,
    bool? isLoading,
    bool? hasError,
    DateTime? updatedAt,
    String? source,
  }) {
    return MarketQuote(
      id: id,
      name: name,
      value: value ?? this.value,
      note: note ?? this.note,
      change: change ?? this.change,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
    );
  }
}

class RawQuote {
  final double priceToman;
  final double? change;
  final String source;

  const RawQuote({
    required this.priceToman,
    required this.source,
    this.change,
  });
}

class PricePoint {
  final int time;
  final double price;
  final double? open;
  final double? high;
  final double? low;
  final double? close;

  const PricePoint(
    this.time,
    this.price, {
    this.open,
    this.high,
    this.low,
    this.close,
  });

  Map<String, dynamic> toJson() => {
        'time': time,
        'price': price,
        if (open != null) 'open': open,
        if (high != null) 'high': high,
        if (low != null) 'low': low,
        if (close != null) 'close': close,
      };

  static PricePoint? fromJson(dynamic value) {
    if (value is! Map) return null;
    final t = value['time'];
    final p = value['price'] ?? value['close'];
    if (t is! num || p is! num || p <= 0) return null;

    double? read(String key) {
      final v = value[key];
      return v is num ? v.toDouble() : null;
    }

    return PricePoint(
      t.toInt(),
      p.toDouble(),
      open: read('open'),
      high: read('high'),
      low: read('low'),
      close: read('close'),
    );
  }
}

class MarketController extends ChangeNotifier {
  static const _timeout = Duration(seconds: 6);
  static const _cachePrefix = 'karmadilo.quote.';
  static const _historyPrefix = 'karmadilo.history.';

  final Map<String, MarketQuote> _quotes = {
    'dollar': const MarketQuote(
      id: 'dollar',
      name: 'دلار آمریکا',
      note: 'در حال آماده‌سازی قیمت...',
      isLoading: true,
    ),
    'gold18': const MarketQuote(
      id: 'gold18',
      name: 'طلای ۱۸ عیار',
      note: 'در حال آماده‌سازی قیمت...',
      isLoading: true,
    ),
    'bitcoin': const MarketQuote(
      id: 'bitcoin',
      name: 'بیت‌کوین',
      note: 'در حال آماده‌سازی قیمت...',
      isLoading: true,
    ),
  };

  bool _loading = false;
  final Map<String, List<PricePoint>> _history = {};

  List<PricePoint> historyFor(String id) =>
      List.unmodifiable(_history[id] ?? const <PricePoint>[]);

  List<MarketQuote> get quotes => _quotes.values.toList(growable: false);
  bool get loading => _loading;

  Future<void> start() async {
    await _restoreCache();
    // Historical download runs in the background; current prices still load promptly.
    unawaited(_loadHistoricalHistory());
    await refresh();
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _setLoadingState();

    await Future.wait([
      _refreshDollar(),
      _refreshGold(),
      _refreshBitcoin(),
    ]);

    _loading = false;
    notifyListeners();
  }

  void _setLoadingState() {
    for (final id in _quotes.keys) {
      final old = _quotes[id]!;
      _quotes[id] = old.copyWith(
        isLoading: old.value == '—',
        note: old.value == '—' ? 'در حال دریافت قیمت...' : old.note,
        hasError: false,
      );
    }
    notifyListeners();
  }

  Future<void> _refreshDollar() async {
    final result = await _firstValid([
      () => MarketSources.tgjuApi('دلار', 'price_dollar_rl'),
      () => MarketSources.tgjuProfile(
        'دلار',
        'https://www.tgju.org/profile/price_dollar_rl',
      ),
      () => MarketSources.mesghal('dollar'),
    ]);
    await _apply('dollar', result);
  }

  Future<void> _refreshGold() async {
    final result = await _firstValid([
      () => MarketSources.tgjuApi('طلا', 'geram18'),
      () => MarketSources.tgjuProfile(
        'طلا',
        'https://www.tgju.org/profile/geram18',
      ),
      () => MarketSources.mesghal('gold18'),
    ]);
    await _apply('gold18', result);
  }

  Future<void> _refreshBitcoin() async {
    final result = await _firstValid([
      MarketSources.nobitexBitcoin,
      MarketSources.wallexBitcoin,
      () async {
        final btcUsd = await MarketSources.tgjuBitcoinUsd();
        final dollar = await _firstValid([
          () => MarketSources.tgjuApi('دلار', 'price_dollar_rl'),
          () => MarketSources.tgjuProfile(
            'دلار',
            'https://www.tgju.org/profile/price_dollar_rl',
          ),
        ]);
        if (btcUsd == null || dollar == null) return null;
        return RawQuote(
          priceToman: btcUsd.priceToman * dollar.priceToman,
          change: btcUsd.change,
          source: 'TGJU',
        );
      },
    ]);
    await _apply('bitcoin', result);
  }

  Future<RawQuote?> _firstValid(
    List<Future<RawQuote?> Function()> sources,
  ) async {
    final pending = <int, Future<(int, RawQuote?)>>{};
    for (var i = 0; i < sources.length; i++) {
      final index = i;
      pending[index] = () async {
        try {
          return (index, await sources[index]().timeout(_timeout));
        } catch (_) {
          return (index, null);
        }
      }();
    }

    while (pending.isNotEmpty) {
      final result = await Future.any(pending.values);
      pending.remove(result.$1);
      final quote = result.$2;
      if (quote != null && quote.priceToman > 0) return quote;
    }
    return null;
  }

  Future<void> _apply(String id, RawQuote? result) async {
    final old = _quotes[id]!;
    if (result == null) {
      _quotes[id] = old.copyWith(
        isLoading: false,
        note: old.value != '—'
            ? 'آخرین قیمت ذخیره‌شده • بروزرسانی ناموفق'
            : 'فعلاً داده‌ای از منابع بازار دریافت نشد',
        hasError: true,
      );
      notifyListeners();
      return;
    }

    final now = DateTime.now();
    final quote = old.copyWith(
      value: formatToman(result.priceToman),
      note: 'تومان • ${result.source}',
      change: result.change,
      isLoading: false,
      hasError: false,
      updatedAt: now,
      source: result.source,
    );
    _quotes[id] = quote;
    await _recordHistory(id, result.priceToman, now);
    await _saveQuote(quote);
    notifyListeners();
  }

  Future<void> _recordHistory(
    String id,
    double price,
    DateTime time,
  ) async {
    final points = _history.putIfAbsent(id, () => <PricePoint>[]);
    final timestamp = time.millisecondsSinceEpoch;

    // Replace the current point if another refresh happens within one minute.
    if (points.isNotEmpty &&
        timestamp - points.last.time < 60000 &&
        timestamp >= points.last.time) {
      points[points.length - 1] = PricePoint(timestamp, price);
    } else {
      points.add(PricePoint(timestamp, price));
    }

    points.sort((a, b) => a.time.compareTo(b.time));
    if (points.length > 2000) {
      points.removeRange(0, points.length - 2000);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_historyPrefix$id',
      jsonEncode(points.map((p) => p.toJson()).toList()),
    );
  }

  Future<void> _loadHistoricalHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - const Duration(days: 31).inMilliseconds;

    final ids = ['dollar', 'gold18', 'bitcoin'];
    final needHistory = ids.any((id) {
      final points = _history[id] ?? const <PricePoint>[];
      return points.length < 20 ||
          points.isEmpty ||
          points.first.time > cutoff;
    });

    if (!needHistory) return;

    final results = await Future.wait<List<PricePoint>>([
      _historyNeedsDownload('dollar', cutoff)
          ? MarketSources.tgjuHistory('price_dollar_rl')
          : Future.value(<PricePoint>[]),
      _historyNeedsDownload('gold18', cutoff)
          ? MarketSources.tgjuHistory('geram18')
          : Future.value(<PricePoint>[]),
      _historyNeedsDownload('bitcoin', cutoff)
          ? MarketSources.nobitexBitcoinHistory()
          : Future.value(<PricePoint>[]),
    ]);

    var changed = false;
    for (var i = 0; i < ids.length; i++) {
      if (results[i].isEmpty) continue;
      final id = ids[i];
      final merged = <int, PricePoint>{
        for (final p in (_history[id] ?? <PricePoint>[])) p.time: p,
        for (final p in results[i]) p.time: p,
      };
      final points = merged.values.toList()
        ..sort((a, b) => a.time.compareTo(b.time));

      if (points.length > 2000) {
        points.removeRange(0, points.length - 2000);
      }

      _history[id] = points;
      await prefs.setString(
        '$_historyPrefix$id',
        jsonEncode(points.map((p) => p.toJson()).toList()),
      );
      changed = true;
    }

    if (changed) notifyListeners();
  }

  bool _historyNeedsDownload(String id, int cutoff) {
    final points = _history[id] ?? const <PricePoint>[];
    return points.length < 20 ||
        points.isEmpty ||
        points.first.time > cutoff;
  }

  Future<void> _saveQuote(MarketQuote quote) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
      '${_cachePrefix}${quote.id}.price',
      _numberFromFormatted(quote.value),
    );
    if (quote.updatedAt != null) {
      await prefs.setInt(
        '${_cachePrefix}${quote.id}.updatedAt',
        quote.updatedAt!.millisecondsSinceEpoch,
      );
    }
    await prefs.setString(
      '${_cachePrefix}${quote.id}.source',
      quote.source ?? '',
    );
    if (quote.change != null) {
      await prefs.setDouble(
        '${_cachePrefix}${quote.id}.change',
        quote.change!,
      );
    }
  }

  Future<void> _restoreCache() async {
    final prefs = await SharedPreferences.getInstance();

    for (final id in _quotes.keys) {
      final rawHistory = prefs.getString('$_historyPrefix$id');
      if (rawHistory != null) {
        try {
          final decoded = jsonDecode(rawHistory);
          if (decoded is List) {
            _history[id] = decoded
                .map(PricePoint.fromJson)
                .whereType<PricePoint>()
                .toList()
              ..sort((a, b) => a.time.compareTo(b.time));
          }
        } catch (_) {
          // Ignore damaged local history; live prices can still work.
        }
      }

      final price = prefs.getDouble('${_cachePrefix}$id.price');
      final timestamp = prefs.getInt('${_cachePrefix}$id.updatedAt');
      if (price == null || timestamp == null || price <= 0) continue;

      final change = prefs.getDouble('${_cachePrefix}$id.change');
      final source = prefs.getString('${_cachePrefix}$id.source');
      final old = _quotes[id]!;
      _quotes[id] = old.copyWith(
        value: formatToman(price),
        note:
            'آخرین قیمت ذخیره‌شده • ${_relativeTime(DateTime.fromMillisecondsSinceEpoch(timestamp))}',
        change: change,
        isLoading: false,
        hasError: false,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
        source: source,
      );
    }
    notifyListeners();
  }

  static double _numberFromFormatted(String value) {
    final western = value
        .replaceAll(',', '')
        .replaceAll('٬', '')
        .replaceAllMapped(
          RegExp(r'[۰-۹]'),
          (m) => '۰۱۲۳۴۵۶۷۸۹'.indexOf(m.group(0)!).toString(),
        );
    return double.tryParse(western) ?? 0;
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class MarketSources {
  static const _timeout = Duration(seconds: 12);
  static const _headers = {
    'Accept': 'application/json,text/html;q=0.9,*/*;q=0.8',
    'User-Agent': 'Mozilla/5.0 Karmadilo/0.4',
  };

  static Future<RawQuote?> tgjuApi(String label, String slug) async {
    final uri = Uri.https(
      'api.tgju.org',
      '/v1/market/indicator/summary-table-data/$slug',
      {
        'lang': 'fa',
        'draw': '1',
        'start': '0',
        'length': '1',
        'order_dir': 'desc',
        'columns[0][data]': '0',
        'columns[1][data]': '1',
        'columns[2][data]': '2',
        'columns[3][data]': '3',
        'columns[4][data]': '4',
        'columns[5][data]': '5',
        'columns[6][data]': '6',
        'columns[7][data]': '7',
        'convert_to_ad': '1',
      },
    );
    final response = await http.get(uri, headers: _headers).timeout(_timeout);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    if (data is! Map) return null;
    final rows = data['data'];
    if (rows is! List || rows.isEmpty || rows.first is! List) return null;

    final row = rows.first as List;
    final close = _numberFromCell(row.length > 3 ? row[3] : null);
    final change = _percentFromCell(row.length > 5 ? row[5] : null);
    if (close == null || close <= 0) return null;
    return RawQuote(priceToman: close / 10, change: change, source: 'TGJU API');
  }

  static Future<RawQuote?> tgjuProfile(String label, String url) async {
    final response =
        await http.get(Uri.parse(url), headers: _headers).timeout(_timeout);
    if (response.statusCode != 200) return null;

    final text = _stripHtml(response.body);
    final match =
        RegExp(r'نرخ فعلی\s*[:：]?\s*([\d۰-۹٬,\.]+)').firstMatch(text);
    if (match == null) return null;

    final rial = _parseNumber(match.group(1));
    if (rial == null || rial <= 0) return null;

    final changeMatch = RegExp(
      r'درصد تغییر نسبت به روز گذشته\s*([+-]?[\d۰-۹٬,\.]+)\s*%',
    ).firstMatch(text);
    final change =
        changeMatch == null ? null : _parseNumber(changeMatch.group(1));

    return RawQuote(priceToman: rial / 10, change: change, source: 'TGJU');
  }

  static Future<RawQuote?> mesghal(String kind) async {
    final response = await http
        .get(Uri.parse('https://www.mesghal.com/'), headers: _headers)
        .timeout(_timeout);
    if (response.statusCode != 200) return null;

    final text = _stripHtml(response.body);
    if (kind == 'gold18') {
      final match = RegExp(
        r'گرم\s*18[\s\S]{0,220}?تومان\s*[:：]?\s*([\d۰-۹٬,]+)',
      ).firstMatch(text);
      if (match == null) return null;
      final price = _parseNumber(match.group(1));
      if (price == null || price <= 0) return null;
      return RawQuote(priceToman: price, source: 'مثقال');
    }

    final match =
        RegExp(r'دلار\s*[:：]?\s*([\d۰-۹٬,]+)').firstMatch(text);
    if (match == null) return null;
    final price = _parseNumber(match.group(1));
    if (price == null || price <= 0) return null;
    return RawQuote(priceToman: price, source: 'مثقال');
  }

  static Future<RawQuote?> nobitexBitcoin() async {
    final uri = Uri.https('api.nobitex.ir', '/market/stats', {
      'srcCurrency': 'btc',
      'dstCurrency': 'rls',
    });
    final response = await http.get(uri, headers: _headers).timeout(_timeout);
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body);
    if (json is! Map) return null;
    final stats = (json['stats'] as Map?)?['btc-rls'];
    if (stats is! Map) return null;

    final latest = double.tryParse('${stats['latest']}');
    if (latest == null || latest <= 0) return null;
    final change = double.tryParse('${stats['dayChange'] ?? ''}');
    return RawQuote(
      priceToman: latest / 10,
      change: change,
      source: 'نوبیتکس',
    );
  }

  static Future<RawQuote?> wallexBitcoin() async {
    final response = await http
        .get(Uri.parse('https://api.wallex.ir/v1/markets'), headers: _headers)
        .timeout(_timeout);
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body);
    if (json is! Map) return null;
    final result = json['result'];
    if (result is! Map) return null;
    final symbols = result['symbols'];
    if (symbols is! Map) return null;

    final market = symbols['BTCIRT'] ?? symbols['BTCTMN'];
    if (market is! Map) return null;
    final stats = market['stats'];
    if (stats is! Map) return null;

    final last = double.tryParse('${stats['lastPrice']}');
    if (last == null || last <= 0) return null;
    final isToman = market['symbol'] == 'BTCTMN';
    final change = double.tryParse('${stats['24h_ch'] ?? ''}');

    return RawQuote(
      priceToman: isToman ? last : last / 10,
      change: change,
      source: 'والکس',
    );
  }

  static Future<RawQuote?> tgjuBitcoinUsd() async {
    final response = await http.get(
      Uri.parse('https://www.tgju.org/world-market/currency/profile/coin-stocks'),
      headers: _headers,
    ).timeout(_timeout);
    if (response.statusCode != 200) return null;

    final text = _stripHtml(response.body);
    final match = RegExp(r'بیت\s*کوین\s+([\d,.]+)').firstMatch(text);
    if (match == null) return null;

    final usd = _parseNumber(match.group(1));
    if (usd == null || usd <= 0) return null;
    return RawQuote(priceToman: usd, source: 'TGJU');
  }

  // Daily archive for the last month. TGJU history pages are HTML pages;
  // if their table format changes, this method safely returns no history.
  static Future<List<PricePoint>> tgjuHistory(String slug) async {
    try {
      final uri = Uri.https('www.tgju.org', '/profile/$slug/history');
      final response = await http
          .get(uri, headers: _headers)
          .timeout(_timeout);

      if (response.statusCode != 200) return [];
      final html = response.body;
      final rows = RegExp(
        r'<tr\b[^>]*>([\s\S]*?)</tr>',
        caseSensitive: false,
      ).allMatches(html);
      final result = <PricePoint>[];
      final cutoff = DateTime.now()
          .subtract(const Duration(days: 31))
          .millisecondsSinceEpoch;

      for (final rowMatch in rows) {
        final rowHtml = rowMatch.group(1)!;
        final dateMatch = RegExp(r'20\d{2}[/-]\d{1,2}[/-]\d{1,2}')
            .firstMatch(_stripHtml(rowHtml));
        if (dateMatch == null) continue;

        final cells = RegExp(
          r'<t[dh]\b[^>]*>([\s\S]*?)</t[dh]>',
          caseSensitive: false,
        ).allMatches(rowHtml).map((m) => _stripHtml(m.group(1)!)).toList();

        // Expected archive columns: open, low, high, close, change, change %, date.
        if (cells.length < 4) continue;
        final open = _parseNumber(cells[0]);
        final low = _parseNumber(cells[1]);
        final high = _parseNumber(cells[2]);
        final close = _parseNumber(cells[3]);
        if (open == null ||
            low == null ||
            high == null ||
            close == null ||
            close <= 0) {
          continue;
        }

        final dateText = dateMatch.group(0)!.replaceAll('-', '/');
        final parts = dateText.split('/');
        if (parts.length != 3) continue;

        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (year == null || month == null || day == null) continue;

        // Only accept Gregorian-looking dates. Persian dates are not converted here.
        if (year < 1900 || month < 1 || month > 12 || day < 1 || day > 31) {
          continue;
        }

        final date = DateTime(year, month, day);
        final timestamp = date.millisecondsSinceEpoch;
        if (timestamp < cutoff) continue;

        // TGJU domestic market values are generally shown in rials.
        result.add(PricePoint(
          timestamp,
          close / 10,
          open: open / 10,
          low: low / 10,
          high: high / 10,
          close: close / 10,
        ));
      }

      final unique = <int, PricePoint>{for (final p in result) p.time: p};
      final points = unique.values.toList()
        ..sort((a, b) => a.time.compareTo(b.time));
      return points;
    } catch (_) {
      return [];
    }
  }

  // Nobitex documented UDF endpoint returns genuine daily OHLC candles.
  static Future<List<PricePoint>> nobitexBitcoinHistory() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final from = now - 31 * 24 * 60 * 60;
      final uri = Uri.https('apiv2.nobitex.ir', '/market/udf/history', {
        'symbol': 'BTCIRT',
        'resolution': 'D',
        'from': '$from',
        'to': '$now',
      });

      final response = await http
          .get(uri, headers: _headers)
          .timeout(_timeout);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      if (data is! Map || data['s'] != 'ok') return [];

      final times = data['t'];
      final opens = data['o'];
      final highs = data['h'];
      final lows = data['l'];
      final closes = data['c'];

      if (times is! List ||
          opens is! List ||
          highs is! List ||
          lows is! List ||
          closes is! List) {
        return [];
      }

      final count = [
        times.length,
        opens.length,
        highs.length,
        lows.length,
        closes.length,
      ].reduce((a, b) => a < b ? a : b);

      final result = <PricePoint>[];
      for (var i = 0; i < count; i++) {
        final t = times[i];
        final o = opens[i];
        final h = highs[i];
        final l = lows[i];
        final c = closes[i];

        if (t is! num ||
            o is! num ||
            h is! num ||
            l is! num ||
            c is! num ||
            c <= 0) {
          continue;
        }

        result.add(PricePoint(
          t.toInt() * 1000,
          c.toDouble() / 10,
          open: o.toDouble() / 10,
          high: h.toDouble() / 10,
          low: l.toDouble() / 10,
          close: c.toDouble() / 10,
        ));
      }

      result.sort((a, b) => a.time.compareTo(b.time));
      return result;
    } catch (_) {
      return [];
    }
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&zwnj;', '')
        .replaceAll('&#x2F;', '/')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static double? _numberFromCell(dynamic cell) {
    if (cell == null) return null;
    return _parseNumber(_stripHtml(cell.toString()));
  }

  static double? _percentFromCell(dynamic cell) {
    if (cell == null) return null;
    final text = _stripHtml(cell.toString())
        .replaceAll('%', '')
        .replaceAll('٪', '')
        .replaceAll(',', '.');
    return _parseNumber(text);
  }

  static double? _parseNumber(String? input) {
    if (input == null) return null;
    final normalized = input
        .replaceAll('۰', '0')
        .replaceAll('۱', '1')
        .replaceAll('۲', '2')
        .replaceAll('۳', '3')
        .replaceAll('۴', '4')
        .replaceAll('۵', '5')
        .replaceAll('۶', '6')
        .replaceAll('۷', '7')
        .replaceAll('۸', '8')
        .replaceAll('۹', '9')
        .replaceAll('٬', '')
        .replaceAll(',', '')
        .replaceAll('٫', '.')
        .replaceAll(RegExp(r'[^0-9.+-]'), '')
        .trim();
    return double.tryParse(normalized);
  }
}

String formatToman(num number) {
  final raw = number.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
    buffer.write(raw[i]);
  }
  return buffer.toString().replaceAllMapped(
        RegExp(r'\d'),
        (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
      );
}

String formatPercent(double? value) {
  if (value == null) return '';
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)}٪';
}

String _relativeTime(DateTime time) {
  final seconds = DateTime.now().difference(time).inSeconds;
  if (seconds < 60) return 'همین الان';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '$minutes دقیقه قبل';
  final hours = minutes ~/ 60;
  final days = hours ~/ 24;
  if (days > 0) return '$days روز قبل';
  return '$hours ساعت قبل';
}

class HomePage extends StatefulWidget {
  final MarketController controller;
  const HomePage({super.key, required this.controller});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('کارمادیلو')),
        body: pages[index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'داشبورد',
            ),
            NavigationDestination(
              icon: Icon(Icons.show_chart),
              label: 'بازارها',
            ),
            NavigationDestination(
              icon: Icon(Icons.lightbulb_outline),
              label: 'پیشنهاد امروز',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              label: 'پیش‌بینی',
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> get pages => [
        DashboardPage(
          quotes: widget.controller.quotes,
          onRefresh: widget.controller.refresh,
        ),
        MarketsPage(
          quotes: widget.controller.quotes,
          historyFor: widget.controller.historyFor,
          onRefresh: widget.controller.refresh,
        ),
        const RecommendationsPage(),
        const ForecastPage(),
      ];
}

class DashboardPage extends StatelessWidget {
  final List<MarketQuote> quotes;
  final Future<void> Function() onRefresh;
  const DashboardPage({
    super.key,
    required this.quotes,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'سلام 👋',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('نمای کلی بازارها و قیمت‌های امروز'),
            const SizedBox(height: 20),
            ...quotes.map((quote) => MarketCard(quote: quote)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(quotes.any((q) => q.isLoading)
                        ? Icons.sync
                        : Icons.cloud_done_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        quotes.any((q) => q.isLoading)
                            ? 'قیمت‌ها در حال دریافت از چند منبع هستند...'
                            : 'برای دریافت آخرین قیمت‌ها، صفحه را به پایین بکشید.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class MarketCard extends StatelessWidget {
  final MarketQuote quote;
  const MarketCard({super.key, required this.quote});

  @override
  Widget build(BuildContext context) {
    final changeText = formatPercent(quote.change);
    final displayNote = quote.note.isEmpty ? '—' : quote.note;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          title: Text(
            quote.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(displayNote),
              if (changeText.isNotEmpty)
                Text(
                  changeText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: quote.change! >= 0
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ),
                ),
            ],
          ),
          trailing: quote.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: Text(
                    quote.value,
                    key: ValueKey(quote.value),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class MarketsPage extends StatefulWidget {
  final List<MarketQuote> quotes;
  final List<PricePoint> Function(String id) historyFor;
  final Future<void> Function() onRefresh;

  const MarketsPage({
    super.key,
    required this.quotes,
    required this.historyFor,
    required this.onRefresh,
  });

  @override
  State<MarketsPage> createState() => _MarketsPageState();
}

class _MarketsPageState extends State<MarketsPage> {
  String selectedId = 'dollar';
  bool candlestick = false;
  String period = '۱ ماه';

  @override
  Widget build(BuildContext context) {
    final quote = widget.quotes.firstWhere(
      (q) => q.id == selectedId,
      orElse: () => widget.quotes.first,
    );
    final all = widget.historyFor(quote.id);
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = period == '۱ روز'
        ? now - const Duration(days: 1).inMilliseconds
        : period == '۱ هفته'
            ? now - const Duration(days: 7).inMilliseconds
            : period == '۱ ماه'
                ? now - const Duration(days: 31).inMilliseconds
                : 0;
    final points = all.where((p) => p.time >= cutoff).toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'بازارها',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'سابقه قیمت‌ها در کارمادیلو ذخیره می‌شود و نمودار از همین اطلاعات استفاده می‌کند.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: selectedId,
            decoration: const InputDecoration(
              labelText: 'انتخاب بازار',
              border: OutlineInputBorder(),
            ),
            items: widget.quotes
                .map((q) => DropdownMenuItem(
                      value: q.id,
                      child: Text(q.name),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => selectedId = v);
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quote.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${quote.value} تومان',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    quote.note,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('خطی'),
                        icon: Icon(Icons.show_chart),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('شمعی'),
                        icon: Icon(Icons.bar_chart),
                      ),
                    ],
                    selected: {candlestick},
                    onSelectionChanged: (v) =>
                        setState(() => candlestick = v.first),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: ['۱ روز', '۱ هفته', '۱ ماه', 'همه']
                        .map(
                          (v) => ChoiceChip(
                            label: Text(v),
                            selected: period == v,
                            onSelected: (_) => setState(() => period = v),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 230,
                    width: double.infinity,
                    child: points.length < 2
                        ? Center(
                            child: Text(
                              points.isEmpty
                                  ? 'هنوز سابقه کافی دریافت نشده است. اتصال اینترنت را بررسی کنید و دوباره صفحه را به پایین بکشید.'
                                  : 'برای رسم نمودار، حداقل دو ثبت قیمت لازم است.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : CustomPaint(
                            painter: MarketChartPainter(
                              points: points,
                              candlestick: candlestick,
                              textColor:
                                  Theme.of(context).colorScheme.onSurface,
                              gridColor: Theme.of(context).dividerColor,
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تعداد ثبت‌های ذخیره‌شده: ${points.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'سابقه تاریخی از منابع قابل‌دسترسی دریافت و روی گوشی ذخیره می‌شود. اگر منبع سابقه ندهد، برنامه قیمت ساختگی نمایش نمی‌دهد.',
          ),
        ],
      ),
    );
  }
}

class MarketChartPainter extends CustomPainter {
  final List<PricePoint> points;
  final bool candlestick;
  final Color textColor;
  final Color gridColor;

  MarketChartPainter({
    required this.points,
    required this.candlestick,
    required this.textColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const left = 8.0;
    const right = 8.0;
    const top = 12.0;
    const bottom = 12.0;
    final rect = Rect.fromLTWH(
      left,
      top,
      size.width - left - right,
      size.height - top - bottom,
    );

    final values = <double>[];
    for (final p in points) {
      values.add(p.price);
      if (candlestick) {
        if (p.open != null) values.add(p.open!);
        if (p.high != null) values.add(p.high!);
        if (p.low != null) values.add(p.low!);
        if (p.close != null) values.add(p.close!);
      }
    }

    var minV = values.reduce((a, b) => a < b ? a : b);
    var maxV = values.reduce((a, b) => a > b ? a : b);
    if (maxV == minV) {
      maxV *= 1.01;
      minV *= .99;
    }

    final grid = Paint()
      ..color = gridColor.withOpacity(.45)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
    }

    double yFor(double value) =>
        rect.bottom - ((value - minV) / (maxV - minV)) * rect.height;

    if (!candlestick) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final x = rect.left +
            (points.length == 1 ? 0 : rect.width * i / (points.length - 1));
        final point = Offset(x, yFor(points[i].price));
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF8B80FF)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    } else {
      final step = rect.width / points.length;
      final candleWidth = (step * .55).clamp(2.0, 12.0).toDouble();

      for (var i = 0; i < points.length; i++) {
        final p = points[i];
        final previous = i == 0 ? p.price : points[i - 1].price;
        final open = p.open ?? previous;
        final close = p.close ?? p.price;
        final high = p.high ?? (open > close ? open : close);
        final low = p.low ?? (open < close ? open : close);
        final up = close >= open;
        final paint = Paint()
          ..color = up
              ? const Color(0xFF35C98A)
              : const Color(0xFFFF647C)
          ..strokeWidth = 1.3;

        final x = rect.left + step * (i + .5);
        canvas.drawLine(
          Offset(x, yFor(high)),
          Offset(x, yFor(low)),
          paint,
        );

        final topY = yFor(open) < yFor(close) ? yFor(open) : yFor(close);
        final bottomY = yFor(open) > yFor(close) ? yFor(open) : yFor(close);
        final body = Rect.fromLTRB(
          x - candleWidth / 2,
          topY,
          x + candleWidth / 2,
          bottomY == topY ? bottomY + 1 : bottomY,
        );
        canvas.drawRect(body, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant MarketChartPainter old) =>
      old.points != points ||
      old.candlestick != candlestick ||
      old.textColor != textColor ||
      old.gridColor != gridColor;
}

class RecommendationsPage extends StatelessWidget {
  const RecommendationsPage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'پیشنهاد امروز',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'این بخش بعد از آماده شدن داده‌های تاریخی و موتور تحلیل تکمیل می‌شود.',
          ),
          SizedBox(height: 16),
          MarketCard(
            quote: MarketQuote(
              id: 'btc-demo',
              name: 'بیت‌کوین',
              value: 'تحلیل',
              note: 'در حال آماده‌سازی موتور تحلیل',
            ),
          ),
          MarketCard(
            quote: MarketQuote(
              id: 'gold-demo',
              name: 'طلا',
              value: 'تحلیل',
              note: 'در حال آماده‌سازی موتور تحلیل',
            ),
          ),
          MarketCard(
            quote: MarketQuote(
              id: 'dollar-demo',
              name: 'دلار',
              value: 'تحلیل',
              note: 'در حال آماده‌سازی موتور تحلیل',
            ),
          ),
        ],
      );
}

class ForecastPage extends StatelessWidget {
  const ForecastPage({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'پیش‌بینی علمی\n\nافق‌های ۷، ۱۴ و ۳۰ روزه و شاخص‌های روند، نوسان و اطمینان در مرحله بعد اضافه می‌شوند.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20),
          ),
        ),
      );
}
