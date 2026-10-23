import 'package:flutter/material.dart';
import 'screens/manager_dashboard.dart';
import 'screens/products.dart';
void main() {
  runApp(const SmartOpsApp());
}

class SmartOpsApp extends StatelessWidget {
  const SmartOpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'SmartOps AI',

      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),

      routes: {
        '/': (context) => const ManagerDashboard(),
        '/products': (context) => const ProductsScreen(),
      },

      initialRoute: '/',
    );
  }
}
