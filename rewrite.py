import re

with open('lib/main.dart', 'r') as f:
    content = f.read()

start_marker = "class GalleryScreen extends StatefulWidget {"
end_marker = "class DetailScreen extends StatefulWidget {"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx != -1 and end_idx != -1:
    new_code = """class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> with SingleTickerProviderStateMixin {
  final WallpaperRepository _repository = WallpaperRepository();
  List<Wallpaper> _allItems = [];
  List<Wallpaper> _items = [];
  
  bool _loading = true;
  String? _error;
  
  static const _all = 'All Games';
  String _activeCategory = _all;
  List<String> _categories = [];
  
  int _visibleCount = 20;
  final int _batchSize = 20;
  
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  late AnimationController _animController;
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _loadWallpapers();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text;
        _applyFilters();
      });
    });
  }
  
  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    Iterable<Wallpaper> filtered = _allItems;
    if (_activeCategory != _all) {
      filtered = filtered.where((e) => e.category == _activeCategory);
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((e) => e.title.toLowerCase().contains(_searchQuery.toLowerCase()));
    }
    _items = filtered.take(_visibleCount).toList();
  }

  Future<void> _loadWallpapers() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _repository.fetch();
      items.shuffle();
      if (!mounted) return;
      setState(() {
        _allItems = items;
        _categories = [_all, ...{for (final item in items) item.category}.toList()..sort()];
        _applyFilters();
        _loading = false;
        _animController.forward();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Oops! We could not fetch the latest games.';
      });
    }
  }

  Widget _buildContent() {
    final filteredTotal = _allItems.where((e) {
      bool catMatch = _activeCategory == _all || e.category == _activeCategory;
      bool textMatch = _searchQuery.isEmpty || e.title.toLowerCase().contains(_searchQuery.toLowerCase());
      return catMatch && textMatch;
    }).length;

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 180.0,
          floating: false,
          pinned: true,
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
            title: Text('Retro Hub', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 24)),
            background: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        Theme.of(context).colorScheme.surface,
                      ],
                    )
                  ),
                ),
                Positioned(
                  right: -40,
                  top: -20,
                  child: Icon(Icons.sports_esports, size: 180, color: Colors.white.withOpacity(0.03)),
                )
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search for a game...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final active = cat == _activeCategory;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(cat, style: TextStyle(fontWeight: active ? FontWeight.bold : FontWeight.normal)),
                    selected: active,
                    onSelected: (val) {
                      if (val) {
                        setState(() { _activeCategory = cat; _visibleCount = _batchSize; _applyFilters(); });
                      }
                    },
                    backgroundColor: Colors.white.withOpacity(0.08),
                    selectedColor: Theme.of(context).colorScheme.primary,
                    labelStyle: TextStyle(color: active ? Colors.black : Colors.white),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                );
              },
            ),
          ),
        ),
        if (_items.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text('No games found.', style: TextStyle(color: Colors.white54))),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = _items[index];
                  return _buildItemCard(item, index);
                },
                childCount: _items.length,
              ),
            ),
          ),
        if (_items.length < filteredTotal)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _visibleCount += _batchSize;
                      _applyFilters();
                    });
                  },
                  icon: const Icon(Icons.expand_more_rounded),
                  label: Text('Load More (${_items.length}/$filteredTotal)'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          )
        else if (_items.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text("That's all the games!", style: TextStyle(color: Colors.white30))),
            ),
          )
      ],
    );
  }

  Widget _buildItemCard(Wallpaper item, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetailScreen(
              wallpaper: item,
              isFavorite: false,
              onFavorite: () {},
            ),
          ),
        );
      },
      child: Hero(
        tag: 'image_${item.id}',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: item.accent.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: item.thumbUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: item.accent.withOpacity(0.1)),
                  errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                      )
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1.2)),
                        const SizedBox(height: 4),
                        Text(item.category.toUpperCase(), style: TextStyle(color: item.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.videogame_asset_off_rounded, size: 64, color: Colors.white54),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 16),
                      FilledButton.icon(onPressed: _loadWallpapers, icon: const Icon(Icons.refresh), label: const Text('Try Again')),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }
}

"""
    
    new_content = content[:start_idx] + new_code + content[end_idx:]
    with open('lib/main.dart', 'w') as out_f:
        out_f.write(new_content)
    print("Replaced GalleryScreen successfully.")
else:
    print("Could not find markers.")
