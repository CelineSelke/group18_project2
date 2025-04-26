class StockQuote {
  final String symbol;
  final double currentPrice;
  final double change;
  final double percentChange;
  final double highPrice;
  final double lowPrice;
  final double openPrice;
  final double previousClose;

  StockQuote({
    required this.symbol,
    required this.currentPrice,
    required this.change,
    required this.percentChange,
    required this.highPrice,
    required this.lowPrice,
    required this.openPrice,
    required this.previousClose,
  });

  factory StockQuote.fromJson(Map<String, dynamic> json, String symbol) {
    return StockQuote(
      symbol: symbol,
      currentPrice: json['c']?.toDouble() ?? 0.0,
      change: json['d']?.toDouble() ?? 0.0,
      percentChange: json['dp']?.toDouble() ?? 0.0,
      highPrice: json['h']?.toDouble() ?? 0.0,
      lowPrice: json['l']?.toDouble() ?? 0.0,
      openPrice: json['o']?.toDouble() ?? 0.0,
      previousClose: json['pc']?.toDouble() ?? 0.0,
    );
  }
}