import 'package:intl/intl.dart';

class NewsArticle {
  final String headline;
  final DateTime date;
  final String symbol;

  NewsArticle({
    required this.headline,
    required this.date,
    required this.symbol,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json, String symbol) {
    return NewsArticle(
      headline: json['headline'] ?? 'No headline available',
      date: DateTime.fromMillisecondsSinceEpoch(json['datetime'] * 1000),
      symbol: symbol,
    );
  }

  String get formattedDate {
    return DateFormat('MMM dd, yyyy – hh:mm a').format(date);
  }
}