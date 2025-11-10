/// Fapshi Payment Transaction Models
/// 
/// Models for Fapshi payment API responses and status

class FapshiPaymentResponse {
  final String message;
  final String transId;
  final DateTime dateInitiated;

  FapshiPaymentResponse({
    required this.message,
    required this.transId,
    required this.dateInitiated,
  });

  factory FapshiPaymentResponse.fromJson(Map<String, dynamic> json) {
    return FapshiPaymentResponse(
      message: json['message'] as String,
      transId: json['transId'] as String,
      dateInitiated: DateTime.parse(json['dateInitiated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'transId': transId,
      'dateInitiated': dateInitiated.toIso8601String(),
    };
  }
}

class FapshiPaymentStatus {
  final String transId;
  final String status; // 'PENDING', 'SUCCESSFUL', 'FAILED'
  final int amount;
  final DateTime dateInitiated;
  final DateTime? dateCompleted;

  FapshiPaymentStatus({
    required this.transId,
    required this.status,
    required this.amount,
    required this.dateInitiated,
    this.dateCompleted,
  });

  factory FapshiPaymentStatus.fromJson(Map<String, dynamic> json) {
    return FapshiPaymentStatus(
      transId: json['transId'] as String,
      status: json['status'] as String,
      amount: json['amount'] as int,
      dateInitiated: DateTime.parse(json['dateInitiated'] as String),
      dateCompleted: json['dateCompleted'] != null
          ? DateTime.parse(json['dateCompleted'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transId': transId,
      'status': status,
      'amount': amount,
      'dateInitiated': dateInitiated.toIso8601String(),
      'dateCompleted': dateCompleted?.toIso8601String(),
    };
  }

  bool get isPending => status == 'PENDING';
  bool get isSuccessful => status == 'SUCCESSFUL';
  bool get isFailed => status == 'FAILED';
}

