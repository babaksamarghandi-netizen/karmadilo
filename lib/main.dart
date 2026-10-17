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
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            pageBuilder: (_, __, ___) => HomePage(controller: widget.controller),
            transitionDuration: const Duration(milliseconds: 350),
            transitionsBuilder: (_, animation, __, child) => FadeTransition(
              opacity: animation,
              child: child,
            ),
          ),
        );
      }
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
  const PricePoint(this.time, this.price);
  Map<String, dynamic> toJson() => {'time': time, 'price': price};
  static PricePoint? fromJson(dynamic value) {
    if (value is! Map) return null;
    final t = value['time'];
    final p = value['price'];
    if (t is! num || p is! num || p <= 0) return null;
    return PricePoint(t.toInt(), p.toDouble());
  }
}

class MarketController extends ChangeNotifier {
  static const _timeout = Duration(seconds: 6);
  static const _cachePrefix = 'karmadilo.quote.';

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
  Timer? _autoRefreshTimer;
  bool _disposed = false;
  final Map<String, List<PricePoint>> _history = {};

  List<PricePoint> historyFor(String id) => List.unmodifiable(_history[id] ?? const <PricePoint>[]);

  List<MarketQuote> get quotes => _quotes.values.toList(growable: false);
  bool get loading => _loading;

