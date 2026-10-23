import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/order_payment.dart';
import '../services/payment_service.dart';
import 'success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final OrderPayment order;

  const CheckoutScreen({super.key, required this.order});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late OrderPayment _order;
  Timer? _countdownTimer;
  Timer? _pollingTimer;
  int _secondsRemaining = 300; // Default 5 minutes
  bool _isDisposed = false;
  String? _networkErrorMessage;
  Uint8List? _qrBytes;
  bool _qrLoading = true;
  String? _qrError;

  final PaymentService _paymentService = PaymentService();

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _calculateRemainingTime();
    _startCountdown();
    _startPolling();
    _loadQrImage();
  }

  /// Flutter Web blocks Image.network to vietqr.app (no CORS).
  /// Load bytes via http: backend proxy first, then img.vietqr.io (has CORS *).
  String _apiBase() {
    var base = PaymentService.baseUrl.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    // 10.0.2.2 only works inside Android emulator — not in desktop browser
    if (kIsWeb && base.contains('10.0.2.2')) {
      return 'http://localhost:3000';
    }
    return base;
  }

  Future<void> _loadQrImage() async {
    final amount = _order.amount.toInt();
    final query =
        'acc=${_order.bankAccount}&bank=${_order.bankName}&amount=$amount&des=${Uri.encodeComponent(_order.orderCode)}&template=compact';

    // vietqr.app không có CORS → Image.network/http trực tiếp bị chặn trên Flutter Web.
    // img.vietqr.io trả SVG (Image.memory không decode được).
    // Giải pháp: proxy PNG qua backend /api/qr (đề bài vẫn dùng vietqr.app phía server).
    final urls = <String>{
      '${_apiBase()}/api/qr?$query',
      if (kIsWeb) 'http://localhost:3000/api/qr?$query',
    }.toList();

    for (final url in urls) {
      try {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
        final type = res.headers['content-type'] ?? '';
        final isRaster = type.contains('png') || type.contains('jpeg') || type.contains('jpg') || type.contains('webp');
        if (res.statusCode == 200 && res.bodyBytes.length > 100 && (isRaster || type.isEmpty)) {
          if (_isDisposed || !mounted) return;
          setState(() {
            _qrBytes = res.bodyBytes;
            _qrLoading = false;
            _qrError = null;
          });
          return;
        }
      } catch (_) {
        // try next URL
      }
    }

    if (_isDisposed || !mounted) return;
    setState(() {
      _qrLoading = false;
      _qrError = 'Lỗi tải ảnh QR — kiểm tra backend đang chạy (localhost:3000)';
    });
  }

  void _calculateRemainingTime() {
    final difference = DateTime.now().difference(_order.createdAt).inSeconds;
    setState(() {
      _secondsRemaining = 300 - difference;
      if (_secondsRemaining <= 0) {
        _secondsRemaining = 0;
        _order = OrderPayment(
          orderCode: _order.orderCode,
          amount: _order.amount,
          status: PaymentStatus.expired,
          createdAt: _order.createdAt,
          overpaid: _order.overpaid,
          notes: 'Đã hết hạn thanh toán.',
          actualPaidAmount: _order.actualPaidAmount,
          bankAccount: _order.bankAccount,
          bankName: _order.bankName,
        );
      }
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed || !mounted) return;
      _calculateRemainingTime();
      if (_secondsRemaining <= 0) {
        _countdownTimer?.cancel();
        _pollingTimer?.cancel();
      }
    });
  }

  // Polling every 3 seconds to check payment status on Node.js Server
  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_isDisposed || !mounted || _order.status != PaymentStatus.pending) return;

      try {
        final updatedOrder = await _paymentService.getOrder(_order.orderCode);
        
        if (_isDisposed || !mounted) return;

        setState(() {
          _order = updatedOrder;
          _networkErrorMessage = null; // Clear error if success
        });

        if (_order.status == PaymentStatus.paid) {
          _pollingTimer?.cancel();
          _countdownTimer?.cancel();
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SuccessScreen(order: _order),
            ),
          );
        } else if (_order.status == PaymentStatus.expired) {
          _pollingTimer?.cancel();
          _countdownTimer?.cancel();
        }
      } catch (e) {
        if (_isDisposed || !mounted) return;
        setState(() {
          _networkErrorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _isDisposed = true;
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPending = _order.status == PaymentStatus.pending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán đơn hàng (SePay)'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Error banner for network/API issues
            if (_networkErrorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync_problem, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lỗi kết nối API: $_networkErrorMessage. Đang tự động kết nối lại...',
                        style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Order status details
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
                        Text(
                          _order.orderCode,
                          style: const TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Số tiền thanh toán:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '${_order.amount.toInt()}đ',
                          style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (_order.notes.isNotEmpty) ...[
                      const Divider(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ghi chú: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                          Expanded(
                            child: Text(
                              _order.notes,
                              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Countdown Timer or Expiry / Paid States
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
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Đang chờ hệ thống ghi nhận chuyển khoản (3s)...', style: TextStyle(color: Colors.blueGrey, fontSize: 13)),
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
                    Text('Đơn hàng đã hết hạn thanh toán', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // QR code section
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
                    SizedBox(
                      height: 260,
                      width: 260,
                      child: _qrLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _qrBytes != null
                              ? Image.memory(_qrBytes!, fit: BoxFit.contain)
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                      const SizedBox(height: 8),
                                      Text(_qrError ?? 'Lỗi tải ảnh QR VietQR', style: const TextStyle(color: Colors.grey)),
                                      TextButton(onPressed: () {
                                        setState(() {
                                          _qrLoading = true;
                                          _qrError = null;
                                        });
                                        _loadQrImage();
                                      }, child: const Text('Thử lại')),
                                    ],
                                  ),
                                ),
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
            ],
          ],
        ),
      ),
    );
  }
}
