import 'package:flutter/material.dart';
import 'products.dart' as products;

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const products.ProductsScreen();
  }
}
