import re

with open("lib/main.dart", "r") as f:
    content = f.read()

# Replace _buildLibraryView
new_library_view = """
  Widget _buildLibraryView() {
    final favoritesList = _favorites.toList();
    return Scaffold(
      backgroundColor: const Color(0xFF131313),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131313),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF3F008E)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const Icon(Icons.person, color: Color(0xFFD2BBFF), size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'RETRO HUB',
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFFD2BBFF),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF4A4455)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.search, color: Color(0xFFD2BBFF), size: 20),
              onPressed: () {},
            ),
          )
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('ALL', true),
                _buildFilterChip('GBA', false),
                _buildFilterChip('GBC', false),
                _buildFilterChip('GB', false),
                _buildFilterChip('NES', false),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Library', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Icon(Icons.sort, color: Color(0xFF73DB9A), size: 16),
                    const SizedBox(width: 4),
                    Text('RECENT', style: GoogleFonts.jetBrainsMono(color: const Color(0xFF73DB9A), fontSize: 12, fontWeight: FontWeight.bold)),
                    const Icon(Icons.keyboard_arrow_down, color: Color(0xFF73DB9A), size: 16),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: favoritesList.isEmpty
                ? const Center(child: Text('No ROMs saved yet.', style: TextStyle(color: Colors.white54)))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: favoritesList.length,
                    itemBuilder: (context, index) {
                      return _buildItemCard(favoritesList[index], index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFD2BBFF) : Colors.transparent,
        border: Border.all(color: isSelected ? const Color(0xFFD2BBFF) : const Color(0xFF4A4455)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          color: isSelected ? const Color(0xFF3F008E) : const Color(0xFFE5E2E1),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
"""
content = re.sub(r'  Widget _buildLibraryView\(\) \{.*?(?=  Widget _buildSocialView\(\) \{)', new_library_view, content, flags=re.DOTALL)

# Replace _buildItemCard
new_item_card = """
  Widget _buildItemCard(Wallpaper item, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetailScreen(
              wallpaper: item,
              isFavorite: _favorites.contains(item),
              onFavorite: () {
                setState(() {
                  if (_favorites.contains(item)) {
                    _favorites.remove(item);
                  } else {
                    _favorites.add(item);
                  }
                });
              },
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3A3939)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: item.thumbUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: const Color(0xFF2A2A2A)),
                    errorWidget: (_, _, _) => Container(color: const Color(0xFF2A2A2A)),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF73DB9A)),
                      ),
                      child: Text(
                        item.category.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF73DB9A),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '60 FPS',
                          style: GoogleFonts.jetBrainsMono(
                            color: const Color(0xFFCCC3D8),
                            fontSize: 10,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star_outline, color: Color(0xFFF97316), size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '4.8',
                              style: GoogleFonts.jetBrainsMono(
                                color: const Color(0xFFCCC3D8),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
"""
content = re.sub(r'  Widget _buildItemCard\(Wallpaper item, int index\) \{.*?(?=  @override\n  Widget build\(BuildContext context\) \{)', new_item_card, content, flags=re.DOTALL)

with open("lib/main.dart", "w") as f:
    f.write(content)

