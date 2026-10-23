import 'package:flutter/material.dart';
import '../models/order_payment.dart';

class SuccessScreen extends StatelessWidget {
  final OrderPayment order;

  const SuccessScreen({super.key, required this.order});

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
                'Hệ thống đã nhận được tiền qua SePay.',
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
                      _buildReceiptRow('Số tiền cần thanh toán', '${order.amount.toInt()}đ'),
                      const Divider(),
                      _buildReceiptRow('Số tiền thực chuyển', '${order.actualPaidAmount.toInt()}đ', isBold: true),
                      const Divider(),
                      _buildReceiptRow('Trạng thái đơn hàng', 'ĐÃ THANH TOÁN', color: Colors.green, isBold: true),
                      if (order.overpaid) ...[
                        const Divider(),
                        _buildReceiptRow('Trạng thái số tiền', 'DƯ TIỀN (OVERPAID)', color: Colors.orange, isBold: true),
                      ],
                      if (order.notes.isNotEmpty) ...[
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Ghi chú hệ thống:', style: TextStyle(color: Colors.grey)),
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  order.notes,
                                  style: const TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Divider(),
                      _buildReceiptRow('Thời gian giao dịch', order.createdAt.toLocal().toString().substring(0, 19)),
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