  Future<void> start() async {
    await _restoreCache();
    await refresh();

    // به‌روزرسانی خودکار هر ۶۰ ثانیه تا وقتی برنامه باز است.
    // به‌روزرسانی دستی با کشیدن صفحه به پایین همچنان فعال می‌ماند.
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(refresh()),
    );
  }

  Future<void> refresh() async {
    if (_loading || _disposed) return;
    _loading = true;
    _setLoadingState();

    try {
      await Future.wait([
        _refreshDollar(),
        _refreshGold(),
        _refreshBitcoin(),
      ]);
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
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
      () => MarketSources.tgjuProfile('دلار', 'https://www.tgju.org/profile/price_dollar_rl'),
      () => MarketSources.mesghal('dollar'),
    ]);
    await _apply('dollar', result);
  }

  Future<void> _refreshGold() async {
    final result = await _firstValid([
      () => MarketSources.tgjuApi('طلا', 'geram18'),
      () => MarketSources.tgjuProfile('طلا', 'https://www.tgju.org/profile/geram18'),
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
          () => MarketSources.tgjuProfile('دلار', 'https://www.tgju.org/profile/price_dollar_rl'),
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
      if (quote != null && quote.priceToman > 0) {
        return quote;
      }
    }
    return null;
  }

  Future<void> _apply(String id, RawQuote? result) async {
    final old = _quotes[id]!;
    if (result == null) {
      if (old.value != '—') {
        _quotes[id] = old.copyWith(
          isLoading: false,
          note: 'آخرین قیمت ذخیره‌شده • بروزرسانی ناموفق',
          hasError: true,
        );
      } else {
        _quotes[id] = old.copyWith(
          isLoading: false,
          note: 'فعلاً داده‌ای از منابع بازار دریافت نشد',
          hasError: true,
        );
      }
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

  Future<void> _recordHistory(String id, double price, DateTime time) async {
    final points = _history.putIfAbsent(id, () => <PricePoint>[]);
    // Avoid storing duplicate points when a source returns the same price within a minute.
    if (points.isNotEmpty && time.millisecondsSinceEpoch - points.last.time < 60000) {
      points[points.length - 1] = PricePoint(time.millisecondsSinceEpoch, price);
    } else {
      points.add(PricePoint(time.millisecondsSinceEpoch, price));
    }
    // Keep up to 2,000 samples per market to limit local storage use.
    if (points.length > 2000) points.removeRange(0, points.length - 2000);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('karmadilo.history.$id', jsonEncode(points.map((p) => p.toJson()).toList()));
  }

  Future<void> _saveQuote(MarketQuote quote) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${_cachePrefix}${quote.id}.price', _numberFromFormatted(quote.value));
    await prefs.setInt('${_cachePrefix}${quote.id}.updatedAt', quote.updatedAt!.millisecondsSinceEpoch);
    await prefs.setString('${_cachePrefix}${quote.id}.source', quote.source ?? '');
    if (quote.change != null) {
      await prefs.setDouble('${_cachePrefix}${quote.id}.change', quote.change!);
    }
  }

  Future<void> _restoreCache() async {
    final prefs = await SharedPreferences.getInstance();
    for (final id in _quotes.keys) {
      final rawHistory = prefs.getString('karmadilo.history.$id');
      if (rawHistory != null) {
        try {
          final decoded = jsonDecode(rawHistory);
          if (decoded is List) {
            _history[id] = decoded.map(PricePoint.fromJson).whereType<PricePoint>().toList();
          }
        } catch (_) {}
      }
      final price = prefs.getDouble('${_cachePrefix}$id.price');
      final timestamp = prefs.getInt('${_cachePrefix}$id.updatedAt');
      if (price == null || timestamp == null || price <= 0) continue;
      final change = prefs.getDouble('${_cachePrefix}$id.change');
      final source = prefs.getString('${_cachePrefix}$id.source');
      final old = _quotes[id]!;
      _quotes[id] = old.copyWith(
        value: formatToman(price),
        note: 'آخرین قیمت ذخیره‌شده • ${_relativeTime(DateTime.fromMillisecondsSinceEpoch(timestamp))}',
        change: change,
        isLoading: false,
        hasError: false,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
        source: source,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  static double _numberFromFormatted(String value) {
    final western = value
        .replaceAll(',', '')
        .replaceAll('٬', '')
        .replaceAllMapped(RegExp(r'[۰-۹]'), (m) => '۰۱۲۳۴۵۶۷۸۹'.indexOf(m.group(0)!).toString());
    return double.tryParse(western) ?? 0;
  }
}

class MarketSources {
    static const _timeout = Duration(seconds: 6);
  static const _headers = {
    'Accept': 'application/json,text/html;q=0.9,*/*;q=0.8',
    'User-Agent': 'Mozilla/5.0 Karmadilo/0.3',
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
    final rows = data['data'];
    if (rows is! List || rows.isEmpty || rows.first is! List) return null;
    final row = rows.first as List;
    final close = _numberFromCell(row.length > 3 ? row[3] : null);
    final change = _percentFromCell(row.length > 5 ? row[5] : null);
    if (close == null || close <= 0) return null;
    return RawQuote(priceToman: close / 10, change: change, source: 'TGJU API');
  }

  static Future<RawQuote?> tgjuProfile(String label, String url) async {
    final response = await http.get(Uri.parse(url), headers: _headers).timeout(_timeout);
    if (response.statusCode != 200) return null;
    final text = _stripHtml(response.body);
    final match = RegExp(r'نرخ فعلی\s*[:：]\s*([\d۰-۹٬,\.]+)').firstMatch(text);
    if (match == null) return null;
    final rial = _parseNumber(match.group(1));
    if (rial == null || rial <= 0) return null;
    final changeMatch = RegExp(r'درصد تغییر نسبت به روز گذشته\s*([+-]?[\d۰-۹٬,\.]+)%').firstMatch(text);
    final change = changeMatch == null ? null : _parseNumber(changeMatch.group(1));
    return RawQuote(priceToman: rial / 10, change: change, source: 'TGJU');
  }

  static Future<RawQuote?> mesghal(String kind) async {
    final response = await http.get(Uri.parse('https://www.mesghal.com/'), headers: _headers).timeout(_timeout);
    if (response.statusCode != 200) return null;
    final text = _stripHtml(response.body);
    if (kind == 'gold18') {
      final match = RegExp(r'گرم\s*18[\s\S]{0,220}?تومان\s*[:：]\s*([\d۰-۹٬,]+)').firstMatch(text);
      if (match == null) return null;
      final price = _parseNumber(match.group(1));
      if (price == null || price <= 0) return null;
      return RawQuote(priceToman: price, source: 'مثقال');
    }
    final match = RegExp(r'دلار\s*[:：]\s*([\d۰-۹٬,]+)').firstMatch(text);
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
    final stats = json['stats']?['btc-rls'];
    if (stats is! Map) return null;
    final latest = double.tryParse('${stats['latest']}');
    if (latest == null || latest <= 0) return null;
    final change = double.tryParse('${stats['dayChange'] ?? ''}');
    return RawQuote(priceToman: latest / 10, change: change, source: 'نوبیتکس');
  }

  static Future<RawQuote?> wallexBitcoin() async {
    final response = await http.get(Uri.parse('https://api.wallex.ir/v1/markets'), headers: _headers).timeout(_timeout);
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body);
    final symbols = json['result']?['symbols'];
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
    final match = RegExp(r'بیت\s*کوین\s+([\d\.]+)').firstMatch(text);
    if (match == null) return null;
    final usd = double.tryParse(match.group(1)!.replaceAll(',', ''));
    if (usd == null || usd <= 0) return null;
    return RawQuote(priceToman: usd, source: 'TGJU');
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&zwnj;', '')
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
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'داشبورد'),
            NavigationDestination(icon: Icon(Icons.show_chart), label: 'بازارها'),
            NavigationDestination(icon: Icon(Icons.lightbulb_outline), label: 'پیشنهاد امروز'),
            NavigationDestination(icon: Icon(Icons.insights_outlined), label: 'پیش‌بینی'),
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
        MarketsPage(quotes: widget.controller.quotes, historyFor: widget.controller.historyFor, onRefresh: widget.controller.refresh),
        const RecommendationsPage(),
        const ForecastPage(),
      ];
}

class DashboardPage extends StatelessWidget {
  final List<MarketQuote> quotes;
  final Future<void> Function() onRefresh;

  const DashboardPage({super.key, required this.quotes, required this.onRefresh});

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text('سلام 👋', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
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
                    Icon(quotes.any((q) => q.isLoading) ? Icons.sync : Icons.cloud_done_outlined),
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
          title: Text(quote.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Row(
            children: [
              Flexible(child: Text(displayNote)),
              if (changeText.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  changeText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: quote.change! >= 0 ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
              ],
            ],
          ),
          trailing: quote.isLoading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: Text(
                    quote.value,
                    key: ValueKey(quote.value),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
  const MarketsPage({super.key, required this.quotes, required this.historyFor, required this.onRefresh});

  @override
  State<MarketsPage> createState() => _MarketsPageState();
}

class _MarketsPageState extends State<MarketsPage> {
  String selectedId = 'dollar';
  bool candlestick = false;
  String period = 'همه';

  @override
  Widget build(BuildContext context) {
    final quote = widget.quotes.firstWhere((q) => q.id == selectedId, orElse: () => widget.quotes.first);
    final all = widget.historyFor(quote.id);
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = period == '۱ روز' ? now - const Duration(days: 1).inMilliseconds
        : period == '۱ هفته' ? now - const Duration(days: 7).inMilliseconds
        : period == '۱ ماه' ? now - const Duration(days: 30).inMilliseconds : 0;
    final points = all.where((p) => p.time >= cutoff).toList();
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('بازارها', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('نمودارها از زمان شروع ذخیره قیمت، تاریخچه واقعی جمع می‌کنند.'),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: selectedId,
          decoration: const InputDecoration(labelText: 'انتخاب بازار', border: OutlineInputBorder()),
          items: widget.quotes.map((q) => DropdownMenuItem(value: q.id, child: Text(q.name))).toList(),
          onChanged: (v) { if (v != null) setState(() => selectedId = v); },
        ),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(quote.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${quote.value} تومان', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          Text(quote.note, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          SegmentedButton<bool>(segments: const [
            ButtonSegment(value: false, label: Text('خطی'), icon: Icon(Icons.show_chart)),
            ButtonSegment(value: true, label: Text('شمعی'), icon: Icon(Icons.bar_chart)),
          ], selected: {candlestick}, onSelectionChanged: (v) => setState(() => candlestick = v.first)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['۱ روز', '۱ هفته', '۱ ماه', 'همه']
                .map((v) => ChoiceChip(
                      label: Text(v),
                      selected: period == v,
                      onSelected: (_) => setState(() => period = v),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(height: 230, width: double.infinity, child: points.length < 2
              ? Center(child: Text(points.isEmpty ? 'هنوز تاریخچه کافی نیست. قیمت‌ها را در زمان‌های مختلف به‌روزرسانی کنید.' : 'برای رسم نمودار، حداقل دو ثبت قیمت لازم است.', textAlign: TextAlign.center))
              : CustomPaint(painter: MarketChartPainter(points: points, candlestick: candlestick, textColor: Theme.of(context).colorScheme.onSurface, gridColor: Theme.of(context).dividerColor))),
          const SizedBox(height: 8),
          Text('تعداد ثبت‌های واقعی: ${points.length}', style: Theme.of(context).textTheme.bodySmall),
        ]))),
        const SizedBox(height: 8),
        const Text('برای ساخت تاریخچه، قیمت‌ها هنگام به‌روزرسانی ذخیره می‌شوند. تاریخچه گذشته‌ای که قبلاً ثبت نشده، قابل بازسازی نیست.'),
      ]),
    );
  }
}

