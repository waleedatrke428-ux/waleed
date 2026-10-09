import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const SignalAdminApp());

class SignalAdminApp extends StatelessWidget {
  const SignalAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF0A0F17);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'كربيتو البلحوسي',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF26D7A0),
          brightness: Brightness.dark,
          surface: const Color(0xFF111925),
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0C131D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF263343)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF263343)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF26D7A0)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: SignalEntryPage(),
      ),
    );
  }
}

class SignalEntryPage extends StatefulWidget {
  const SignalEntryPage({super.key});

  @override
  State<SignalEntryPage> createState() => _SignalEntryPageState();
}

class _SignalEntryPageState extends State<SignalEntryPage> {
  static final Uri _endpoint =
      Uri.parse('http://freehosting.dev/backend/create_signal.php');
  static const _green = Color(0xFF26D7A0);
  static const _muted = Color(0xFF91A0B4);

  final _formKey = GlobalKey<FormState>();
  final _symbol = TextEditingController();
  final _entry = TextEditingController();
  final _target1 = TextEditingController();
  final _target2 = TextEditingController();
  final _target3 = TextEditingController();
  final _stopLoss = TextEditingController();
  final _leverage = TextEditingController();
  final _balance = TextEditingController(text: '1000');
  final _support = TextEditingController();
  final _resistance = TextEditingController();
  final _sniper = TextEditingController();
  final _flowEngine = TextEditingController();

  String _direction = 'LONG';
  String _entryTimeframe = '15m';
  double _riskPercent = 1;
  bool _dailyConfirmed = false;
  bool _fourHourConfirmed = false;
  bool _triggerConfirmed = false;
  bool _isSending = false;
  final Set<String> _fibonacciLevels = {};

