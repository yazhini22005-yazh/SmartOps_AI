import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import 'ai_assistant.dart';
import 'orders_screen.dart';
import 'products.dart';
import 'delivery_screen.dart';
class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  static const String baseUrl = 'http://127.0.0.1:8001';
  int totalOrders = 0;
  int completedOrders = 0;
  int pendingOrders = 0;
  int activeWorkers = 0;
  int lowStockProducts = 0;

  List<Map<String, dynamic>> workersData = [];
  List<Map<String, dynamic>> ordersData = [];

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchDashboardSummary();
  }

  Future<void> fetchDashboardSummary() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/dashboard/summary')),
        http.get(Uri.parse('$baseUrl/workers')),
        http.get(Uri.parse('$baseUrl/orders')),
      ]).timeout(const Duration(seconds: 15));

      if (responses[0].statusCode != 200 ||
          responses[1].statusCode != 200 ||
          responses[2].statusCode != 200) {
        throw Exception('Dashboard API request failed.');
      }

      final summary =
          jsonDecode(responses[0].body) as Map<String, dynamic>;

      final workersJson = jsonDecode(responses[1].body) as List;
      final ordersJson = jsonDecode(responses[2].body) as List;

      final workers = workersJson
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      final orders = ordersJson
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (!mounted) return;

      setState(() {
        totalOrders = _asInt(summary['total_orders']);
        completedOrders = _asInt(summary['completed_orders']);
        pendingOrders = _asInt(summary['pending_orders']);
        activeWorkers = _asInt(summary['active_workers']);
        lowStockProducts = _asInt(summary['low_stock_products']);

        workersData = workers;
        ordersData = orders;

        isLoading = false;
      });
    } catch (e) {
      debugPrint('Dashboard API error: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Unable to load data. Please check your backend connection.';
      });
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _getLocationWorkerCount(String location) {
    return workersData.where((worker) {
      return (worker['location'] ?? '').toString().trim() == location &&
          worker['is_active'] != false;
    }).length;
  }

  List<Map<String, dynamic>> _getLocationOrders(String location) {
    return ordersData.where((order) {
      return (order['location'] ?? '').toString().trim() == location &&
          order['is_active'] != false;
    }).toList();
  }

  int _getOpenOrderCount(String location) {
    final locationOrders = _getLocationOrders(location);

    return locationOrders.where((order) {
      final status =
          (order['status'] ?? '').toString().toLowerCase().trim();

      return status != 'completed' &&
          status != 'cancelled' &&
          status != 'canceled';
    }).length;
  }

  List<String> _getLocations() {
    final locations = <String>{};

    for (final worker in workersData) {
      final location = (worker['location'] ?? '').toString().trim();

      if (location.isNotEmpty) {
        locations.add(location);
      }
    }

    for (final order in ordersData) {
      final location = (order['location'] ?? '').toString().trim();

      if (location.isNotEmpty) {
        locations.add(location);
      }
    }

    return locations.toList()..sort();
  }

  String _getInsight() {
    if (isLoading) {
      return 'Loading your latest operations data...';
    }

    if (errorMessage != null) {
      return 'Dashboard data is unavailable. Check the backend.';
    }

    if (lowStockProducts > 0) {
      return '$lowStockProducts product(s) need stock replenishment.';
    }

    if (pendingOrders > 0) {
      return '$pendingOrders order(s) need further processing.';
    }

    return 'Your operations data has been refreshed.';
  }

  void _openOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OrdersScreen(),
      ),
    );
  }
  void _openDelivery() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const DeliveryScreen(),
    ),
  );
  }
  
  void _openProducts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProductsScreen(),
      ),
    );
  }

  void _openAI() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AIAssistant(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,

      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        titleSpacing: 20,

        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppTheme.primary,
                    AppTheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SMARTOPS AI',
                    style: TextStyle(
                      color: AppTheme.text,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Operations Intelligence',
                    style: TextStyle(
                      color: Colors.black45,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Orders',
            onPressed: _openOrders,
            icon: const Icon(
              Icons.shopping_bag_outlined,
              color: AppTheme.text,
            ),
          ),

          IconButton(
            tooltip: 'Products',
            onPressed: _openProducts,
            icon: const Icon(
              Icons.inventory_2_outlined,
              color: AppTheme.text,
            ),
          ),

          IconButton(
            tooltip: 'Refresh Dashboard',
            onPressed: isLoading ? null : fetchDashboardSummary,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppTheme.text,
            ),
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: fetchDashboardSummary,

        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const Text(
                'Good Morning 👋',
                style: TextStyle(
                  color: AppTheme.text,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 7),

              const Text(
                'Here is your operations overview for today.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 22),

              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 18),
                  child: LinearProgressIndicator(),
                ),

              if (errorMessage != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                        ),
                      ),
                      TextButton(
                        onPressed: fetchDashboardSummary,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),

              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;

                  final columns = width > 1000
                      ? 4
                      : width > 550
                          ? 2
                          : 1;

                  const spacing = 14.0;

                  final cardWidth =
                      (width - (spacing * (columns - 1))) / columns;

                  final stats = [
                    _DashboardStat(
                      title: 'Total Orders',
                      value: '$totalOrders',
                      icon: Icons.shopping_bag_outlined,
                      color: AppTheme.accent,
                    ),
                    _DashboardStat(
                      title: 'Completed',
                      value: '$completedOrders',
                      icon: Icons.check_circle_outline,
                      color: AppTheme.success,
                    ),
                    _DashboardStat(
                      title: 'Pending',
                      value: '$pendingOrders',
                      icon: Icons.pending_actions,
                      color: AppTheme.warning,
                    ),
                    _DashboardStat(
                      title: 'Active Workers',
                      value: '$activeWorkers',
                      icon: Icons.people_outline,
                      color: AppTheme.secondary,
                    ),
                  ];

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: stats.map((stat) {
                      return SizedBox(
                        width: cardWidth,
                        child: StatCard(
                          title: stat.title,
                          value: stat.value,
                          icon: stat.icon,
                          iconColor: stat.color,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 28),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(23),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppTheme.primary,
                      AppTheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: AppTheme.text,
                          size: 27,
                        ),
                        SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'AI Operations Insight',
                            style: TextStyle(
                              color: AppTheme.text,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 17),

                    Text(
                      _getInsight(),
                      style: const TextStyle(
                        color: AppTheme.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      '$lowStockProducts low-stock product(s) detected. '
                      '${ordersData.length} order record(s) loaded.',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 18),

                    ElevatedButton.icon(
                      onPressed: _openAI,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Ask AI'),

                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                'Worker Distribution',
                style: TextStyle(
                  color: AppTheme.text,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Worker and order information by location.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: AppTheme.secondary.withOpacity(0.18),
                  ),
                ),

                child: _buildWorkerDistribution(),
              ),

              const SizedBox(height: 30),

              const Text(
                "Today's Operations",
                style: TextStyle(
                  color: AppTheme.text,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              LayoutBuilder(
                builder: (context, constraints) {
                  final lowStockCard = _OperationCard(
                    title: 'Low Stock',
                    value: '$lowStockProducts',
                    subtitle: 'Products needing attention',
                    icon: Icons.inventory_2_outlined,
                    color: AppTheme.warning,
                    onTap: _openProducts,
                  );

                  const forecastCard = _OperationCard(
                    title: 'Tomorrow Forecast',
                    value: 'N/A',
                    subtitle: 'Forecast model not configured',
                    icon: Icons.trending_up_rounded,
                    color: AppTheme.secondary,
                  );

                  if (constraints.maxWidth > 700) {
                    return Row(
                      children: [
                        Expanded(child: lowStockCard),
                        const SizedBox(width: 16),
                        const Expanded(child: forecastCard),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      lowStockCard,
                      const SizedBox(height: 14),
                      forecastCard,
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openOrders,
                  icon: const Icon(Icons.list_alt_rounded),
                  label: const Text('Open Orders Management'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color.fromARGB(255, 117, 9, 249),
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    side: const BorderSide(
                      color: Color.fromARGB(255, 5, 1, 18),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openDelivery,
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Voice-Guided Delivery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  

  Widget _buildWorkerDistribution() {
    if (isLoading && workersData.isEmpty && ordersData.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(15),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final locations = _getLocations();

    if (locations.isEmpty) {
      
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No worker location data available.'),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < locations.length; i++) ...[
          _WorkerLocationRow(
            location: locations[i],
            workers: _getLocationWorkerCount(locations[i]),
            deliveries: _getLocationOrders(locations[i]).length,
            pending: _getOpenOrderCount(locations[i]),
          ),

          if (i < locations.length - 1)
            const Divider(height: 27),
        ],
      ],
    );
  }
}

class _DashboardStat {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _DashboardStat({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _WorkerLocationRow extends StatelessWidget {
  final String location;
  final int workers;
  final int deliveries;
  final int pending;

  const _WorkerLocationRow({
    required this.location,
    required this.workers,
    required this.deliveries,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: AppTheme.secondary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.location_on_outlined,
            color: AppTheme.secondary,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                location,
                style: const TextStyle(
                  color: AppTheme.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                '$workers active workers • $deliveries orders',
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            children: [
              Text(
                '$pending',
                style: const TextStyle(
                  color: AppTheme.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Text(
                'Open',
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OperationCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _OperationCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(19),

      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: color.withOpacity(0.20),
          ),
        ),

        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}