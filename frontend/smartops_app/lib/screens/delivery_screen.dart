import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  static const String baseUrl = 'http://127.0.0.1:8001';

  final FlutterTts _tts = FlutterTts();

  List<Map<String, dynamic>> _workers = [];
  List<Map<String, dynamic>> _orders = [];

  String? _selectedWorkerId;
  String? _selectedOrderId;

  bool _loading = true;
  bool _processing = false;
  bool _speaking = false;

  String? _errorMessage;

  // ---------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _loadData();
  }

  Future<void> _initializeTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        if (mounted) {
          setState(() => _speaking = true);
        }
      });

      _tts.setCompletionHandler(() {
        if (mounted) {
          setState(() => _speaking = false);
        }
      });

      _tts.setCancelHandler(() {
        if (mounted) {
          setState(() => _speaking = false);
        }
      });

      _tts.setErrorHandler((message) {
        if (mounted) {
          setState(() => _speaking = false);
        }
      });
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  // ---------------------------------------------------------
  // LOAD WORKERS AND ORDERS
  // ---------------------------------------------------------

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/workers')),
        http.get(Uri.parse('$baseUrl/orders')),
      ]).timeout(const Duration(seconds: 20));

      if (responses[0].statusCode != 200) {
        throw Exception(
          'Unable to load workers. HTTP ${responses[0].statusCode}',
        );
      }

      if (responses[1].statusCode != 200) {
        throw Exception(
          'Unable to load orders. HTTP ${responses[1].statusCode}',
        );
      }

      final workerData = jsonDecode(responses[0].body);
      final orderData = jsonDecode(responses[1].body);

      if (workerData is! List || orderData is! List) {
        throw Exception('Unexpected data received from the server.');
      }

      final workers = workerData
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((worker) => worker['is_active'] != false)
          .toList();

      final orders = orderData
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((order) => order['is_active'] != false)
          .toList();

      if (!mounted) return;

      setState(() {
        _workers = workers;
        _orders = orders;

        final workerExists = workers.any(
          (worker) =>
              worker['worker_id']?.toString() == _selectedWorkerId,
        );

        if (!workerExists) {
          _selectedWorkerId = workers.isNotEmpty
              ? workers.first['worker_id']?.toString()
              : null;
        }

        _syncSelectedOrder();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'Unable to connect to the backend.\n'
            'Please check whether the API is running on port 8001.\n\n'
            '$e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ---------------------------------------------------------
  // FILTER ORDERS ASSIGNED TO SELECTED WORKER
  // ---------------------------------------------------------

  List<Map<String, dynamic>> get _assignedOrders {
    if (_selectedWorkerId == null) return [];

    final orders = _orders.where((order) {
      final assignedWorker = order['assigned_worker']?.toString();
      final status = order['status']?.toString().toLowerCase();

      return assignedWorker == _selectedWorkerId &&
          status != 'completed' &&
          status != 'cancelled' &&
          status != 'canceled' &&
          status != 'failed';
    }).toList();

    // Put orders already out for delivery before other orders.
    orders.sort((a, b) {
      final aOut =
          a['status']?.toString().toLowerCase() == 'out for delivery';
      final bOut =
          b['status']?.toString().toLowerCase() == 'out for delivery';

      if (aOut && !bOut) return -1;
      if (!aOut && bOut) return 1;

      return 0;
    });

    return orders;
  }

  Map<String, dynamic>? get _currentOrder {
    for (final order in _assignedOrders) {
      if (order['order_id']?.toString() == _selectedOrderId) {
        return order;
      }
    }

    return null;
  }

  void _syncSelectedOrder() {
    final assigned = _assignedOrders;

    if (assigned.isEmpty) {
      _selectedOrderId = null;
      return;
    }

    final selectedExists = assigned.any(
      (order) => order['order_id']?.toString() == _selectedOrderId,
    );

    if (!selectedExists) {
      _selectedOrderId = assigned.first['order_id']?.toString();
    }
  }

  // ---------------------------------------------------------
  // SELECT WORKER
  // ---------------------------------------------------------

  Future<void> _selectWorker(String? workerId) async {
    if (workerId == null) return;

    await _tts.stop();

    if (!mounted) return;

    setState(() {
      _selectedWorkerId = workerId;
      _syncSelectedOrder();
    });
  }

  // ---------------------------------------------------------
  // VOICE INSTRUCTIONS
  // ---------------------------------------------------------

  Future<void> _speak(String message) async {
    try {
      await _tts.stop();
      await _tts.speak(message);
    } catch (e) {
      debugPrint('Speech error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice unavailable. Please check browser audio settings.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _announceCurrentOrder() async {
    final order = _currentOrder;

    if (order == null) {
      await _speak('There are no pending deliveries assigned to this worker.');
      return;
    }

    final orderId = order['order_id'] ?? 'Unknown order';
    final customer = order['customer_name'] ?? 'Unknown customer';
    final address = _destination(order);

    await _speak(
      'Delivery instructions. '
      'Order number $orderId. '
      'Customer name $customer. '
      'Delivery address $address. '
      'Please proceed to the delivery location.',
    );
  }

  // ---------------------------------------------------------
  // GOOGLE MAPS NAVIGATION
  // ---------------------------------------------------------

  String _destination(Map<String, dynamic> order) {
    final address = order['delivery_address']?.toString() ?? '';
    final location = order['location']?.toString() ?? '';

    if (address.trim().isEmpty) {
      return location.trim().isEmpty ? 'Address unavailable' : location;
    }

    if (location.trim().isEmpty ||
        location.trim().toLowerCase() == address.trim().toLowerCase()) {
      return address;
    }

    return '$address, $location';
  }

  Future<void> _openMaps() async {
    final order = _currentOrder;

    if (order == null) return;

    final destination = _destination(order);

    if (destination == 'Address unavailable') {
      _showMessage('This order does not have a delivery address.');
      return;
    }

    final uri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      {
        'api': '1',
        'destination': destination,
      },
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );

      if (!launched && mounted) {
        _showMessage('Unable to open Google Maps.');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Could not open navigation: $e');
      }
    }
  }

  // ---------------------------------------------------------
  // UPDATE ORDER STATUS
  // ---------------------------------------------------------

  Future<void> _updateOrderStatus(
    Map<String, dynamic> order,
    String newStatus,
  ) async {
    if (_processing) return;

    final orderId = order['order_id']?.toString();

    if (orderId == null || orderId.isEmpty) {
      _showMessage('Invalid order ID.');
      return;
    }

    setState(() => _processing = true);

    try {
      final response = await http
          .put(
            Uri.parse(
              '$baseUrl/orders/${Uri.encodeComponent(orderId)}/status',
            ),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'status': newStatus,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        String details = response.body;

        try {
          final decoded = jsonDecode(response.body);

          if (decoded is Map && decoded['detail'] != null) {
            details = decoded['detail'].toString();
          }
        } catch (_) {
          // Keep the original response body.
        }

        throw Exception(details);
      }

      if (newStatus == 'Out for Delivery') {
        await _loadData();

        if (!mounted) return;

        _showMessage('Order $orderId started successfully.');

        await _announceCurrentOrder();
      } else if (newStatus == 'Completed') {
        // Update the local list immediately after successful completion.
        if (!mounted) return;

        setState(() {
          final index = _orders.indexWhere(
            (item) => item['order_id']?.toString() == orderId,
          );

          if (index != -1) {
            _orders[index]['status'] = 'Completed';
          }

          _syncSelectedOrder();
        });

        _showMessage('Order $orderId completed successfully.');

        final nextOrder = _currentOrder;

        if (nextOrder != null) {
          await _speak(
            'Delivery completed successfully. '
            'Proceeding to your next assigned order.',
          );

          if (!mounted) return;

          await _announceCurrentOrder();
        } else {
          await _handleAllDeliveriesCompleted();
        }

        // Reload backend data after local state has been updated.
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Failed to update order: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  // ---------------------------------------------------------
  // MARK WORKER AVAILABLE WHEN ALL DELIVERIES ARE COMPLETED
  // ---------------------------------------------------------

  Future<void> _handleAllDeliveriesCompleted() async {
    final workerId = _selectedWorkerId;

    if (workerId == null) return;

    try {
      final response = await http
          .put(
            Uri.parse(
              '$baseUrl/workers/${Uri.encodeComponent(workerId)}/status',
            ),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'status': 'Available',
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception(
          'Worker status update failed: HTTP ${response.statusCode}',
        );
      }

      if (!mounted) return;

      setState(() {
        final index = _workers.indexWhere(
          (worker) => worker['worker_id']?.toString() == workerId,
        );

        if (index != -1) {
          _workers[index]['status'] = 'Available';
        }
      });

      await _speak(
        'All assigned deliveries are completed. '
        'Worker status is now available. Great job.',
      );

      if (mounted) {
        _showMessage(
          'All deliveries completed. Worker is now Available.',
        );
      }
    } catch (e) {
      debugPrint('Worker availability update failed: $e');

      if (mounted) {
        _showMessage(
          'All deliveries completed, but worker status could not be updated. '
          'Please check the backend.',
        );
      }
    }
  }

  // ---------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Map<String, dynamic>? get _selectedWorker {
    for (final worker in _workers) {
      if (worker['worker_id']?.toString() == _selectedWorkerId) {
        return worker;
      }
    }

    return null;
  }

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'out for delivery':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'pending':
        return Colors.grey;
      case 'failed':
      case 'cancelled':
        return Colors.red;
      default:
        return AppTheme.primary;
    }
  }

  // ---------------------------------------------------------
  // BUILD UI
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Voice-Guided Delivery',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadData,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: _buildContent(),
                ),
    );
  }

  // ---------------------------------------------------------
  // ERROR SCREEN
  // ---------------------------------------------------------

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 64,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            const Text(
              'Connection Error',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to connect.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // MAIN CONTENT
  // ---------------------------------------------------------

  Widget _buildContent() {
    final worker = _selectedWorker;
    final assigned = _assignedOrders;
    final order = _currentOrder;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        _buildHeader(),
        const SizedBox(height: 20),

        _buildWorkerSelector(),
        const SizedBox(height: 20),

        if (worker != null) _buildWorkerInfo(worker),

        const SizedBox(height: 20),

        _buildStats(assigned.length),

        const SizedBox(height: 24),

        const Text(
          'Assigned Deliveries',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        if (_workers.isEmpty)
          _buildEmptyState(
            Icons.person_off_outlined,
            'No workers found',
            'Add a worker in Worker Management first.',
          )
        else if (assigned.isEmpty)
          _buildEmptyState(
            Icons.task_alt,
            'No open deliveries',
            'This worker has no pending assigned orders.',
          )
        else ...[
          ...assigned.map(_buildOrderCard),
          const SizedBox(height: 20),
          if (order != null) _buildSelectedOrder(order),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  // ---------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary,
            AppTheme.primary.withValues(alpha: 0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.local_shipping_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Delivery Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Voice instructions • Live order status • Navigation',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // WORKER SELECTOR
  // ---------------------------------------------------------

  Widget _buildWorkerSelector() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Delivery Worker',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedWorkerId,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFC),
            ),
            hint: const Text('Choose a worker'),
            items: _workers.map((worker) {
              final id = worker['worker_id']?.toString() ?? '';
              final name = worker['name']?.toString() ?? 'Unknown';

              return DropdownMenuItem<String>(
                value: id,
                child: Text(
                  '$name ($id)',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: _processing ? null : _selectWorker,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // WORKER INFORMATION
  // ---------------------------------------------------------

  Widget _buildWorkerInfo(Map<String, dynamic> worker) {
    final name = worker['name']?.toString() ?? 'Unknown';
    final status = worker['status']?.toString() ?? 'Unknown';
    final phone = worker['phone']?.toString() ?? 'Not available';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: Icon(
              Icons.delivery_dining,
              color: AppTheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phone,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: status.toLowerCase() == 'available'
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: status.toLowerCase() == 'available'
                    ? Colors.green.shade700
                    : Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // STATISTICS
  // ---------------------------------------------------------

  Widget _buildStats(int count) {
    final completedCount = _orders.where((order) {
      return order['assigned_worker']?.toString() == _selectedWorkerId &&
          order['status']?.toString().toLowerCase() == 'completed';
    }).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Open Orders',
            count.toString(),
            Icons.inventory_2_outlined,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Completed',
            completedCount.toString(),
            Icons.task_alt,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // ORDER CARD
  // ---------------------------------------------------------

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['order_id']?.toString() ?? '';
    final customer = order['customer_name']?.toString() ?? 'Unknown';
    final status = order['status']?.toString() ?? 'Pending';
    final selected = orderId == _selectedOrderId;

    return GestureDetector(
      onTap: _processing
          ? null
          : () {
              setState(() => _selectedOrderId = orderId);
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orderId,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(customer),
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: _statusColor(status),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppTheme.primary : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // SELECTED ORDER DETAILS AND ACTIONS
  // ---------------------------------------------------------

  Widget _buildSelectedOrder(Map<String, dynamic> order) {
    final orderId = order['order_id']?.toString() ?? '';
    final customer = order['customer_name']?.toString() ?? 'Unknown';
    final address = _destination(order);
    final status = order['status']?.toString() ?? 'Pending';

    final isOutForDelivery =
        status.toLowerCase() == 'out for delivery';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Instructions',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          _buildDetailRow(
            Icons.receipt_long,
            'Order ID',
            orderId,
          ),

          const SizedBox(height: 16),

          _buildDetailRow(
            Icons.person_outline,
            'Customer',
            customer,
          ),

          const SizedBox(height: 16),

          _buildDetailRow(
            Icons.location_on_outlined,
            'Delivery Address',
            address,
          ),

          const SizedBox(height: 16),

          _buildDetailRow(
            Icons.info_outline,
            'Current Status',
            status,
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _processing ? null : _announceCurrentOrder,
              icon: Icon(
                _speaking ? Icons.volume_up : Icons.record_voice_over,
              ),
              label: Text(
                _speaking
                    ? 'Repeat Instructions'
                    : 'Speak Delivery Instructions',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                foregroundColor: AppTheme.primary,
                side: BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _processing ? null : _openMaps,
              icon: const Icon(Icons.navigation_outlined),
              label: const Text('Navigate with Google Maps'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (!isOutForDelivery)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _processing
                    ? null
                    : () => _updateOrderStatus(
                          order,
                          'Out for Delivery',
                        ),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Start Delivery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          if (!isOutForDelivery) const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _processing
                  ? null
                  : () => _confirmCompletion(order),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Complete Delivery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          if (_processing) ...[
            const SizedBox(height: 20),
            const Center(
              child: CircularProgressIndicator(),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('Updating delivery status...'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: AppTheme.primary,
          size: 23,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // CONFIRM DELIVERY COMPLETION
  // ---------------------------------------------------------

  Future<void> _confirmCompletion(
    Map<String, dynamic> order,
  ) async {
    final orderId = order['order_id']?.toString() ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Complete Delivery?'),
          content: Text(
            'Confirm that order $orderId has been delivered successfully.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _updateOrderStatus(order, 'Completed');
    }
  }

  // ---------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------

  Widget _buildEmptyState(
    IconData icon,
    String title,
    String description,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 55,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}