  double? _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim());

  double? get _entryValue => _number(_entry);
  double? get _stopValue => _number(_stopLoss);
  double? get _balanceValue => _number(_balance);

  double? get _stopDistancePercent {
    final entry = _entryValue;
    final stop = _stopValue;
    if (entry == null || stop == null || entry <= 0 || stop <= 0) return null;
    return ((entry - stop).abs() / entry) * 100;
  }

  double? get _riskAmount {
    final balance = _balanceValue;
    if (balance == null || balance <= 0) return null;
    return balance * _riskPercent / 100;
  }

  double? get _positionNotional {
    final distance = _stopDistancePercent;
    final risk = _riskAmount;
    if (distance == null || distance <= 0 || risk == null) return null;
    return risk / (distance / 100);
  }

  int? get _suggestedLeverage {
    final balance = _balanceValue;
    final notional = _positionNotional;
    if (balance == null || balance <= 0 || notional == null) return null;
    return (notional / balance).ceil().clamp(1, 125).toInt();
  }

  double? get _positionQuantity {
    final entry = _entryValue;
    final notional = _positionNotional;
    if (entry == null || entry <= 0 || notional == null) return null;
    return notional / entry;
  }

  @override
  void dispose() {
    _symbol.dispose();
    _entry.dispose();
    _target1.dispose();
    _target2.dispose();
    _target3.dispose();
    _stopLoss.dispose();
    _leverage.dispose();
    _balance.dispose();
    _support.dispose();
    _resistance.dispose();
    _sniper.dispose();
    _flowEngine.dispose();
    super.dispose();
  }

  String? _requiredText(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'أدخل $label';
    return null;
  }

  String? _positiveNumber(String? value, String label) {
    final parsed = double.tryParse((value ?? '').trim());
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return 'أدخل $label رقماً أكبر من صفر';
    }
    return null;
  }

  String? _validateLeverage(String? value) {
    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null || parsed < 1 || parsed > 125) {
      return 'أدخل رافعة صحيحة بين 1 و125';
    }
    return null;
  }

  String? _validateSignalPrices() {
    final entry = _number(_entry);
    final stop = _number(_stopLoss);
    final targets = [_target1, _target2, _target3].map(_number).toList();
    if (entry == null || stop == null || targets.any((value) => value == null)) {
      return null;
    }
    if (_direction == 'LONG') {
      if (stop >= entry) return 'في صفقة LONG يجب أن يكون وقف الخسارة أدنى من الدخول';
      if (targets.any((target) => target! <= entry) ||
          targets[0]! >= targets[1]! ||
          targets[1]! >= targets[2]!) {
        return 'في LONG يجب أن ترتفع الأهداف بالتتابع فوق سعر الدخول';
      }
    } else {
      if (stop <= entry) return 'في صفقة SHORT يجب أن يكون وقف الخسارة أعلى من الدخول';
      if (targets.any((target) => target! >= entry) ||
          targets[0]! <= targets[1]! ||
          targets[1]! <= targets[2]!) {
        return 'في SHORT يجب أن تنخفض الأهداف بالتتابع تحت سعر الدخول';
      }
    }
    return null;
  }

  Future<void> _publish() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final priceError = _validateSignalPrices();
    if (priceError != null) {
      _showMessage(priceError, isError: true);
      return;
    }
    if (!_dailyConfirmed || !_fourHourConfirmed || !_triggerConfirmed) {
      _showMessage('أكد الفريم اليومي و4 ساعات وإشارة الدخول قبل النشر',
          isError: true);
      return;
    }
    if (_fibonacciLevels.isEmpty) {
      _showMessage('اختر مستوى Fibonacci واحداً على الأقل', isError: true);
      return;
    }
    if (_stopDistancePercent == null || _positionNotional == null) {
      _showMessage('أدخل أسعاراً ورصيداً صالحاً لحساب المخاطر',
          isError: true);
      return;
    }

    final payload = <String, Object>{
      'symbol': _symbol.text.trim().toUpperCase(),
      'direction': _direction,
      'entry_price': _entryValue!,
      'target_1': _number(_target1)!,
      'target_2': _number(_target2)!,
      'target_3': _number(_target3)!,
      'stop_loss': _stopValue!,
      'leverage': int.parse(_leverage.text.trim()),
      'risk_percent': _riskPercent,
      'risk_calculator': {
        'account_balance': _balanceValue!,
        'risk_amount': _riskAmount!,
        'stop_distance_percent': _stopDistancePercent!,
        'position_notional': _positionNotional!,
        'position_quantity': _positionQuantity!,
      },
      'multi_timeframe_confirmation': {
        'daily': _dailyConfirmed,
        '4h': _fourHourConfirmed,
        'entry_timeframe': _entryTimeframe,
        'entry_trigger_confirmed': _triggerConfirmed,
      },
      'technical_filters': {
        'fibonacci_levels': _fibonacciLevels.toList()..sort(),
        'strategic_support': _support.text.trim(),
        'strategic_resistance': _resistance.text.trim(),
      },
      'liquidity_momentum': {
        'iqraa_sniper': _sniper.text.trim(),
        'iqraa_flow_engine': _flowEngine.text.trim(),
      },
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    setState(() => _isSending = true);
    try {
      final response = await http
          .post(
            _endpoint,
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));
      Map<String, dynamic> responseBody = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) responseBody = decoded;
      } on FormatException {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('استجاب الخادم برمز ${response.statusCode}');
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(responseBody['message'] ??
            'رفض الخادم الطلب (HTTP ${response.statusCode})');
      }
      if (responseBody['status'] == 'error') {
        throw Exception(responseBody['message'] ?? 'تعذر نشر الإشارة');
      }
      if (!mounted) return;
      _showMessage(
        'تم إرسال الإشارة${responseBody['signal_id'] == null ? '' : ' رقم ${responseBody['signal_id']}'}',
      );
    } on http.ClientException catch (error) {
      if (mounted) _showMessage('تعذر الاتصال بالخادم: ${error.message}', isError: true);
    } on Exception catch (error) {
      if (mounted) _showMessage('فشل النشر: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFF9D3546) : const Color(0xFF146B54),
        ),
      );
  }

  Widget _section(String title, String subtitle, IconData icon, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF111925),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFF202D3B)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _green, size: 21),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: const TextStyle(color: _muted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Widget _twoColumns(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(children: [first, const SizedBox(height: 12), second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _confirmation(String title, bool value, ValueChanged<bool?> onChanged) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: _green,
      title: Text(title, style: const TextStyle(fontSize: 14)),
    );
  }

  String _format(double? value, {int digits = 2}) =>
      value == null || !value.isFinite ? '—' : value.toStringAsFixed(digits);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F17),
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.candlestick_chart_rounded, color: _green),
            SizedBox(width: 10),
            Text('كربيتو البلحوسي',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
            SizedBox(width: 10),
            Text('إدارة صفقات الفيوتشرز',
                style: TextStyle(fontSize: 14, color: _muted)),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              children: [
                _section(
                  'بيانات الصفقة الأساسية',
                  'حدد الأصل والاتجاه والأسعار، وتحقق تلقائياً من ترتيب مستوياتك.',
                  Icons.show_chart_rounded,
                  Column(
                    children: [
                      _twoColumns(
                        _field('رمز التداول (Symbol)', _symbol,
                            hint: 'BTCUSDT',
                            validator: (value) =>
                                _requiredText(value, 'رمز التداول')),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                                value: 'LONG',
                                label: Text('LONG'),
                                icon: Icon(Icons.trending_up)),
                            ButtonSegment(
                                value: 'SHORT',
                                label: Text('SHORT'),
                                icon: Icon(Icons.trending_down)),
                          ],
                          selected: {_direction},
                          onSelectionChanged: (value) =>
                              setState(() => _direction = value.first),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _twoColumns(
                        _field('سعر الدخول (Entry)', _entry,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (value) => _positiveNumber(value, 'سعر الدخول'),
                            onChanged: (_) => setState(() {})),
                        _field('وقف الخسارة (Stop loss)', _stopLoss,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (value) =>
                                _positiveNumber(value, 'وقف الخسارة'),
                            onChanged: (_) => setState(() {})),
                      ),
                      const SizedBox(height: 12),
                      _twoColumns(
                        _field('الهدف الأول (Target 1)', _target1,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (value) => _positiveNumber(value, 'الهدف الأول')),
                        _field('الهدف الثاني (Target 2)', _target2,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (value) => _positiveNumber(value, 'الهدف الثاني')),
                      ),
                      const SizedBox(height: 12),
                      _field('الهدف الثالث (Target 3)', _target3,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) => _positiveNumber(value, 'الهدف الثالث')),
                      const SizedBox(height: 12),
                      _field('الرافعة المالية (Leverage)', _leverage,
                          hint: '1–125x',
                          keyboardType: TextInputType.number,
                          validator: _validateLeverage),
                    ],
                  ),
                ),
                _section(
                  'حاسبة المخاطر الذكية',
                  'تقدير حسابي للمخاطرة والحجم؛ الرافعة لا تقلل خسارة وقف الخسارة.',
                  Icons.calculate_outlined,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _twoColumns(
                        _field('رصيد الحساب (USDT)', _balance,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (value) => _positiveNumber(value, 'رصيد الحساب'),
                            onChanged: (_) => setState(() {})),
                        DropdownButtonFormField<double>(
                          initialValue: _riskPercent,
                          decoration:
                              const InputDecoration(labelText: 'المخاطرة المستهدفة'),
                          items: const <double>[
                            0.25,
                            0.5,
                            0.75,
                            1.0,
                            1.5,
                            2.0,
                            3.0,
                            5.0,
                          ]
                              .map((value) => DropdownMenuItem(
                                  value: value, child: Text('$value% من الرصيد')))
                              .toList(),
                          onChanged: (value) => setState(
                              () => _riskPercent = value ?? _riskPercent),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C131D),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF263343)),
                        ),
                        child: Wrap(
                          spacing: 26,
                          runSpacing: 16,
                          children: [
                            _metric('المخاطرة إلى وقف الخسارة',
                                '${_format(_stopDistancePercent)}%'),
                            _metric('قيمة المخاطرة',
                                '${_format(_riskAmount)} USDT'),
                            _metric('حجم المركز التقديري',
                                '${_format(_positionNotional)} USDT'),
                            _metric('كمية الأصل',
                                _format(_positionQuantity, digits: 6)),
                            _metric('الرافعة المقترحة',
                                '${_suggestedLeverage ?? '—'}x'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'تقدير توعوي قبل الرسوم والانزلاق السعري ومتطلبات الهامش. '
                        'تحقق من قواعد منصة التداول وحدود التصفية بنفسك.',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _section(
                  'تأكيد الفريمات المتعددة',
                  'النشر مشروط بتأكيد اليومي و4 ساعات ووجود محفز دخول على فريم صغير.',
                  Icons.checklist_rounded,
                  Column(
                    children: [
                      _confirmation(
                        'اتجاه وتحليل الفريم اليومي مؤكد',
                        _dailyConfirmed,
                        (value) =>
                            setState(() => _dailyConfirmed = value ?? false),
                      ),
                      _confirmation(
                        'اتجاه وتحليل فريم 4 ساعات مؤكد',
                        _fourHourConfirmed,
                        (value) =>
                            setState(() => _fourHourConfirmed = value ?? false),
                      ),
                      _twoColumns(
                        DropdownButtonFormField<String>(
                          initialValue: _entryTimeframe,
                          decoration: const InputDecoration(
                              labelText: 'فريم إشارة الدخول'),
                          items: const ['1m', '3m', '5m', '15m']
                              .map((value) => DropdownMenuItem(
                                  value: value, child: Text(value)))
                              .toList(),
                          onChanged: (value) => setState(
                              () => _entryTimeframe = value ?? _entryTimeframe),
                        ),
                        _confirmation(
                          'إشارة الدخول مؤكدة ولا يوجد انعكاس واضح',
                          _triggerConfirmed,
                          (value) =>
                              setState(() => _triggerConfirmed = value ?? false),
                        ),
                      ),
                    ],
                  ),
                ),
                _section(
                  'الفلاتر الفنية الكبرى',
                  'اختر مستويات Fibonacci وسجل مناطق الدعم والمقاومة الاستراتيجية.',
                  Icons.hub_outlined,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('مستويات Fibonacci المستهدفة',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ['0.618', '1.000', '1.272', '1.618', '2.000']
                            .map((level) => FilterChip(
                                  label: Text(level),
                                  selected: _fibonacciLevels.contains(level),
                                  onSelected: (selected) => setState(() {
                                    if (selected) {
                                      _fibonacciLevels.add(level);
                                    } else {
                                      _fibonacciLevels.remove(level);
                                    }
                                  }),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      _twoColumns(
                        _field('منطقة الدعم الاستراتيجية', _support,
                            hint: 'سعر أو نطاق سعري',
                            validator: (value) =>
                                _requiredText(value, 'منطقة الدعم')),
                        _field('منطقة المقاومة الاستراتيجية', _resistance,
                            hint: 'سعر أو نطاق سعري',
                            validator: (value) =>
                                _requiredText(value, 'منطقة المقاومة')),
                      ),
                    ],
                  ),
                ),
                _section(
                  'السيولة والزخم | IQRAA888',
                  'سجل قراءات الأدوات المستخدمة؛ هذه القيم يحددها المحلل وليست بيانات حية.',
                  Icons.waterfall_chart_rounded,
                  _twoColumns(
                    _field('IQRAA Sniper', _sniper,
                        hint: 'قراءة / ملاحظة الدخول',
                        validator: (value) =>
                            _requiredText(value, 'قراءة IQRAA Sniper')),
                    _field('IQRAA Flow Engine', _flowEngine,
                        hint: 'تدفق الأموال / الزخم',
                        validator: (value) =>
                            _requiredText(value, 'قراءة IQRAA Flow Engine')),
                  ),
                ),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _isSending ? null : _publish,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.publish_rounded),
                    label: Text(
                      _isSending ? 'جارٍ إرسال الإشارة...' : 'نشر الإشارة الاحترافية',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: const Color(0xFF06130F),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value) => SizedBox(
        width: 145,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 5),
            Text(value,
                style: const TextStyle(
                    color: _green, fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
      );
}