class MarketChartPainter extends CustomPainter {
  final List<PricePoint> points;
  final bool candlestick;
  final Color textColor;
  final Color gridColor;
  MarketChartPainter({required this.points, required this.candlestick, required this.textColor, required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    const left = 8.0, right = 8.0, top = 12.0, bottom = 12.0;
    final rect = Rect.fromLTWH(left, top, size.width-left-right, size.height-top-bottom);
    final values = points.map((p) => p.price).toList();
    var minV = values.reduce((a,b) => a < b ? a : b);
    var maxV = values.reduce((a,b) => a > b ? a : b);
    if (maxV == minV) { maxV *= 1.01; minV *= 0.99; }
    final grid = Paint()..color = gridColor.withOpacity(.45)..strokeWidth = 1;
    for (var i=0;i<4;i++) { final y=rect.top+rect.height*i/3; canvas.drawLine(Offset(rect.left,y),Offset(rect.right,y),grid); }
    double yFor(double v) => rect.bottom - ((v-minV)/(maxV-minV))*rect.height;
    if (!candlestick) {
      final path = Path();
      for (var i=0;i<points.length;i++) {
        final x = rect.left + (points.length == 1 ? 0 : rect.width*i/(points.length-1));
        final pt = Offset(x,yFor(points[i].price));
        if (i==0) path.moveTo(pt.dx,pt.dy); else path.lineTo(pt.dx,pt.dy);
      }
      canvas.drawPath(path, Paint()..color=const Color(0xFF8B80FF)..strokeWidth=2.5..style=PaintingStyle.stroke..strokeCap=StrokeCap.round);
    } else {
      final step = rect.width / points.length;
      final candleWidth = (step * .55).clamp(2.0, 12.0);
      for (var i=0;i<points.length;i++) {
        final p=points[i].price;
        final prev=i==0 ? p : points[i-1].price;
        final up=p>=prev;
        final color=up ? const Color(0xFF35C98A) : const Color(0xFFFF647C);
        final paint=Paint()..color=color..strokeWidth=1.3;
        final x=rect.left+step*(i+.5);
        canvas.drawLine(Offset(x,yFor(p)),Offset(x,yFor(prev)),paint);
        final body=Rect.fromLTRB(x-candleWidth/2, yFor(p)<yFor(prev)?yFor(p):yFor(prev), x+candleWidth/2, (yFor(p)-yFor(prev)).abs()<2 ? (yFor(p)+yFor(prev))/2+1 : (yFor(p)>yFor(prev)?yFor(p):yFor(prev)));
        canvas.drawRect(body,paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant MarketChartPainter old) => old.points != points || old.candlestick != candlestick || old.textColor != textColor || old.gridColor != gridColor;
}

class RecommendationsPage extends StatelessWidget {
  const RecommendationsPage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('پیشنهاد امروز', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('این بخش بعد از آماده شدن داده‌های تاریخی و موتور تحلیل تکمیل می‌شود.'),
          SizedBox(height: 16),
          MarketCard(quote: MarketQuote(id: 'btc-demo', name: 'بیت‌کوین', value: 'تحلیل', note: 'در حال آماده‌سازی موتور تحلیل')),
          MarketCard(quote: MarketQuote(id: 'gold-demo', name: 'طلا', value: 'تحلیل', note: 'در حال آماده‌سازی موتور تحلیل')),
          MarketCard(quote: MarketQuote(id: 'dollar-demo', name: 'دلار', value: 'تحلیل', note: 'در حال آماده‌سازی موتور تحلیل')),
        ],
      );
}

class ForecastPage extends StatelessWidget {
  const ForecastPage({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('پیش‌بینی علمی\n\nافق‌های ۷، ۱۴ و ۳۰ روزه و شاخص‌های روند، نوسان و اطمینان در مرحله بعد اضافه می‌شوند.', textAlign: TextAlign.center, style: TextStyle(fontSize: 20)),
        ),
      );
}
