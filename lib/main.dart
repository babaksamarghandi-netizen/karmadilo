import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const KarmadiloApp());

class KarmadiloApp extends StatelessWidget {
  const KarmadiloApp({super.key});

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
      home: const HomePage(),
    );
  }
}

class MarketQuote {
  final String name;
  final String value;
  final String note;
  final double? change;
  final bool isLoading;
  final bool hasError;

  const MarketQuote({
    required this.name,
    this.value = '—',
    this.note = '',
    this.change,
    this.isLoading = false,
    this.hasError = false,
  });

  MarketQuote copyWith({
    String? value,
    String? note,
    double? change,
    bool? isLoading,
    bool? hasError,
  }) {
    return MarketQuote(
      name: name,
      value: value ?? this.value,
      note: note ?? this.note,
      change: change ?? this.change,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
    );
  }
}

class MarketService {
  static const _timeout = Duration(seconds: 12);

  static Future<MarketQuote> fetchIranMarket({
    required String name,
    required String slug,
  }) async {
    try {
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

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'Karmadilo/0.1',
        },
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final json = jsonDecode(response.body);
      final rows = json['data'];

      if (rows is! List || rows.isEmpty || rows.first is! List) {
        throw Exception('داده بازار پیدا نشد');
      }

      final row = rows.first as List;
      final close = _numberFromCell(row.length > 3 ? row[3] : null);
      final change = _percentFromCell(row.length > 5 ? row[5] : null);

      if (close == null) {
        throw Exception('قیمت نامعتبر است');
      }

      // TGJU reports Iranian market prices in rial. Karmadilo displays toman.
      final toman = close / 10;

      return MarketQuote(
        name: name,
        value: formatNumber(toman.round()),
        note: 'تومان • به‌روزرسانی زنده',
        change: change,
      );
    } catch (_) {
      return MarketQuote(
        name: name,
        value: '—',
        note: 'دریافت داده ممکن نشد',
        hasError: true,
      );
    }
  }

  static Future<MarketQuote> fetchBitcoin() async {
    try {
      // CoinGecko's public endpoint is used only for the global BTC/USD quote.
      final uri = Uri.https(
        'api.coingecko.com',
        '/api/v3/simple/price',
        {
          'ids': 'bitcoin',
          'vs_currencies': 'usd',
          'include_24hr_change': 'true',
        },
      );

      final response = await http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final json = jsonDecode(response.body);
      final bitcoin = json['bitcoin'];

      if (bitcoin is! Map) {
        throw Exception('داده بیت‌کوین پیدا نشد');
      }

      final price = (bitcoin['usd'] as num?)?.toDouble();
      final change = (bitcoin['usd_24h_change'] as num?)?.toDouble();

      if (price == null) {
        throw Exception('قیمت نامعتبر است');
      }

      return MarketQuote(
        name: 'بیت‌کوین',
        value: '\$${formatNumber(price.round())}',
        note: 'دلار • تغییر ۲۴ ساعته',
        change: change,
      );
    } catch (_) {
      return const MarketQuote(
        name: 'بیت‌کوین',
        value: '—',
        note: 'دریافت داده ممکن نشد',
        hasError: true,
      );
    }
  }

  static double? _numberFromCell(dynamic cell) {
    if (cell == null) return null;
    final text = cell.toString().replaceAll(RegExp(r'<[^>]*>'), '');
    final normalized = text
        .replaceAll(',', '')
        .replaceAll('٬', '')
        .replaceAll('٫', '.')
        .trim();
    return double.tryParse(normalized);
  }

  static double? _percentFromCell(dynamic cell) {
    if (cell == null) return null;
    final text = cell
        .toString()
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('%', '')
        .replaceAll('٪', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(text);
  }
}

String formatNumber(num number) {
  final raw = number.toInt().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) {
      buffer.write(',');
    }
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  List<MarketQuote> quotes = const [
    MarketQuote(
      name: 'دلار آمریکا',
      note: 'در حال دریافت قیمت...',
      isLoading: true,
    ),
    MarketQuote(
      name: 'طلای ۱۸ عیار',
      note: 'در حال دریافت قیمت...',
      isLoading: true,
    ),
    MarketQuote(
      name: 'بیت‌کوین',
      note: 'در حال دریافت قیمت...',
      isLoading: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    final results = await Future.wait([
      MarketService.fetchIranMarket(
        name: 'دلار آمریکا',
        slug: 'price_dollar_rl',
      ),
      MarketService.fetchIranMarket(
        name: 'طلای ۱۸ عیار',
        slug: 'geram18',
      ),
      MarketService.fetchBitcoin(),
    ]);

    if (!mounted) return;

    setState(() {
      quotes = results;
    });
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
          quotes: quotes,
          onRefresh: _loadQuotes,
        ),
        const MarketsPage(),
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
            ...quotes.map(
              (quote) => MarketCard(quote: quote),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(Icons.sync),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'برای دریافت آخرین قیمت‌ها، صفحه را به پایین بکشید.',
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

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          quote.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Flexible(child: Text(quote.note)),
            if (changeText.isNotEmpty) ...[
              const SizedBox(width: 8),
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
          ],
        ),
        trailing: quote.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                quote.value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

class MarketsPage extends StatelessWidget {
  const MarketsPage({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Text(
          'بازارها\nدلار • طلا • ارز • رمزارز • نفت • فلزات',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20),
        ),
      );
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
              name: 'بیت‌کوین',
              value: 'تحلیل',
              note: 'در حال آماده‌سازی موتور تحلیل',
            ),
          ),
          MarketCard(
            quote: MarketQuote(
              name: 'طلا',
              value: 'تحلیل',
              note: 'در حال آماده‌سازی موتور تحلیل',
            ),
          ),
          MarketCard(
            quote: MarketQuote(
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
