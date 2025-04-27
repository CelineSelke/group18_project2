import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/stock_quote.dart';
import '../models/news_article.dart';
import '../models/stock_price.dart';

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
        return StockQuote.fromJson(data, symbol);
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

  static Future<List<NewsArticle>> getNewsForSymbols(List<String> symbols) async {
    try {
      final List<NewsArticle> allNews = [];
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 7));
      
      for (final symbol in symbols) {
        final response = await http.get(
          Uri.parse(
            '$_baseUrl/company-news?symbol=$symbol&'
            'from=${DateFormat('yyyy-MM-dd').format(from)}&'
            'to=${DateFormat('yyyy-MM-dd').format(now)}&token=$_apiKey'
          ),
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          allNews.addAll(data.map((item) => NewsArticle.fromJson(item, symbol)));
        }
      }
      allNews.sort((a, b) => b.date.compareTo(a.date));
      return allNews;
    } catch (e) {
      throw Exception('Failed to load news: $e');
    }
  }

  static Future<List<StockPrice>> getStockChartData(String symbol) async {
    try {
      final response = await http.get(
        Uri.parse('https://finnhub.io/api/v1/quote?symbol=$symbol&token=$_apiKey'),
      );

      if (response.statusCode != 200) {
        throw Exception('API request failed');
      }

      final data = json.decode(response.body);
      final now = DateTime.now();
      final previousClose = data['pc'].toDouble();
      final currentPrice = data['c'].toDouble();
      
      final changePercent = ((currentPrice - previousClose) / previousClose);
      
      List<StockPrice> prices = [];
      for (int i = 4; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        double price = previousClose;

        if (i == 4) price = previousClose * 0.98;
        if (i == 3) price = previousClose * 0.995;
        if (i == 2) price = previousClose;
        if (i == 1) price = (previousClose + currentPrice) / 2;
        if (i == 0) price = currentPrice;
        
        price *= 1 + (changePercent * (i/4));
        
        prices.add(StockPrice(
          date: date,
          close: price,
        ));
      }

      return prices;
    } catch (e) {
      throw Exception('Failed to generate chart data: $e');
    }
  }
}