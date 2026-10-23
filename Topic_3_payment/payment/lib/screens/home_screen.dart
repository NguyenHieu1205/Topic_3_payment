import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/payment_service.dart';
import 'checkout_screen.dart';
import '../part1_main.dart' as part1;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _amountController = TextEditingController(text: '50000');
  late final TextEditingController _urlController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Web dùng localhost; Android emulator dùng 10.0.2.2
    final defaultUrl = kIsWeb ? 'http://localhost:3000' : PaymentService.baseUrl;
    PaymentService.baseUrl = defaultUrl;
    _urlController = TextEditingController(text: defaultUrl);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _createAndPay() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ (> 0)')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      PaymentService.baseUrl = _urlController.text.trim();
    });

    try {
      final order = await PaymentService().createOrder(amount);
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckoutScreen(order: order),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Lỗi kết nối'),
            ],
          ),
          content: Text(e.toString().replaceAll('Exception: ', '')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cổng Thanh Toán SePay'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // App Banner Header
            Card(
              color: Colors.blue.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blue.shade200),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.verified_user, color: Colors.blue, size: 40),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tích hợp thanh toán SePay',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tự động ghi nhận giao dịch & chuyển trạng thái đơn hàng qua Webhook ngân hàng.',
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Form Title
            const Text(
              'CẤU HÌNH KẾT NỐI API (PHẦN 2)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),

            // Server URL Config
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ Backend Server URL',
                hintText: 'http://localhost:3000 hoặc URL Tunnel',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),

            // Order Amount Input
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Số tiền đơn hàng (VND)',
                hintText: 'Nhập số tiền',
                prefixIcon: Icon(Icons.monetization_on),
                border: OutlineInputBorder(),
                suffixText: 'đ',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _createAndPay,
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.shopping_bag),
              label: const Text('TẠO ĐƠN & THANH TOÁN (ONLINE)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 32),

            // Divider Line
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('HOẶC', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 24),

            // Section 2: Mock Part 1 Trigger
            const Text(
              'THỬ NGHIỆM KHÔNG CẦN BACKEND (PHẦN 1)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                // Navigate directly to Part 1 Checkout with a mock order
                final mockOrder = part1.OrderPayment(
                  orderCode: 'DH${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
                  amount: 50000.0,
                  status: part1.PaymentStatus.pending,
                  createdAt: DateTime.now(),
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => part1.CheckoutScreen(order: mockOrder),
                  ),
                );
              },
              icon: const Icon(Icons.offline_pin, color: Colors.green),
              label: const Text('CHẠY BẢN GIẢ LẬP OFFLINE (PART 1)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
                side: const BorderSide(color: Colors.green),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
