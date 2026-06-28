import 'package:flutter/material.dart';
import 'package:curl_impersonate_dart/curl_impersonate_dart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Curl Impersonate Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F15),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E1E26),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController(text: 'https://httpbin.org/headers');
  String _selectedProfile = BrowserProfile.chrome;
  bool _isLoading = false;
  
  // Response details
  int? _statusCode;
  Map<String, String>? _headers;
  String? _body;
  List<String>? _cookies;
  String? _error;
  bool _fallbackMode = false;

  late TabController _tabController;

  final List<Map<String, String>> _profiles = [
    {'name': 'Chrome Desktop (Default)', 'value': BrowserProfile.chrome},
    {'name': 'Chrome Android', 'value': BrowserProfile.chromeAndroid},
    {'name': 'Firefox Desktop', 'value': BrowserProfile.firefox},
    {'name': 'Safari Desktop', 'value': BrowserProfile.safari},
    {'name': 'Safari iOS', 'value': BrowserProfile.safariIos},
    {'name': 'Edge Desktop', 'value': BrowserProfile.edge},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Check if FFI works or falls back
    final tempClient = CurlImpersonateClient();
    _fallbackMode = !tempClient.isNative;
    tempClient.close();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _statusCode = null;
      _headers = null;
      _body = null;
      _cookies = null;
    });

    final client = CurlImpersonateClient(defaultImpersonate: _selectedProfile);

    try {
      final response = await client.request(
        url: _urlController.text.trim(),
        method: 'GET',
      );

      setState(() {
        _statusCode = response.statusCode;
        _headers = response.headers;
        _body = response.body;
        _cookies = response.cookies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Curl Impersonate FFI',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        backgroundColor: const Color(0xFF1E1E26),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _fallbackMode ? Colors.amber.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _fallbackMode ? Colors.amber : Colors.green,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _fallbackMode ? Icons.warning_amber_rounded : Icons.offline_bolt_rounded,
                  color: _fallbackMode ? Colors.amber : Colors.green,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _fallbackMode ? 'HTTP Fallback' : 'Native FFI Active',
                  style: TextStyle(
                    color: _fallbackMode ? Colors.amber : Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Controls Panel
            Card(
              color: const Color(0xFF1E1E26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: 'URL',
                        prefixIcon: const Icon(Icons.link, color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: const Color(0xFF13131A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _selectedProfile,
                            decoration: InputDecoration(
                              labelText: 'Impersonate Browser',
                              prefixIcon: const Icon(Icons.language, color: Colors.grey),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: const Color(0xFF13131A),
                            ),
                            items: _profiles.map((profile) {
                              return DropdownMenuItem<String>(
                                value: profile['value'],
                                child: Text(profile['name']!),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedProfile = val;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 58,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _sendRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Icon(Icons.send_rounded, size: 24),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Warning message if fallback is active and they want to test impersonation
            if (_fallbackMode)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'Note: Impersonation fingerprints require running on iOS or Android. On desktop platforms, requests will fall back to standard HTTP headers.',
                  style: TextStyle(color: Colors.amber, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

            // Tab bar headers
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Body'),
                Tab(text: 'Headers'),
                Tab(text: 'Cookies'),
              ],
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),

            // Results Output
            Expanded(
              child: Card(
                color: const Color(0xFF1E1E26),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _error != null
                      ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
                      : _statusCode == null && !_isLoading
                          ? const Center(child: Text('Submit a request to see results'))
                          : _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : TabBarView(
                                  controller: _tabController,
                                  children: [
                                    // Body Tab
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Status: $_statusCode',
                                              style: TextStyle(
                                                color: _statusCode == 200 ? Colors.green : Colors.redAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              'Size: ${_body?.length ?? 0} chars',
                                              style: const TextStyle(color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 20),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            child: Text(
                                              _body ?? '',
                                              style: const TextStyle(
                                                fontFamily: 'Courier',
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Headers Tab
                                    ListView.builder(
                                      itemCount: _headers?.length ?? 0,
                                      itemBuilder: (context, index) {
                                        final key = _headers!.keys.elementAt(index);
                                        final val = _headers![key];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: RichText(
                                            text: TextSpan(
                                              style: const TextStyle(fontSize: 14),
                                              children: [
                                                TextSpan(
                                                  text: '$key: ',
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: val,
                                                  style: const TextStyle(color: Colors.white70),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    // Cookies Tab
                                    ListView.builder(
                                      itemCount: _cookies?.length ?? 0,
                                      itemBuilder: (context, index) {
                                        final cookieLine = _cookies![index];
                                        return Card(
                                          color: const Color(0xFF13131A),
                                          margin: const EdgeInsets.symmetric(vertical: 4),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Text(
                                              cookieLine,
                                              style: const TextStyle(fontSize: 13, fontFamily: 'Courier'),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
