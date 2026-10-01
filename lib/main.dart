import 'package:flutter/material.dart';

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

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  static const pages = [
    DashboardPage(),
    MarketsPage(),
    RecommendationsPage(),
    ForecastPage(),
  ];

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
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: const [
      Text('سلام 👋', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      SizedBox(height: 8),
      Text('نمای کلی بازارها و فرصت‌های امروز'),
      SizedBox(height: 20),
      MarketCard(name: 'دلار / ریال', value: '—', note: 'داده زنده در مرحله اتصال به منابع بازار'),
      MarketCard(name: 'طلای ۱۸ عیار', value: '—', note: 'داده زنده در مرحله اتصال به منابع بازار'),
      MarketCard(name: 'بیت‌کوین', value: '—', note: 'داده زنده در مرحله اتصال به منابع بازار'),
      SizedBox(height: 16),
      Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'نسخه اولیه رابط کاربری آماده است. در مرحله بعد، منابع داده واقعی، به‌روزرسانی خودکار و موتور تحلیل اضافه می‌شوند.',
          ),
        ),
      ),
    ],
  );
}

class MarketCard extends StatelessWidget {
  final String name;
  final String value;
  final String note;
  const MarketCard({super.key, required this.name, required this.value, required this.note});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(note),
      trailing: Text(value, style: const TextStyle(fontSize: 18)),
    ),
  );
}

class MarketsPage extends StatelessWidget {
  const MarketsPage({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('بازارها\nدلار • طلا • ارز • رمزارز • نفت • فلزات', textAlign: TextAlign.center, style: TextStyle(fontSize: 20)),
  );
}

class RecommendationsPage extends StatelessWidget {
  const RecommendationsPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: const [
      Text('پیشنهاد امروز', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      SizedBox(height: 8),
      Text('این بخش با داده واقعی و مدل تحلیلی تکمیل خواهد شد؛ مقادیر فعلی توصیه سرمایه‌گذاری نیستند.'),
      SizedBox(height: 16),
      MarketCard(name: 'بیت‌کوین', value: 'تحلیل', note: 'نمونه نمایشی'),
      MarketCard(name: 'طلا', value: 'تحلیل', note: 'نمونه نمایشی'),
      MarketCard(name: 'دلار', value: 'تحلیل', note: 'نمونه نمایشی'),
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
