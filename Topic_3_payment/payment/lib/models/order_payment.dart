enum PaymentStatus { pending, paid, expired }

class OrderPayment {
  final String orderCode;
  final double amount;
  final PaymentStatus status;
  final DateTime createdAt;
  final bool overpaid;
  final String notes;
  final double actualPaidAmount;
  final String bankAccount;
  final String bankName;

  OrderPayment({
    required this.orderCode,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.overpaid = false,
    this.notes = '',
    this.actualPaidAmount = 0.0,
    this.bankAccount = '31454997',
    this.bankName = 'ACB',
  });

  factory OrderPayment.fromJson(Map<String, dynamic> json) {
    PaymentStatus status;
    switch (json['status']) {
      case 'paid':
        status = PaymentStatus.paid;
        break;
      case 'expired':
        status = PaymentStatus.expired;
        break;
      default:
        status = PaymentStatus.pending;
    }

    return OrderPayment(
      orderCode: json['orderCode'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      status: status,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      overpaid: json['overpaid'] ?? false,
      notes: json['notes'] ?? '',
      actualPaidAmount: (json['actualPaidAmount'] ?? 0.0).toDouble(),
      bankAccount: json['bankAccount']?.toString() ?? '31454997',
      bankName: json['bankName']?.toString() ?? 'ACB',
    );
  }
}
