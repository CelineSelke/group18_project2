import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/finnhub_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models/stock_quote.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await dotenv.load(fileName: ".env");
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData.dark(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData) {
          return LoginPage(auth: FirebaseAuth.instance);
        }
        return const MainWrapper();
      },
    );
  }
}

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    NewsPage(),
    WatchList(),
    StockChart(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: _buildFooter(),
    );
  }

  Widget _buildFooter() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      type: BottomNavigationBarType.fixed,
      backgroundColor: const Color(0xFF223055),
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.article),
          label: 'News',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bookmark),
          label: 'Watchlist',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.show_chart),
          label: 'Charts',
        ),
      ],
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<String> _symbols = ['AAPL', 'GOOGL', 'MSFT', 'NVDA', 'BTC', 'ETH', 'SHEL', 'XOM', 'CVX'];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Future<List<StockQuote>> _futureStockQuotes;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;
  late Stream<DocumentSnapshot> _watchlistStream;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _futureStockQuotes = FinnhubService.getMultipleStockQuotes(_symbols);
    _watchlistStream = _firestore.collection('watchlists')
      .doc(_auth.currentUser?.uid)
      .snapshots();
  }

  Future<void> _toggleWatchlist(String symbol) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('watchlists').doc(user.uid);
    final doc = await docRef.get();

    if (doc.exists && (doc.data()?['symbols'] ?? []).contains(symbol)) {
      await docRef.update({
        'symbols': FieldValue.arrayRemove([symbol])
      });
    } else {
      await docRef.set({
        'symbols': FieldValue.arrayUnion([symbol])
      }, SetOptions(merge: true));
    }
  }

  void _signOut() async {
    await _auth.signOut();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Signed out successfully'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF592248),
        title: Text("Top Stocks"),
        actions: <Widget>[
          IconButton(
            onPressed: _signOut,
            icon: Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<List<StockQuote>>(
        future: _futureStockQuotes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text(
              'Error loading data\n${snapshot.error}',
              textAlign: TextAlign.center,
            ));
          }

          final quotes = snapshot.data ?? [];
          if (quotes.isEmpty) {
            return const Center(child: Text('No stock data available'));
          }
          final searchQuery = _searchController.text.toLowerCase();
          final filteredQuotes = quotes.where((quote) {
            return quote.symbol.toLowerCase().contains(searchQuery);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                child: SizedBox(
                  width: 375,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search stock symbols...',
                      hintStyle: TextStyle(fontSize: 14),
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                    style: TextStyle(fontSize: 14),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Showing ${filteredQuotes.length} of ${quotes.length} stocks',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: _watchlistStream,
                  builder: (context, watchlistSnapshot) {
                    final List<String> watchlist = ((watchlistSnapshot.data?.data() 
                      as Map<String, dynamic>?)?['symbols'] as List<dynamic>? ?? [])
                      .map((e) => e.toString())
                      .toList();
                    
                    return ListView.builder(
                      itemCount: filteredQuotes.length,
                      itemBuilder: (context, index) {
                        final quote = filteredQuotes[index];
                        final isAdded = watchlist.contains(quote.symbol);

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          child: ListTile(
                            title: Text(quote.symbol),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current: \$${quote.currentPrice.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                IconButton(
                                  icon: Icon(
                                    isAdded ? Icons.bookmark : Icons.bookmark_border,
                                  ),
                                  onPressed: () => _toggleWatchlist(quote.symbol),
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${quote.change.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: quote.change >= 0 ? Colors.green : Colors.red,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '(${quote.percentChange.toStringAsFixed(2)}%)',
                                  style: TextStyle(
                                    color: quote.change >= 0 ? Colors.green : Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }
                ),
              ),
            ]
          );
        }
      ),
    );
  }
}

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  void _signOut() async {
    await _auth.signOut();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Signed out successfully'),
    ));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF592248),
        title: Text('News'),
        actions: <Widget>[
          IconButton(
            onPressed: _signOut,
            icon: Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
          ],
        ),
      ),
    );
  }
}

class WatchList extends StatefulWidget {
  const WatchList({super.key});

  @override
  State<WatchList> createState() => _WatchListState();
}

