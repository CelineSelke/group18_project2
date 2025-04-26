import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/stock_quote.dart';

class FinnhubService {
  static final String _baseUrl = 'https://finnhub.io/api/v1';
  static final String _apiKey = dotenv.env['FINNHUB_API_KEY']!;

  static Future<StockQuote> getStockQuote(String symbol) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/quote?symbol=$symbol&token=$_apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return StockQuote.fromJson(data, symbol); // Pass symbol here
      } else {
        throw Exception('Failed to load stock data for $symbol');
      }
    } catch (e) {
      throw Exception('Error fetching $symbol: $e');
    }
  }

  static Future<List<StockQuote>> getMultipleStockQuotes(List<String> symbols) async {
    final List<Future<StockQuote>> futures = symbols.map((symbol) => getStockQuote(symbol)).toList();
    return await Future.wait(futures);
  }

  static Future<List<dynamic>> getCompanyNews(String symbol) async {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30)).toIso8601String().split('T')[0];
    final to = now.toIso8601String().split('T')[0];

    final response = await http.get(
      Uri.parse('$_baseUrl/company-news?symbol=$symbol&from=$from&to=$to&token=$_apiKey'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load company news');
    }
  }
}