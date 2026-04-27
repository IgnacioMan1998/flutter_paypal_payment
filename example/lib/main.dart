// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';

// ─── Entry point ───────────────────────────────────────────────────────────────

void main() {
  runApp(const PaypalDemoApp());
}

// ─── App ───────────────────────────────────────────────────────────────────────

class PaypalDemoApp extends StatelessWidget {
  const PaypalDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PayPal Plugin Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF003087)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}

// ─── Shared state ──────────────────────────────────────────────────────────────

/// Fill in your PayPal sandbox credentials here.
const _kClientId =
    'YOUR_SANDBOX_CLIENT_ID';
const _kClientSecret =
    'YOUR_SANDBOX_CLIENT_SECRET';
const _kReturnUrl = 'com.example.demo://paypalpay';

final _paypal = FlutterPaypalPayment();
bool _initialized = false;

Future<String?> _ensureInit() async {
  if (_initialized) return null;
  final result = await _paypal.init(
    PaypalConfig(
      clientId: _kClientId,
      environment: PaypalEnvironment.sandbox,
      returnUrl: _kReturnUrl,
      debugMode: true,
    ),
  );
  return result.fold(
    (f) => f.message,
    (_) {
      _initialized = true;
      return null;
    },
  );
}

// ─── Home Screen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text(
          'PayPal Plugin Demo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF001C64),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Credentials notice ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFCC02)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Color(0xFFE65100), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Replace _kClientId / _kClientSecret at the top of main.dart '
                    'with your PayPal sandbox credentials before testing real flows.',
                    style:
                        TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _SectionTitle('Card UI Themes'),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.palette_outlined,
            title: 'PayPal Theme',
            subtitle: 'Classic light paysheet with blue gradient card',
            color: const Color(0xFF003087),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CardFormDemoScreen(
                  theme: PaypalCardFormTheme.paypal,
                  themeName: 'PayPal',
                ),
              ),
            ),
          ),
          _FeatureCard(
            icon: Icons.dark_mode_outlined,
            title: 'Dark Theme',
            subtitle: 'Night mode with violet accent',
            color: const Color(0xFF7B61FF),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CardFormDemoScreen(
                  theme: PaypalCardFormTheme.dark,
                  themeName: 'Dark',
                ),
              ),
            ),
          ),
          _FeatureCard(
            icon: Icons.auto_awesome_outlined,
            title: 'Aurora Theme',
            subtitle: 'Deep purple to teal gradient',
            color: const Color(0xFF5E35B1),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CardFormDemoScreen(
                  theme: PaypalCardFormTheme.aurora,
                  themeName: 'Aurora',
                ),
              ),
            ),
          ),
          _FeatureCard(
            icon: Icons.star_outline,
            title: 'Gold Theme',
            subtitle: 'Midnight obsidian with gold accents',
            color: const Color(0xFFD4AF37),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CardFormDemoScreen(
                  theme: PaypalCardFormTheme.gold,
                  themeName: 'Gold',
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          _SectionTitle('Theme Comparison'),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.compare_outlined,
            title: 'Compare All Themes',
            subtitle: 'Swipe between all 4 card form themes side by side',
            color: const Color(0xFF009CDE),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ThemeComparisonScreen()),
            ),
          ),

          const SizedBox(height: 24),
          _SectionTitle('Payment Flows'),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.credit_card_outlined,
            title: 'Card Payment (with backend)',
            subtitle: 'payWithCard — provide your own orderId',
            color: const Color(0xFF00875A),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CardPaymentScreen()),
            ),
          ),
          _FeatureCard(
            icon: Icons.flash_on_outlined,
            title: 'Card Payment (no backend)',
            subtitle: 'payWithCardDirect — creates order internally',
            color: const Color(0xFF006FCF),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CardPaymentDirectScreen()),
            ),
          ),
          _FeatureCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'PayPal Checkout (with backend)',
            subtitle: 'pay — provide your own orderId',
            color: const Color(0xFF009CDE),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaypalCheckoutScreen()),
            ),
          ),
          _FeatureCard(
            icon: Icons.bolt_outlined,
            title: 'PayPal Checkout (no backend)',
            subtitle: 'payDirect — creates order internally',
            color: const Color(0xFF0070BA),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PaypalCheckoutDirectScreen()),
            ),
          ),

          const SizedBox(height: 24),
          _SectionTitle('Vault (Save Payment Method)'),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.lock_outline,
            title: 'Vault Card',
            subtitle: 'Save a card for future payments',
            color: const Color(0xFFAB47BC),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VaultCardScreen()),
            ),
          ),
          _FeatureCard(
            icon: Icons.account_circle_outlined,
            title: 'Vault PayPal Account',
            subtitle: 'Save a PayPal account for future payments',
            color: const Color(0xFF7E57C2),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VaultPaypalScreen()),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Shared widgets ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6C7378),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1A1D27),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6C7378),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: color.withValues(alpha: 0.6), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result});

  final String? result;

  @override
  Widget build(BuildContext context) {
    if (result == null) return const SizedBox.shrink();
    final isSuccess = result!.startsWith('✓');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSuccess
            ? const Color(0xFFE6F4EA)
            : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSuccess
              ? const Color(0xFF4CAF50)
              : const Color(0xFFEF5350),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            color: isSuccess
                ? const Color(0xFF2E7D32)
                : const Color(0xFFC62828),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result!,
              style: TextStyle(
                color: isSuccess
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC62828),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card Form Demo Screen (theme showcase) ────────────────────────────────────

class CardFormDemoScreen extends StatefulWidget {
  const CardFormDemoScreen({
    super.key,
    required this.theme,
    required this.themeName,
  });

  final PaypalCardFormTheme theme;
  final String themeName;

  @override
  State<CardFormDemoScreen> createState() => _CardFormDemoScreenState();
}

class _CardFormDemoScreenState extends State<CardFormDemoScreen> {
  String? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.theme.backgroundColor,
      appBar: AppBar(
        title: Text('${widget.themeName} Theme'),
        backgroundColor: widget.theme.backgroundColor,
        foregroundColor: widget.theme.primaryColor,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          _ResultBanner(result: _result),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: PaypalCardForm(
                theme: widget.theme,
                amount: '49.99',
                currency: 'USD',
                submitButtonText: 'Pay \$49.99',
                requireCardholderName: true,
                requireBillingPostalCode: true,
                onSubmit: (card) async {
                  // Simulate a short processing delay
                  await Future.delayed(const Duration(seconds: 2));
                  setState(() {
                    _result =
                        '✓ Card validated: •••• •••• •••• ${card.number.substring(card.number.length - 4)}'
                        '  exp ${card.expirationMonth}/${card.expirationYear}';
                  });
                },
                onError: (msg) {
                  setState(() => _result = '✗ Error: $msg');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Theme Comparison Screen ───────────────────────────────────────────────────

class ThemeComparisonScreen extends StatefulWidget {
  const ThemeComparisonScreen({super.key});

  @override
  State<ThemeComparisonScreen> createState() =>
      _ThemeComparisonScreenState();
}

class _ThemeComparisonScreenState extends State<ThemeComparisonScreen> {
  static const _themes = [
    (PaypalCardFormTheme.paypal, 'PayPal'),
    (PaypalCardFormTheme.dark, 'Dark'),
    (PaypalCardFormTheme.aurora, 'Aurora'),
    (PaypalCardFormTheme.gold, 'Gold'),
  ];

  int _page = 0;
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _themes[_page];
    return Scaffold(
      backgroundColor: current.$1.backgroundColor,
      appBar: AppBar(
        title: Text(current.$2),
        backgroundColor: current.$1.backgroundColor,
        foregroundColor: current.$1.primaryColor,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${_page + 1} / ${_themes.length}',
              style: TextStyle(color: current.$1.secondaryColor),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Theme tab bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: List.generate(_themes.length, (i) {
                final selected = i == _page;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _controller.animateToPage(i,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: EdgeInsets.only(right: i < _themes.length - 1 ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? current.$1.accentColor
                            : current.$1.inputFillColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _themes[i].$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? current.$1.buttonTextColor
                              : current.$1.secondaryColor,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _themes.length,
              itemBuilder: (_, i) {
                final (theme, _) = _themes[i];
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  color: theme.backgroundColor,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: PaypalCardForm(
                      theme: theme,
                      amount: '99.00',
                      currency: 'USD',
                      requireCardholderName: true,
                      onSubmit: (_) async {},
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card Payment Screen (with backend / own orderId) ─────────────────────────

class CardPaymentScreen extends StatefulWidget {
  const CardPaymentScreen({super.key});

  @override
  State<CardPaymentScreen> createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  final _orderIdController =
      TextEditingController(text: 'PASTE_YOUR_ORDER_ID');
  String? _result;
  bool _loading = false;

  @override
  void dispose() {
    _orderIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Card Payment (with backend)'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF001C64),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: TextField(
              controller: _orderIdController,
              decoration: const InputDecoration(
                labelText: 'Order ID (from your backend)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          _ResultBanner(result: _result),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: PaypalCardForm(
                amount: '25.00',
                currency: 'USD',
                isLoading: _loading,
                onSubmit: (card) async {
                  final initError = await _ensureInit();
                  if (initError != null) {
                    setState(() => _result = '✗ Init error: $initError');
                    return;
                  }
                  setState(() => _loading = true);
                  final result = await _paypal.payWithCard(
                    CardPaymentRequest(
                      orderId: _orderIdController.text.trim(),
                      card: card,
                    ),
                  );
                  setState(() {
                    _loading = false;
                    _result = result.fold(
                      (f) => '✗ ${f.message} (${f.code})',
                      (s) => '✓ Paid! Order: ${s.orderId}  '
                          '3DS: ${s.didAttemptThreeDSecureAuthentication}',
                    );
                  });
                },
                onError: (msg) =>
                    setState(() => _result = '✗ Form error: $msg'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card Payment Direct Screen (no backend) ──────────────────────────────────

class CardPaymentDirectScreen extends StatefulWidget {
  const CardPaymentDirectScreen({super.key});

  @override
  State<CardPaymentDirectScreen> createState() =>
      _CardPaymentDirectScreenState();
}

class _CardPaymentDirectScreenState
    extends State<CardPaymentDirectScreen> {
  final _amountController = TextEditingController(text: '35.00');
  final _currencyController = TextEditingController(text: 'USD');
  String? _result;
  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Card Payment (no backend)'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF001C64),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _currencyController,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _ResultBanner(result: _result),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: PaypalCardForm(
                theme: PaypalCardFormTheme.dark,
                amount: _amountController.text,
                currency: _currencyController.text,
                isLoading: _loading,
                requireCardholderName: true,
                onSubmit: (card) async {
                  final initError = await _ensureInit();
                  if (initError != null) {
                    setState(() => _result = '✗ Init error: $initError');
                    return;
                  }
                  setState(() => _loading = true);
                  final result = await _paypal.payWithCardDirect(
                    clientSecret: _kClientSecret,
                    params: PaymentParams(
                      amount: _amountController.text,
                      currencyCode: _currencyController.text,
                      description: 'Demo purchase',
                    ),
                    buildRequest: (orderId) => CardPaymentRequest(
                      orderId: orderId,
                      card: card,
                    ),
                  );
                  setState(() {
                    _loading = false;
                    _result = result.fold(
                      (f) => '✗ ${f.message} (${f.code})',
                      (s) => '✓ Paid! Order: ${s.orderId}',
                    );
                  });
                },
                onError: (msg) =>
                    setState(() => _result = '✗ Form error: $msg'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PayPal Checkout Screen (with backend) ────────────────────────────────────

class PaypalCheckoutScreen extends StatefulWidget {
  const PaypalCheckoutScreen({super.key});

  @override
  State<PaypalCheckoutScreen> createState() => _PaypalCheckoutScreenState();
}

class _PaypalCheckoutScreenState extends State<PaypalCheckoutScreen> {
  final _orderIdController =
      TextEditingController(text: 'PASTE_YOUR_ORDER_ID');
  String? _result;
  bool _loading = false;

  @override
  void dispose() {
    _orderIdController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    setState(() {
      _loading = true;
      _result = null;
    });
    final initError = await _ensureInit();
    if (initError != null) {
      setState(() {
        _loading = false;
        _result = '✗ Init error: $initError';
      });
      return;
    }
    final result = await _paypal.pay(
      PaymentRequest(orderId: _orderIdController.text.trim()),
    );
    setState(() {
      _loading = false;
      _result = result.fold(
        (f) => '✗ ${f.message} (${f.code})',
        (s) => '✓ Paid! Order: ${s.orderId}  Payer: ${s.payerId}',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('PayPal Checkout (with backend)'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF001C64),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create an order on your backend and paste the Order ID below.',
              style: TextStyle(color: Color(0xFF6C7378)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _orderIdController,
              decoration: const InputDecoration(
                labelText: 'Order ID',
                border: OutlineInputBorder(),
              ),
            ),
            _ResultBanner(result: _result),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _pay,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Open PayPal Checkout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003087),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PayPal Checkout Direct Screen (no backend) ───────────────────────────────

class PaypalCheckoutDirectScreen extends StatefulWidget {
  const PaypalCheckoutDirectScreen({super.key});

  @override
  State<PaypalCheckoutDirectScreen> createState() =>
      _PaypalCheckoutDirectScreenState();
}

class _PaypalCheckoutDirectScreenState
    extends State<PaypalCheckoutDirectScreen> {
  final _amountController = TextEditingController(text: '50.00');
  final _currencyController = TextEditingController(text: 'USD');
  final _descController =
      TextEditingController(text: 'Demo purchase');
  String? _result;
  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _currencyController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    setState(() {
      _loading = true;
      _result = null;
    });
    final initError = await _ensureInit();
    if (initError != null) {
      setState(() {
        _loading = false;
        _result = '✗ Init error: $initError';
      });
      return;
    }
    final result = await _paypal.payDirect(
      clientSecret: _kClientSecret,
      params: PaymentParams(
        amount: _amountController.text,
        currencyCode: _currencyController.text,
        description: _descController.text.isEmpty
            ? null
            : _descController.text,
      ),
    );
    setState(() {
      _loading = false;
      _result = result.fold(
        (f) => '✗ ${f.message} (${f.code})',
        (s) => '✓ Paid & captured! Order: ${s.orderId}',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('PayPal Checkout (no backend)'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF001C64),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _currencyController,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            _ResultBanner(result: _result),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _pay,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.bolt),
                label: const Text('Pay with PayPal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0070BA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Vault Card Screen ────────────────────────────────────────────────────────

class VaultCardScreen extends StatefulWidget {
  const VaultCardScreen({super.key});

  @override
  State<VaultCardScreen> createState() => _VaultCardScreenState();
}

class _VaultCardScreenState extends State<VaultCardScreen> {
  final _setupTokenController =
      TextEditingController(text: 'PASTE_SETUP_TOKEN');
  String? _result;
  bool _loading = false;

  @override
  void dispose() {
    _setupTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Vault Card'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF001C64),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create a setup token via the PayPal API and paste it below, '
                  'or use vaultCardDirect to skip the backend step.',
                  style:
                      TextStyle(fontSize: 12, color: Color(0xFF6C7378)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _setupTokenController,
                  decoration: const InputDecoration(
                    labelText: 'Setup Token',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          _ResultBanner(result: _result),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: PaypalCardForm(
                theme: PaypalCardFormTheme.aurora,
                submitButtonText: 'Save Card',
                isLoading: _loading,
                onSubmit: (card) async {
                  final initError = await _ensureInit();
                  if (initError != null) {
                    setState(() => _result = '✗ Init error: $initError');
                    return;
                  }
                  setState(() => _loading = true);
                  final result = await _paypal.vaultCard(
                    VaultCardRequest(
                      setupTokenId: _setupTokenController.text.trim(),
                      card: card,
                    ),
                  );
                  setState(() {
                    _loading = false;
                    _result = result.fold(
                      (f) => '✗ ${f.message} (${f.code})',
                      (s) => '✓ Vaulted! Setup token: ${s.setupTokenId}  '
                          'Status: ${s.status}',
                    );
                  });
                },
                onError: (msg) =>
                    setState(() => _result = '✗ Form error: $msg'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Vault PayPal Screen ───────────────────────────────────────────────────────

class VaultPaypalScreen extends StatefulWidget {
  const VaultPaypalScreen({super.key});

  @override
  State<VaultPaypalScreen> createState() => _VaultPaypalScreenState();
}

class _VaultPaypalScreenState extends State<VaultPaypalScreen> {
  String? _result;
  bool _loading = false;

  Future<void> _vault() async {
    setState(() {
      _loading = true;
      _result = null;
    });
    final initError = await _ensureInit();
    if (initError != null) {
      setState(() {
        _loading = false;
        _result = '✗ Init error: $initError';
      });
      return;
    }
    final result = await _paypal.vaultPaypalDirect(
      clientSecret: _kClientSecret,
    );
    setState(() {
      _loading = false;
      _result = result.fold(
        (f) => '✗ ${f.message} (${f.code})',
        (s) =>
            '✓ PayPal account vaulted! Token: ${s.setupTokenId}  Status: ${s.status}',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Vault PayPal Account'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF001C64),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Opens a PayPal checkout sheet where the user authorizes saving '
              'their account. No card form required.',
              style: TextStyle(color: Color(0xFF6C7378)),
            ),
            _ResultBanner(result: _result),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _vault,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.account_circle_outlined),
                label: const Text('Save PayPal Account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E57C2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
