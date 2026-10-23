import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
static const String baseUrl = 'http://127.0.0.1:8001';

  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> workers = [];

  bool isLoading = true;
  String? errorMessage;

  String selectedStatus = 'All';
  String searchQuery = '';

  final TextEditingController searchController = TextEditingController();

  final List<String> statuses = [
    'All',
    'Pending',
    'Assigned',
    'Out for Delivery',
    'Completed',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/orders')),
        http.get(Uri.parse('$baseUrl/workers')),
      ]).timeout(const Duration(seconds: 15));

      if (responses[0].statusCode != 200) {
        throw Exception('Orders API failed: ${responses[0].statusCode}');
      }

      if (responses[1].statusCode != 200) {
        throw Exception('Workers API failed: ${responses[1].statusCode}');
      }

      final ordersJson = jsonDecode(responses[0].body) as List;
      final workersJson = jsonDecode(responses[1].body) as List;

      final loadedOrders = ordersJson
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      final loadedWorkers = workersJson
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (!mounted) return;

      setState(() {
        orders = loadedOrders;
        workers = loadedWorkers;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load orders. Please check your backend.';
      });

      debugPrint('Orders screen error: $e');
    }
  }

  List<Map<String, dynamic>> get filteredOrders {
    return orders.where((order) {
      final orderId = (order['order_id'] ?? '').toString().toLowerCase();
      final customer =
          (order['customer_name'] ?? '').toString().toLowerCase();
      final location = (order['location'] ?? '').toString().toLowerCase();
      final status = (order['status'] ?? '').toString();

      final matchesSearch = orderId.contains(searchQuery) ||
          customer.contains(searchQuery) ||
          location.contains(searchQuery);

      final matchesStatus =
          selectedStatus == 'All' || status == selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  int get completedCount => orders.where((order) {
        return _status(order) == 'completed';
      }).length;

  int get pendingCount => orders.where((order) {
        final status = _status(order);
        return status == 'pending' ||
            status == 'assigned' ||
            status == 'out for delivery';
      }).length;

  String _status(Map<String, dynamic> order) {
    return (order['status'] ?? '').toString().toLowerCase().trim();
  }

  Color statusColor(String status) {
    switch (status.toLowerCase().trim()) {
      case 'completed':
        return const Color(0xFF16875B);
      case 'assigned':
        return const Color(0xFF6C45B8);
      case 'out for delivery':
        return const Color(0xFF1677C8);
      case 'cancelled':
      case 'canceled':
        return Colors.red;
      default:
        return const Color(0xFFD68B00);
    }
  }

  String _money(dynamic amount) {
    final value = double.tryParse(amount?.toString() ?? '') ?? 0;
    return '₹${value.toStringAsFixed(2)}';
  }

  Future<void> updateOrderStatus(
    Map<String, dynamic> order,
    String newStatus,
  ) async {
    final orderId = order['order_id']?.toString();

    if (orderId == null || orderId.isEmpty) {
      _showMessage('Order ID is missing.');
      return;
    }

    try {
      final uri = Uri.parse(
        '$baseUrl/orders/${Uri.encodeComponent(orderId)}/status',
      ).replace(
        queryParameters: {'status': newStatus},
      );

      final response = await http.put(uri).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showMessage('Order status updated to $newStatus');
        await loadData();
      } else {
        _showMessage(
          'Status update failed (${response.statusCode}). '
          'Check the API request format in Swagger.',
        );
      }
    } catch (e) {
      _showMessage('Unable to update status. Check backend connection.');
      debugPrint('Update order status error: $e');
    }
  }

  Future<void> assignWorker(
    Map<String, dynamic> order,
    Map<String, dynamic> worker,
  ) async {
    final orderId = order['order_id']?.toString();
    final workerId = worker['worker_id']?.toString();

    if (orderId == null ||
        orderId.isEmpty ||
        workerId == null ||
        workerId.isEmpty) {
      _showMessage('Order ID or worker ID is missing.');
      return;
    }

    try {
      final uri = Uri.parse(
        '$baseUrl/orders/${Uri.encodeComponent(orderId)}/assign',
      ).replace(
        queryParameters: {'worker_id': workerId},
      );

      final response = await http.put(uri).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showMessage('Worker ${worker['name']} assigned successfully.');
        await loadData();
      } else {
        _showMessage(
          'Worker assignment failed (${response.statusCode}). '
          'Check the API request format in Swagger.',
        );
      }
    } catch (e) {
      _showMessage('Unable to assign worker. Check backend connection.');
      debugPrint('Assign worker error: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void showOrderDetails(Map<String, dynamic> order) {
    final status = (order['status'] ?? 'Pending').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Order Details',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (order['order_id'] ?? 'Unknown order').toString(),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _detailRow(
                    'Customer',
                    (order['customer_name'] ?? 'N/A').toString(),
                  ),
                  _detailRow(
                    'Address',
                    (order['delivery_address'] ?? 'N/A').toString(),
                  ),
                  _detailRow(
                    'Location',
                    (order['location'] ?? 'N/A').toString(),
                  ),
                  _detailRow(
                    'Marketplace',
                    (order['marketplace'] ?? 'N/A').toString(),
                  ),
                  _detailRow(
                    'Amount',
                    _money(order['total_amount']),
                  ),
                  _detailRow(
                    'Assigned Worker',
                    (order['assigned_worker'] ?? 'Not assigned').toString(),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Update Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'Pending',
                      'Assigned',
                      'Out for Delivery',
                      'Completed',
                      'Cancelled',
                    ].map((newStatus) {
                      final isSelected = status == newStatus;

                      return OutlinedButton(
                        onPressed: isSelected
                            ? null
                            : () async {
                                Navigator.pop(sheetContext);
                                await updateOrderStatus(order, newStatus);
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: statusColor(newStatus),
                          side: BorderSide(
                            color: statusColor(newStatus),
                          ),
                        ),
                        child: Text(newStatus),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        showWorkerPicker(order);
                      },
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Assign Worker'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void showWorkerPicker(Map<String, dynamic> order) {
    final availableWorkers = workers.where((worker) {
      final active = worker['is_active'] != false;
      final status =
          (worker['status'] ?? '').toString().toLowerCase().trim();

      return active && status == 'available';
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(26),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assign Delivery Worker',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Order: ${(order['order_id'] ?? '').toString()}',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 18),
                if (availableWorkers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No available workers found. '
                      'Refresh the page or update worker status.',
                    ),
                  )
                else
                  ...availableWorkers.map((worker) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor:
                            AppTheme.secondary.withOpacity(0.15),
                        child: const Icon(
                          Icons.person_outline,
                          color: AppTheme.secondary,
                        ),
                      ),
                      title: Text(
                        (worker['name'] ?? 'Worker').toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${worker['worker_id'] ?? ''} • '
                        '${worker['location'] ?? 'Location N/A'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await assignWorker(order, worker);
                      },
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleOrders = filteredOrders;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text(
          'Orders Management',
          style: TextStyle(
            color: AppTheme.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadData,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppTheme.text,
            ),
            tooltip: 'Refresh orders',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    'Total Orders',
                    '${orders.length}',
                    Icons.shopping_bag_outlined,
                    AppTheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryCard(
                    'Completed',
                    '$completedCount',
                    Icons.check_circle_outline,
                    AppTheme.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryCard(
                    'Open',
                    '$pendingCount',
                    Icons.pending_actions,
                    AppTheme.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() {
                  searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search order, customer or location...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.secondary.withOpacity(0.20),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.secondary.withOpacity(0.20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: statuses.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final status = statuses[index];
                  final selected = selectedStatus == status;

                  return ChoiceChip(
                    label: Text(status),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        selectedStatus = status;
                      });
                    },
                    selectedColor: AppTheme.secondary.withOpacity(0.20),
                    labelStyle: TextStyle(
                      color: selected ? AppTheme.primary : Colors.black54,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: selected
                          ? AppTheme.secondary
                          : Colors.black12,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(35),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (errorMessage != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 42,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: loadData,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              )
            else if (visibleOrders.isEmpty)
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: AppTheme.secondary,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No orders found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Try changing the search or status filter.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              )
            else
              ...visibleOrders.map(_orderCard),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final status = (order['status'] ?? 'Pending').toString();
    final color = statusColor(status);
    final orderId = (order['order_id'] ?? 'N/A').toString();
    final customer =
        (order['customer_name'] ?? 'Unknown Customer').toString();
    final location = (order['location'] ?? 'Location N/A').toString();
    final worker =
        (order['assigned_worker'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.secondary.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondary.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showOrderDetails(order),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: AppTheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orderId,
                          style: const TextStyle(
                            color: AppTheme.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          customer,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
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
                      color: color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: Colors.black45,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    _money(order['total_amount']),
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 17,
                    color: Colors.black45,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      worker.isEmpty || worker == 'string'
                          ? 'Worker not assigned'
                          : 'Worker: $worker',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Text(
                    'View details',
                    style: TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.chevron_right,
                    size: 17,
                    color: AppTheme.secondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}