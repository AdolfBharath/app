import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../../../models/shop_item.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/shop_provider.dart';
import '../providers/student_nav_provider.dart';
import '../providers/student_provider.dart';
import '../widgets/student_header_row.dart';
import '../widgets/student_hero_card.dart';
import 'student_notifications_screen.dart';

class StudentShopScreen extends StatefulWidget {
  const StudentShopScreen({super.key});

  @override
  State<StudentShopScreen> createState() => _StudentShopScreenState();
}

class _StudentShopScreenState extends State<StudentShopScreen> {
  int _selectedFilter = 0;
  final _filters = const ['All Items', 'Courses', 'Merchandise'];
  final _searchController = TextEditingController();
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ShopProvider>().fetchShopItems();
      _syncTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (!mounted) return;
        context.read<ShopProvider>().fetchShopItems();
      });
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _buyItem(BuildContext context, ShopItem item) async {
    final scheme = Theme.of(context).colorScheme;
    final student = context.read<StudentProvider>();
    final shop = context.read<ShopProvider>();

    final costCoins = item.price;
    if (costCoins > 0) {
      if (student.coins < costCoins) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Not enough coins. Need $costCoins.'),
            backgroundColor: scheme.error,
          ),
        );
        return;
      }
    }

    try {
      final remainingCoins = await shop.purchaseItem(item.id);
      if (remainingCoins == null) {
        throw Exception(shop.errorMessage ?? 'Purchase failed');
      }

      await student.setCoins(remainingCoins);
      if (!context.mounted) return;

      await shop.fetchShopItems();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchased ${item.name}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final auth = context.watch<AuthProvider>();
    final student = context.watch<StudentProvider>();
    final shop = context.watch<ShopProvider>();
    
    final username = auth.currentUser?.username ?? auth.currentUser?.name ?? 'Student';
    
    // Background color strictly light/pastel as requested
    const bgColor = Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  children: [
                    StudentHeaderRow(
                      onNotificationsTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const StudentNotificationsScreen()),
                      ),
                      onProfileTap: () => context.read<StudentNavProvider>().setIndex(4),
                    ),
                    const SizedBox(height: 20),
                    
                    // ── Search Bar ──────────────────────────
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1A1A1A)),
                        decoration: InputDecoration(
                          hintText: 'Search marketplace...',
                          hintStyle: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF9CA3AF)),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF3B82F6), size: 22),
                          suffixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF0F7FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF3B82F6)),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                    
                    const SizedBox(height: 20),
                    
                    StudentHeroCard(
                      username: username,
                      subtitle: 'Redeem coins for courses & merchandise',
                      coins: student.coins,
                      streakDays: student.streakCount,
                      gender: student.gender,
                      profileImageBytes: student.profileImageBytes,
                    ).animate().fadeIn(duration: 300.ms),
                    
                    const SizedBox(height: 24),

                    // ── Filter chips (Rounded Pills) ──────────────────────────
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) => _ShopFilterChip(
                          label: _filters[i],
                          selected: _selectedFilter == i,
                          onTap: () => setState(() => _selectedFilter = i),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Items List ──────────────────────────
            if (shop.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
              )
            else if (shop.items.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No items found',
                        style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final item = shop.items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _ShopCard(
                          item: item,
                          priceCoins: item.price,
                          index: i,
                          coins: student.coins,
                          onBuy: () => _buyItem(context, item),
                        ),
                      );
                    },
                    childCount: shop.items.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────
class _ShopFilterChip extends StatelessWidget {
  const _ShopFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shop item card (Horizontal Layout) ───────────────────────────────────────
class _ShopCard extends StatefulWidget {
  const _ShopCard({
    required this.item,
    required this.priceCoins,
    required this.index,
    required this.coins,
    required this.onBuy,
  });

  final ShopItem item;
  final int priceCoins;
  final int index;
  final int coins;
  final VoidCallback onBuy;

  @override
  State<_ShopCard> createState() => _ShopCardState();
}

class _ShopCardState extends State<_ShopCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final canAfford = widget.coins >= widget.priceCoins;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onBuy,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.98 : 1.0,
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              // Thumbnail Left
              Hero(
                tag: 'shop_item_${widget.item.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: const Color(0xFFF8FAFF),
                      child: widget.item.imageUrl.isNotEmpty
                          ? _ShopImage(imageUrl: widget.item.imageUrl)
                          : _ShopThumbnailPlaceholder(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Info Right
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.stars_rounded, size: 18, color: LmsAdminTheme.coinGold),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.priceCoins}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: LmsAdminTheme.coinGold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: canAfford
                                ? const LinearGradient(
                                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: canAfford ? null : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            'Redeem',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: canAfford ? Colors.white : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: Duration(milliseconds: widget.index * 60))
        .fadeIn(duration: 400.ms)
        .slideX(begin: 0.1, end: 0);
  }
}

class _ShopImage extends StatelessWidget {
  _ShopImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('data:image/')) {
      final bytes = _decodeDataUrl(imageUrl);
      if (bytes != null && bytes.isNotEmpty) {
        return Image.memory(bytes, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _ShopThumbnailPlaceholder());
      }
      return _ShopThumbnailPlaceholder();
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _ShopThumbnailPlaceholder(),
    );
  }

  Uint8List? _decodeDataUrl(String input) {
    final comma = input.indexOf(',');
    if (comma < 0 || comma + 1 >= input.length) return null;
    try {
      return base64Decode(input.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }
}

class _ShopThumbnailPlaceholder extends StatelessWidget {
  _ShopThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
      child: const Center(
        child: Icon(Icons.shopping_bag_outlined, color: Color(0xFF3B82F6), size: 28),
      ),
    );
  }
}
