import re

with open("lib/main.dart", "r") as f:
    content = f.read()

# Replace _buildItemCard
new_item_card = """
  Widget _buildItemCard(Wallpaper item, int index) {
    final rand = math.Random(item.id.hashCode);
    final rating = (4.0 + rand.nextDouble() * 0.9).toStringAsFixed(1);
    final fps = rand.nextBool() ? '60 FPS' : '30 FPS';

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
              allItems: _allItems,
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
                          fps,
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
                              rating,
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

