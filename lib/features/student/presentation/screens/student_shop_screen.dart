import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../models/shop_item.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/shop_provider.dart';
import '../../../../utils/ui_utils.dart';
import '../../../../widgets/shop_image_thumb.dart';
import '../providers/student_provider.dart';

class StudentShopScreen extends StatefulWidget {
  const StudentShopScreen({super.key});

  @override
  State<StudentShopScreen> createState() => _StudentShopScreenState();
}

class _StudentShopScreenState extends State<StudentShopScreen> {
  final _searchController = TextEditingController();
  Timer? _syncTimer;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ShopProvider>().fetchShopItems();
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        context.read<StudentProvider>().fetchPurchasedItems(user.id);
      }
      _syncTimer = Timer.periodic(const Duration(seconds: 25), (_) {
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

  Future<void> _refresh() async {
    await context.read<ShopProvider>().fetchShopItems();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null && mounted) {
      await context.read<StudentProvider>().fetchPurchasedItems(user.id);
    }
  }

  Future<void> _buyItem(ShopItem item) async {
    final student = context.read<StudentProvider>();
    final shop = context.read<ShopProvider>();
    final user = context.read<AuthProvider>().currentUser;

    if (user == null) {
      showTopNotification(context, 'Log in to purchase rewards.');
      return;
    }
    if (student.isItemPurchased(item.id)) {
      showTopNotification(context, 'You already own ${item.name}.');
      return;
    }
    if (student.coins < item.price) {
      showTopNotification(context, 'Not enough coins. Need ${item.price}.');
      return;
    }

    final remaining = await shop.purchaseItem(
      userId: user.id,
      itemId: item.id,
      itemPrice: item.price,
      currentCoins: student.coins,
    );

    if (!mounted) return;
    if (remaining != null) {
      await student.setCoins(remaining);
      if (mounted) {
        context.read<AuthProvider>().updateCurrentUserCoins(remaining);
      }
      await student.addPurchasedItemOffline(item);
      showTopNotification(context, 'Purchased ${item.name}.');
    } else {
      showTopNotification(context, shop.errorMessage ?? 'Purchase failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final student = context.watch<StudentProvider>();
    final theme = Theme.of(context);
    final query = _searchController.text.trim().toLowerCase();
    final ownedCount = shop.items
        .where((item) => student.isItemPurchased(item.id))
        .length;

    final visibleItems = shop.items
        .where((item) {
          final matchesSearch =
              query.isEmpty || item.name.toLowerCase().contains(query);
          final purchased = student.isItemPurchased(item.id);
          final affordable = student.coins >= item.price;
          final matchesFilter = switch (_filter) {
            'owned' => purchased,
            'affordable' => affordable && !purchased,
            _ => true,
          };
          return matchesSearch && matchesFilter;
        })
        .toList(growable: false);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShopHeader(
                        coins: student.coins,
                        totalItems: shop.items.length,
                        ownedItems: ownedCount,
                      ),
                      const SizedBox(height: 16),
                      _ShopSearchBar(
                        controller: _searchController,
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterPill(
                              label: 'All rewards',
                              icon: Icons.storefront_outlined,
                              selected: _filter == 'all',
                              onTap: () => setState(() => _filter = 'all'),
                            ),
                            _FilterPill(
                              label: 'Can buy',
                              icon: Icons.local_offer_outlined,
                              selected: _filter == 'affordable',
                              onTap: () =>
                                  setState(() => _filter = 'affordable'),
                            ),
                            _FilterPill(
                              label: 'Owned',
                              icon: Icons.inventory_2_outlined,
                              selected: _filter == 'owned',
                              onTap: () => setState(() => _filter = 'owned'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (shop.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (visibleItems.isEmpty)
                SliverFillRemaining(
                  child: _EmptyShopState(
                    message:
                        shop.errorMessage ?? 'No rewards match your filters.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                  sliver: SliverList.separated(
                    itemCount: visibleItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];
                      return _RewardRow(
                        item: item,
                        owned: student.isItemPurchased(item.id),
                        affordable: student.coins >= item.price,
                        onBuy: () => _buyItem(item),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({
    required this.coins,
    required this.totalItems,
    required this.ownedItems,
  });

  final int coins;
  final int totalItems;
  final int ownedItems;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101827).withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Student Shop',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD166),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: Color(0xFF7A4A00),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$coins',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF4A2F00),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Redeem coins for profile rewards and learning perks.',
            style: GoogleFonts.poppins(
              color: const Color(0xFFCBD5E1),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ShopMetric(label: 'Rewards', value: '$totalItems'),
              const SizedBox(width: 10),
              _ShopMetric(label: 'Owned', value: '$ownedItems'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShopMetric extends StatelessWidget {
  const _ShopMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: const Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopSearchBar extends StatelessWidget {
  const _ShopSearchBar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        hintText: 'Search rewards',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFD8E0EA),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFD8E0EA),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 16,
          color: selected ? Colors.white : scheme.onSurface.withAlpha(190),
        ),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        labelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : scheme.onSurface.withAlpha(190),
        ),
        selectedColor: const Color(0xFF2563EB),
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFD8E0EA)),
          ),
        ),
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.item,
    required this.owned,
    required this.affordable,
    required this.onBuy,
  });

  final ShopItem item;
  final bool owned;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFD8E0EA),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).shadowColor.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 86,
              height: 86,
              child: ShopImageThumb(
                imageUrl: item.imageUrl,
                size: double.infinity,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    if (owned) const _SmallBadge(label: 'Owned'),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      size: 18,
                      color: Color(0xFFEAB308),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.price}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF713F12),
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: owned || !affordable ? null : onBuy,
                      icon: Icon(
                        owned
                            ? Icons.check_rounded
                            : Icons.shopping_bag_outlined,
                        size: 16,
                      ),
                      label: Text(owned ? 'Owned' : 'Buy'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        disabledBackgroundColor: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
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
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF064E3B) : const Color(0xFFE8F7EF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF059669) : const Color(0xFFBDE8CF),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: isDark ? scheme.onSurface : const Color(0xFF167A3F),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyShopState extends StatelessWidget {
  const _EmptyShopState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFD8E0EA),
                ),
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 36,
                color: scheme.onSurface.withAlpha(130),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface.withAlpha(150),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
