import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/court_provider.dart';
import '../models/court_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'package:url_launcher/url_launcher.dart';

class CourtsSearchScreen extends StatefulWidget {
  const CourtsSearchScreen({super.key});

  @override
  State<CourtsSearchScreen> createState() => _CourtsSearchScreenState();
}

class _CourtsSearchScreenState extends State<CourtsSearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CourtProvider>(context, listen: false);
      provider.loadGovernorates();
      provider.loadCourts(refresh: true);
    });
  }

  void _onSearchChanged(String value) {
    final provider = Provider.of<CourtProvider>(context, listen: false);
    provider.setSearchQuery(value);
    provider.loadCourts(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(),
          _buildFilterSection(),
          _buildCourtsList(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      floating: true,
      stretch: true,
      backgroundColor: AppColors.brand,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          'دليل المحاكم اليمنية',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.brand, AppColors.brandDark],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -20,
                child: Icon(Icons.account_balance_rounded, size: 200, color: Colors.white.withOpacity(0.05)),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
                  child: _buildSearchBar(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'ابحث عن محكمة أو منطقة...',
          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: AppColors.brand),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2);
  }

  Widget _buildFilterSection() {
    return SliverToBoxAdapter(
      child: Container(
        height: 60,
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Consumer<CourtProvider>(
          builder: (context, provider, child) {
            if (provider.isLoadingGovs) {
              return _buildGovShimmer();
            }
            
            final govs = ['الكل', ...provider.governorates];
            return ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: govs.length,
              itemBuilder: (context, index) {
                final gov = govs[index];
                final isSelected = (provider.governorateFilter ?? 'الكل') == gov;
                
                return Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: FilterChip(
                    label: Text(gov),
                    selected: isSelected,
                    onSelected: (selected) {
                      provider.setGovernorateFilter(gov);
                      provider.loadCourts(refresh: true);
                    },
                    selectedColor: AppColors.gold.withOpacity(0.2),
                    checkmarkColor: AppColors.gold,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.brandDark : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: BorderSide(color: isSelected ? AppColors.gold : Colors.grey.shade300),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCourtsList() {
    return Consumer<CourtProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.courts.isEmpty) {
          return SliverFillRemaining(child: _buildCourtsShimmer());
        }

        if (provider.courts.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade300),
                  SizedBox(height: 16),
                  Text('لم يتم العثور على نتائج', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final court = provider.courts[index];
                
                // Header for Governorate if it's the first in the group and no search active
                bool showHeader = false;
                if (index == 0) showHeader = true;
                else if (provider.courts[index-1].governorate != court.governorate) showHeader = true;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showHeader) _buildGovernorateHeader(court.governorate ?? 'أخرى'),
                    _CourtListItem(court: court).animate().fadeIn(delay: (index % 10 * 50).ms).slideX(begin: 0.05),
                  ],
                );
              },
              childCount: provider.courts.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildGovernorateHeader(String name) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, right: 4.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.brandDark,
            ),
          ),
          Spacer(),
          Text(
            'عرض الكل',
            style: TextStyle(fontSize: 12, color: AppColors.brand.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildGovShimmer() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.white,
        child: Container(
          width: 80,
          margin: EdgeInsets.only(left: 8, top: 10, bottom: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  Widget _buildCourtsShimmer() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.white,
        child: Container(
          height: 100,
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }
}

class _CourtListItem extends StatelessWidget {
  final CourtModel court;
  const _CourtListItem({required this.court});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.brand.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.account_balance_rounded, color: AppColors.brand, size: 24),
        ),
        title: Text(
          court.name,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                SizedBox(width: 4),
                Text(court.address ?? 'موقع غير محدد', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: AppColors.gold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: Icon(Icons.directions_rounded, color: AppColors.goldDark),
            onPressed: () => _launchMap(court),
          ),
        ),
        onTap: () {
          // Show court details or navigate
        },
      ),
    );
  }

  void _launchMap(CourtModel court) async {
    final url = court.locationUrl ?? 
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(court.name + " " + (court.governorate ?? ""))}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }
}
