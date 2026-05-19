import re

with open('lib/main.dart', 'r') as f:
    content = f.read()

def replace_between(text, start_str, end_str, new_str):
    start = text.find(start_str)
    if start == -1: return text
    end = text.find(end_str, start)
    if end == -1: return text
    return text[:start] + new_str + text[end:]

new_home_view = """Widget _buildHomeView() {
    final featured = _allItems.isNotEmpty ? _allItems.first : null;
    final trending = _allItems.skip(1).take(5).toList();

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          toolbarHeight: 70,
          pinned: true,
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.85),
          surfaceTintColor: Colors.transparent,
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(color: Colors.transparent),
            ),
          ),
          titleSpacing: 16,
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9D4EDD), Color(0xFF5A189A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF9D4EDD).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Retro Hub',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: IconButton(
                onPressed: () {
                  showSearch(context: context, delegate: GameSearchDelegate(_allItems));
                },
                icon: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (featured != null) ...[
                  Text(
                    'Featured',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRetroHero(featured),
                  const SizedBox(height: 32),
                ],
                Text(
                  'Categories',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final active = cat == _activeCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _activeCategory = cat;
                              _visibleCount = _batchSize;
                              _applyFilters();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: active
                                  ? const LinearGradient(colors: [Color(0xFF9D4EDD), Color(0xFF5A189A)])
                                  : null,
                              color: active ? null : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: active ? Colors.transparent : Colors.white.withOpacity(0.1),
                              ),
                              boxShadow: active
                                  ? [BoxShadow(color: const Color(0xFF9D4EDD).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                                  : [],
                            ),
                            child: Text(
                              cat,
                              style: GoogleFonts.outfit(
                                color: active ? Colors.white : Colors.white70,
                                fontSize: 14,
                                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Explore Games',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == _items.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _visibleCount += _batchSize;
                            _applyFilters();
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9D4EDD).withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFFD2BBFF)),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Load More',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFD2BBFF),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return _buildItemCard(_items[index], index);
              },
              childCount: _items.length < _allItems.length ? _items.length + 1 : _items.length,
            ),
          ),
        ),
      ],
    );
  }
"""

content = replace_between(content, "Widget _buildHomeView() {", "Widget _buildLibraryView() {", new_home_view + "\n  ")

with open('lib/main.dart', 'w') as f:
    f.write(content)
