import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const GeolocationRosettaApp());
}

class GeolocationRosettaApp extends StatelessWidget {
  const GeolocationRosettaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rosetta Stone Telemetry',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.tealAccent,
      ),
      home: const TrackingDashboardPage(),
    );
  }
}

class TrackingDashboardPage extends StatefulWidget {
  const TrackingDashboardPage({Key? key}) : super(key: key);

  @override
  State<TrackingDashboardPage> createState() => _TrackingDashboardPageState();
}

class _TrackingDashboardPageState extends State<TrackingDashboardPage> {
  // Replace with 10.0.0.2 for Android Emulator fallback
  final String _wsEndpoint = 'ws://localhost:8080/ws/tracking/client_dashboard_01';
  late WebSocketChannel _channel;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _establishTelemetryPipeline();
  }

  void _establishTelemetryPipeline() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsEndpoint));
      setState(() {
        _isConnected = true;
      });
    } catch (e) {
      debugPrint('Connection architecture fault: $e');
      setState(() {
        _isConnected = false;
      });
    }
  }

  void _simulateDriverMovement() {
    // Simulates an edge-device sending positioning payloads to the Go Cluster
    final simulatedPayload = {
      "driver_id": "driver_delta_9",
      "latitude": -23.56168 + (0.001 * (DateTime.now().second % 10)),
      "longitude": -46.656139 - (0.001 * (DateTime.now().second % 5)),
      "speed": 45.5 + (DateTime.now().second % 12)
    };

    _channel.sink.add(jsonEncode(simulatedPayload));
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TELEMETRY MATRIX (GO + FLUTTER)'),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          Icon(
            Icons.circle,
            color: _isConnected ? Colors.greenAccent : Colors.redAccent,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'HARDWARE INGESTION CONTROLS',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      ),
                      onPressed: _simulateDriverMovement,
                      icon: const Icon(Icons.g_mobiledata),
                      label: const Text('EMIT VEHICLE TELEMETRY PACKET'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'LIVE REAL-TIME STREAMING DATA',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.tealAccent),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: StreamBuilder(
                  stream: _channel.stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Stream exception structural error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: Text('Awaiting engine telemetry packets...'));
                    }

                    final Map<String, dynamic> data = jsonDecode(snapshot.data.toString());

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildDataRow('DRIVER IDENTIFIER', data['driver_id'].toString()),
                        _buildDataRow('COORDINATE LATITUDE', data['latitude'].toString()),
                        _buildDataRow('COORDINATE LONGITUDE', data['longitude'].toString()),
                        _buildDataRow('COMPUTED VELOCITY', '${data['speed']} KM/H'),
                        const Divider(color: Colors.white24, height: 32),
                        const Center(
                          child: Text(
                            "✓ Frame parsed synchronously via EventLoop",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        )
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      key: ValueKey(label),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.between,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontFamily: 'Courier')),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Courier')),
        ],
      ),
    );
  }
}
