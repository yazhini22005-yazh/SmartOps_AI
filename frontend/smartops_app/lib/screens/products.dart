
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  // Backend is currently running on port 8001.
  static const String baseUrl = 'http://127.0.0.1:8001';

  List<Map<String, dynamic>> products = [];

  bool isLoading = true;
  bool isAddingProduct = false;

  String? errorMessage;
  String searchQuery = '';

  final TextEditingController searchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchProducts();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // =========================================================
  // FETCH PRODUCTS
  // =========================================================

  Future<void> fetchProducts() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/products'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        final List<dynamic> productList =
            decoded is List
                ? decoded
                : decoded['products'] as List;

        if (!mounted) return;

        setState(() {
          products = productList
              .map(
                (item) =>
                    Map<String, dynamic>.from(item as Map),
              )
              .toList();

          isLoading = false;
        });
      } else {
        throw Exception(
          'Unable to fetch products. '
          'Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  // =========================================================
  // LOW STOCK CHECK
  // =========================================================

  bool isLowStock(Map<String, dynamic> product) {
    final stock =
        int.tryParse('${product['current_stock']}') ?? 0;

    final minimumStock =
        int.tryParse('${product['minimum_stock']}') ?? 0;

    return stock <= minimumStock;
  }

  // =========================================================
  // ADD PRODUCT API
  // =========================================================

  Future<bool> addProduct({
    required String productId,
    required String name,
    required String category,
    required double price,
    required int currentStock,
    required int minimumStock,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/products'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'product_id': productId,
              'name': name,
              'category': category,
              'price': price,
              'current_stock': currentStock,
              'minimum_stock': minimumStock,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        await fetchProducts();
        return true;
      }

      String message = 'Failed to add product.';

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map && decoded['detail'] != null) {
          message = decoded['detail'].toString();
        } else {
          message = response.body;
        }
      } catch (_) {
        message = response.body;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.warning,
          ),
        );
      }

      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: $e'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }

      return false;
    }
  }

  // =========================================================
  // DELETE PRODUCT API
  // =========================================================

  Future<void> deleteProduct(String productId) async {
    try {
      final response = await http
          .delete(
            Uri.parse(
              '$baseUrl/products/'
              '${Uri.encodeComponent(productId)}',
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        await fetchProducts();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Product $productId deleted successfully!',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        String message = 'Failed to delete product.';

        try {
          final decoded = jsonDecode(response.body);

          if (decoded is Map &&
              decoded['detail'] != null) {
            message = decoded['detail'].toString();
          }
        } catch (_) {}

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection error: $e'),
          backgroundColor: AppTheme.warning,
        ),
      );
    }
  }

  // =========================================================
  // DELETE CONFIRMATION
  // =========================================================

  Future<void> confirmDeleteProduct(
    Map<String, dynamic> product,
  ) async {
    final productId =
        '${product['product_id'] ?? ''}';

    final productName =
        '${product['name'] ?? 'Unknown Product'}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text('Delete Product?'),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete '
            '"$productName" (ID: $productId)?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await deleteProduct(productId);
    }
  }

  // =========================================================
  // ADD PRODUCT DIALOG
  // =========================================================

  Future<void> showAddProductDialog() async {
    final formKey = GlobalKey<FormState>();

    final productIdController = TextEditingController();
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    final minimumStockController =
        TextEditingController(text: '10');

    bool dialogIsSubmitting = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: AppTheme.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Icon(
                      Icons.add_box_rounded,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Add New Product',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildInput(
                            controller: productIdController,
                            label: 'Product ID',
                            hint: 'Example: P100',
                            icon: Icons.qr_code_rounded,
                          ),
                          const SizedBox(height: 14),
                          _buildInput(
                            controller: nameController,
                            label: 'Product Name',
                            hint: 'Example: Wireless Keyboard',
                            icon: Icons.inventory_2_outlined,
                          ),
                          const SizedBox(height: 14),
                          _buildInput(
                            controller: categoryController,
                            label: 'Category',
                            hint: 'Example: Electronics',
                            icon: Icons.category_outlined,
                          ),
                          const SizedBox(height: 14),
                          _buildInput(
                            controller: priceController,
                            label: 'Price (₹)',
                            hint: 'Example: 1500',
                            icon: Icons.currency_rupee_rounded,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (value) {
                              final price = double.tryParse(
                                value?.trim() ?? '',
                              );

                              if (price == null ||
                                  !price.isFinite ||
                                  price < 0) {
                                return 'Enter a valid price';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildInput(
                            controller: stockController,
                            label: 'Current Stock',
                            hint: 'Example: 20',
                            icon: Icons.warehouse_outlined,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final stock = int.tryParse(
                                value?.trim() ?? '',
                              );

                              if (stock == null || stock < 0) {
                                return 'Enter a valid stock quantity';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildInput(
                            controller: minimumStockController,
                            label: 'Minimum Stock Alert',
                            hint: 'Example: 10',
                            icon:
                                Icons.notifications_active_outlined,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final stock = int.tryParse(
                                value?.trim() ?? '',
                              );

                              if (stock == null || stock < 0) {
                                return 'Enter a valid minimum stock';
                              }

                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: dialogIsSubmitting
                        ? null
                        : () {
                            Navigator.pop(dialogContext);
                          },
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    onPressed: dialogIsSubmitting
                        ? null
                        : () async {
                            if (!formKey.currentState!
                                .validate()) {
                              return;
                            }

                            setDialogState(() {
                              dialogIsSubmitting = true;
                            });

                            if (mounted) {
                              setState(() {
                                isAddingProduct = true;
                              });
                            }

                            final success = await addProduct(
                              productId:
                                  productIdController.text.trim(),
                              name: nameController.text.trim(),
                              category:
                                  categoryController.text.trim(),
                              price: double.parse(
                                priceController.text.trim(),
                              ),
                              currentStock: int.parse(
                                stockController.text.trim(),
                              ),
                              minimumStock: int.parse(
                                minimumStockController.text.trim(),
                              ),
                            );

                            if (mounted) {
                              setState(() {
                                isAddingProduct = false;
                              });
                            }

                            if (!dialogContext.mounted) return;

                            if (success) {
                              Navigator.pop(dialogContext);

                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Product added successfully!',
                                    ),
                                    backgroundColor:
                                        AppTheme.success,
                                  ),
                                );
                              }
                            } else {
                              setDialogState(() {
                                dialogIsSubmitting = false;
                              });
                            }
                          },
                    icon: dialogIsSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_rounded),
                    label: Text(
                      dialogIsSubmitting
                          ? 'Adding...'
                          : 'Add Product',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      productIdController.dispose();
      nameController.dispose();
      categoryController.dispose();
      priceController.dispose();
      stockController.dispose();
      minimumStockController.dispose();
    }
  }

  // =========================================================
  // REUSABLE INPUT FIELD
  // =========================================================

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return '$label is required';
            }

            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: AppTheme.primary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.primary.withOpacity(0.25),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // SEARCH PRODUCTS
  // =========================================================

  List<Map<String, dynamic>> get filteredProducts {
    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return products;
    }

    return products.where((product) {
      final id =
          '${product['product_id'] ?? ''}'.toLowerCase();

      final name =
          '${product['name'] ?? ''}'.toLowerCase();

      final category =
          '${product['category'] ?? ''}'.toLowerCase();

      return id.contains(query) ||
          name.contains(query) ||
          category.contains(query);
    }).toList();
  }

  // =========================================================
  // PRODUCT CARD
  // =========================================================

  Widget buildProductCard(
    Map<String, dynamic> product,
  ) {
    final lowStock = isLowStock(product);

    final name =
        '${product['name'] ?? 'Unknown Product'}';

    final id = '${product['product_id'] ?? '-'}';

    final category =
        '${product['category'] ?? 'General'}';

    final price =
        double.tryParse('${product['price']}') ?? 0;

    final stock =
        int.tryParse('${product['current_stock']}') ?? 0;

    final minimumStock =
        int.tryParse('${product['minimum_stock']}') ?? 0;

    return Card(
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: lowStock
              ? AppTheme.warning.withOpacity(0.45)
              : AppTheme.primary.withOpacity(0.10),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: AppTheme.primary,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 5),
                      Text(
                        '$id • $category',
                        style: TextStyle(
                          color: AppTheme.text.withOpacity(0.65),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: lowStock
                          ? AppTheme.warning.withOpacity(0.12)
                          : AppTheme.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      lowStock ? 'Low Stock' : 'In Stock',
                      style: TextStyle(
                        color: lowStock
                            ? AppTheme.warning
                            : AppTheme.success,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete Product',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  onPressed: () =>
                      confirmDeleteProduct(product),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _productInfo(
                    'Price',
                    '₹${price.toStringAsFixed(2)}',
                    Icons.currency_rupee_rounded,
                  ),
                ),
                Expanded(
                  child: _productInfo(
                    'Current Stock',
                    '$stock units',
                    Icons.warehouse_outlined,
                  ),
                ),
                Expanded(
                  child: _productInfo(
                    'Minimum',
                    '$minimumStock units',
                    Icons.notifications_none_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // PRODUCT INFORMATION
  // =========================================================

  Widget _productInfo(
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: AppTheme.primary,
          size: 17,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.text.withOpacity(0.60),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.text,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // SUMMARY CARD
  // =========================================================

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 25,
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: TextStyle(
                color: AppTheme.text.withOpacity(0.70),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // MAIN UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final lowStockCount =
        products.where(isLowStock).length;

    final visibleProducts = filteredProducts;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Products & Inventory',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.text,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh Products',
            onPressed: isLoading ? null : fetchProducts,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            isAddingProduct ? null : showAddProductDialog,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Product'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: fetchProducts,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              18,
              10,
              18,
              100,
            ),
            children: [
              Text(
                'Manage your inventory',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.text.withOpacity(0.65),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _summaryCard(
                    title: 'Total Products',
                    value: '${products.length}',
                    icon: Icons.inventory_2_rounded,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 12),
                  _summaryCard(
                    title: 'Low Stock Items',
                    value: '$lowStockCount',
                    icon: Icons.warning_amber_rounded,
                    color: AppTheme.warning,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              TextField(
                controller: searchController,
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText:
                      'Search by product name, ID or category',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppTheme.primary,
                  ),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            searchController.clear();

                            setState(() {
                              searchQuery = '';
                            });
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'All Products',
                      style: TextStyle(
                        color: AppTheme.text,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${visibleProducts.length} items',
                    style: TextStyle(
                      color: AppTheme.text.withOpacity(0.60),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        color: AppTheme.warning,
                        size: 42,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Unable to load products',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: fetchProducts,
                        icon: const Icon(
                          Icons.refresh_rounded,
                        ),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              else if (visibleProducts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 50,
                        color: AppTheme.primary.withOpacity(0.60),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        searchQuery.isEmpty
                            ? 'No products found'
                            : 'No matching products',
                        style: TextStyle(
                          color: AppTheme.text,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        searchQuery.isEmpty
                            ? 'Click Add Product to get started.'
                            : 'Try another product name or ID.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.text.withOpacity(0.60),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...visibleProducts.map(buildProductCard),
            ],
          ),
        ),
      ),
    );
  }
}