class _WatchListState extends State<WatchList> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;
  final List<String> _tech = ['AAPL', 'GOOGL', 'MSFT', 'NVDA'];
  final List<String> _crypto = ['BTC', 'ETH'];
  final List<String> _energy = ['SHEL', 'XOM', 'CVX'];

  Stream<List<String>> get _watchlistStream {
    if (user == null) return const Stream.empty();
    return _firestore.collection('watchlists').doc(user!.uid)
      .snapshots()
      .map((snap) => List<String>.from(snap.data()?['symbols'] ?? []));
  }

  Future<void> _removeWatchlist(String symbol) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('watchlists').doc(user.uid);
    final doc = await docRef.get();

    if (doc.exists) {
      await docRef.update({
        'symbols': FieldValue.arrayRemove([symbol])
      });
    }
  }

  void _signOut() async {
    await _auth.signOut();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Signed out successfully'),
    ));
  }

  Widget _buildCategorySection(String title, List<String> categorySymbols, List<String> watchlist) {
    final symbolsInCategory = categorySymbols.where((symbol) => watchlist.contains(symbol)).toList();
    
    if (symbolsInCategory.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: symbolsInCategory.length,
          itemBuilder: (context, index) {
            final symbol = symbolsInCategory[index];
            return Dismissible(
              key: Key(symbol),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) => _removeWatchlist(symbol),
              child: FutureBuilder<StockQuote>(
                future: FinnhubService.getStockQuote(symbol),
                builder: (context, quoteSnapshot) {
                  final quote = quoteSnapshot.data;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    child: ListTile(
                      title: Text(
                        symbol,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      subtitle: quote != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Price: \$${quote.currentPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                Text(
                                  'Change: ${quote.change.toStringAsFixed(2)} '
                                  '(${quote.percentChange.toStringAsFixed(2)}%)',
                                  style: TextStyle(
                                    color: quote.change >= 0
                                        ? Colors.green
                                        : Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            )
                          : const Text('Loading stock data...'),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.red),
                        onPressed: () => _removeWatchlist(symbol),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF592248),
        title: const Text('Watchlist'),
        actions: <Widget>[
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<List<String>>(
        stream: _watchlistStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final watchlist = snapshot.data ?? [];

          if (watchlist.isEmpty) {
            return const Center(
              child: Text(
                'No symbols in your watchlist\nAdd some in the Home Page.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildCategorySection('Technology Stocks', _tech, watchlist),
                _buildCategorySection('Cryptocurrencies', _crypto, watchlist),
                _buildCategorySection('Energy Stocks', _energy, watchlist),
              ],
            ),
          );
        },
      ),
    );
  }
}

class StockChart extends StatefulWidget {
  const StockChart({super.key});

  @override
  State<StockChart> createState() => _StockChartState();
}

class _StockChartState extends State<StockChart> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  void _signOut() async {
    await _auth.signOut();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Signed out successfully'),
    ));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF592248),
        title: Text('Stock Charts'),
        actions: <Widget>[
          IconButton(
            onPressed: _signOut,
            icon: Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
          ],
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  LoginPage({Key? key, required this.auth}) : super(key: key);
  final FirebaseAuth auth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _success = false;
  bool _initialState = true;
  String? _userEmail;

  void _signInWithEmailAndPassword() async {
    try {
      await widget.auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      setState(() {
        _success = true;
        _userEmail = _emailController.text;
        _initialState = false;
      });

      if (mounted) {
        Navigator.popUntil(context, ModalRoute.withName('/'));
      }
      
    } catch (e) {
      setState(() {
        _success = false;
        _initialState = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF592248),
        title: const Text('Login'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value?.isEmpty ?? true 
                    ? 'Please enter your email'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock)),
                obscureText: true,
                validator: (value) => value?.isEmpty ?? true
                    ? 'Please enter your password'
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _signInWithEmailAndPassword,
                child: const Text('Sign In'),
              ),
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _initialState
                      ? 'Please sign in'
                      : _success
                      ? 'Successfully signed in $_userEmail'
                      : 'Sign in failed',
                  style: TextStyle(color: _success ? Colors.green : Colors.red),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => RegisterPage(auth: FirebaseAuth.instance),
                  ));
                },
                child: const Text('Create new account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  RegisterPage({Key? key, required this.auth}) : super(key: key);
  final FirebaseAuth auth;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  bool _success = false;
  bool _initialState = true;
  String? _userEmail;

  void _register() async {
    try {
      await widget.auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      setState(() {
        _success = true;
        _userEmail = _emailController.text;
        _initialState = false;
      });

      if (mounted) {
        Navigator.popUntil(context, ModalRoute.withName('/'));
      }

    } catch (e) {
      setState(() {
        _success = false;
        _initialState = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF592248),
        title: const Text('Register'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  else if (!emailRegex.hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
              },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock)),
                obscureText: true,
                validator: (value) {
                  if(value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  else if (value.length < 6) {
                    return 'Please enter at least 6 characters';
                  }
                  return null;
                }
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _register,
                child: const Text('Register'),
              ),
              Container(
                alignment: Alignment.center,
                child: Text(
                  _initialState
                      ? 'Please Register'
                  : _success
                      ? 'Successfully registered $_userEmail'
                      : 'Registration failed',
                  style: TextStyle(color: _success ? Colors.green : Colors.red),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Login to account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}