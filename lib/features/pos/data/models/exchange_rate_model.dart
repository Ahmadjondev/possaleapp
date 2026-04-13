import 'package:pos_terminal/features/pos/data/models/parse_helpers.dart';

class ExchangeRateModel {
  final double rate;
  final String? date;

  const ExchangeRateModel({this.rate = 0, this.date});

  factory ExchangeRateModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? json['data'] as Map<String, dynamic>
        : json;
    return ExchangeRateModel(
      rate: parseDouble(data['rate'] ?? data['exchange_rate']),
      date: data['date'] as String?,
    );
  }
}
