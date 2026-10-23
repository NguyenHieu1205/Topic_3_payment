import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum PaymentStatus { pending, paid, expired }

class OrderPayment {
  final String orderCode;
  final double amount;
  PaymentStatus status;
  final DateTime createdAt;

  OrderPayment({
    required this.orderCode,
    required this.amount,
    required this.status,
    required this.createdAt,
  });
}

void main() {
  runApp(const Part1App());
}

class Part1App extends StatelessWidget {
  const Part1App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SePay Integration - Part 1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
        useMaterial3: true,
      ),
      home: const MainMenuScreen(),
    );
  }
}

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SePay Integration - Part 1'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(20),
          elevation: 5,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.payment, size: 64, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'PHẦN 1: Giả Lập Thanh Toán',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chạy trên DartPad, tự động đếm ngược và giả lập webhook SePay.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    final newOrder = OrderPayment(
                      orderCode: 'DH${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
                      amount: 50000.0,
                      status: PaymentStatus.pending,
                      createdAt: DateTime.now(),
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CheckoutScreen(order: newOrder),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('Tạo đơn hàng & Thanh toán'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CheckoutScreen extends StatefulWidget {
  final OrderPayment order;

  const CheckoutScreen({super.key, required this.order});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late OrderPayment _order;
  Timer? _timer;
  int _secondsRemaining = 300; // 5 minutes = 300 seconds
  bool _isMocking = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
          _order.status = PaymentStatus.expired;
        }
      });
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _mockTransfer() async {
    if (_isMocking || _order.status != PaymentStatus.pending) return;
    setState(() {
      _isMocking = true;
    });

    // Future.delayed 2s then change to paid
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() {
      _isMocking = false;
      _order.status = PaymentStatus.paid;
      _timer?.cancel();
    });

    // Navigate to Success screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SuccessReceiptScreen(order: _order),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPending = _order.status == PaymentStatus.pending;
    // Trùng tài khoản SePay thật: ACB | 31454997
    final String bankSTK = '0938983427';
    final String bankName = 'MB';
    // Đề bài (URL gốc): https://vietqr.app/img?acc=...&bank=...&amount=...&des=...&template=compact
    // Lưu ý: trên Flutter Web, Image.network tới vietqr.app bị CORS chặn → dùng Part 2 (proxy backend).
    final String qrUrl =
        'https://vietqr.app/img?acc=$bankSTK&bank=$bankName&amount=${_order.amount.toInt()}&des=${_order.orderCode}&template=compact';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán đơn hàng'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Order details
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Mã đơn hàng:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_order.orderCode, style: const TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Số tiền thanh toán:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_order.amount.toInt()}đ', style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Countdown timer & Status
            if (isPending) ...[
              const Text('Hạn thanh toán còn lại:', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(_secondsRemaining),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ],
              ),
            ] else if (_order.status == PaymentStatus.expired) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Giao dịch đã hết hạn thanh toán', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // QR Code
            if (isPending) ...[
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Quét mã QR để thanh toán', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Image.network(
                      qrUrl,
                      height: 260,
                      width: 260,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const SizedBox(
                          height: 260,
                          width: 260,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(
                          height: 260,
                          width: 260,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Lỗi tải ảnh QR VietQR', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Copy button
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _order.orderCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã sao chép nội dung chuyển khoản thành công!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Sao chép nội dung chuyển khoản'),
              ),
              const SizedBox(height: 30),

              // Simulator Button
              ElevatedButton.icon(
                onPressed: _isMocking ? null : _mockTransfer,
                icon: _isMocking
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.offline_bolt),
                label: Text(_isMocking ? 'Đang giả lập...' : 'Giả lập khách đã chuyển khoản'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SuccessReceiptScreen extends StatelessWidget {
  final OrderPayment order;

  const SuccessReceiptScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biên lai thanh toán'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'Thanh toán thành công!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cảm ơn bạn đã mua hàng. Dưới đây là biên lai thanh toán của bạn.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildReceiptRow('Mã đơn hàng', order.orderCode),
                      const Divider(),
                      _buildReceiptRow('Số tiền đã nhận', '${order.amount.toInt()}đ'),
                      const Divider(),
                      _buildReceiptRow('Trạng thái', 'Đã thanh toán (Paid)', color: Colors.green, isBold: true),
                      const Divider(),
                      _buildReceiptRow('Thời gian tạo', order.createdAt.toString().substring(0, 19)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 48),
                ),
                child: const Text('Về trang chủ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black87,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
