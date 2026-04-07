class ReceiptParser {
  // Public entry point

  static List<Map<String, dynamic>> parse(String rawText) {
    if (rawText.trim().isEmpty) return [];

    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final leftLines = <String>[];
    final rightPrices = <double>[];

    for (final line in lines) {
      final m = _standalonePriceRe.firstMatch(line);
      if (m != null) {
        final v = double.tryParse(m.group(1)!);
        if (v != null) rightPrices.add(v);
      } else {
        leftLines.add(line);
      }
    }

    final slots = <_Slot>[];

    int i = 0;
    while (i < leftLines.length) {
      final line = leftLines[i];
      final lower = line.toLowerCase();

      // Header fragments — no slot
      if (_headerRe.hasMatch(line)) {
        i++;
        continue;
      }

      // Detail line — no slot; update previous item
      if (_detailRe.hasMatch(line)) {
        if (slots.isNotEmpty && slots.last.type == _SlotType.item) {
          final dm = _detailRe.firstMatch(line)!;
          slots.last.quantity = double.tryParse(dm.group(1)!) ?? 1.0;
          slots.last.unit = dm.group(2)!.toLowerCase().replaceAll('ltr', 'L');
        }
        i++;
        continue;
      }

      // Noise
      if (_noiseWords.contains(lower)) {
        slots.add(_Slot(_SlotType.noise, line));
        i++;
        continue;
      }

      // Skip (SPECIAL / promo discount lines)
      if (_skipWords.contains(lower)) {
        slots.add(_Slot(_SlotType.skip, line));
        i++;
        continue;
      }

      // Item
      slots.add(_Slot(_SlotType.item, line));
      i++;
    }

    final items = <Map<String, dynamic>>[];

    for (int s = 0; s < slots.length; s++) {
      final slot = slots[s];
      final price = s < rightPrices.length ? rightPrices[s] : null;

      if (slot.type == _SlotType.item && price != null) {
        items.add({
          'name': _toTitleCase(slot.name),
          'category': _guessCategory(slot.name),
          'quantity': slot.quantity,
          'unit': slot.unit,
          'price': price,
        });
      }
    }

    return items;
  }

  // Patterns

  /// A line that is ONLY a price (the right column).
  /// Matches: "$4.66"  "-15.00"  "4.66"
  /// Single capture group so group(1) is never null.
  static final _standalonePriceRe = RegExp(r'^[-\$]?\s*(\d+\.\d{2})\s*$');

  /// Header fragments that have no right-column price.
  /// DATE, day abbreviations, dd/mm/yyyy dates, separator lines (***).
  static final _headerRe = RegExp(
    r'^(date|wed|thu|fri|sat|sun|mon|tue|\d{1,2}/\d{1,2}/\d{2,4}|\*+|#+|=+|-+)$',
    caseSensitive: false,
  );

  /// Detail lines: start with a number followed by a weight unit.
  /// "0.778kg NET @ $5.99/kg"  "1.328kg NET @ $2.99/kg"
  static final _detailRe = RegExp(
    r'^(\d+(?:\.\d+)?)\s*(kg|g\b|ml|l\b|ltr)',
    caseSensitive: false,
  );

  /// Left-column keywords that consume a price slot but are not grocery items.
  static const _noiseWords = {
    'subtotal',
    'total',
    'tax',
    'gst',
    'cgst',
    'sgst',
    'loyalty',
    'discount',
    'cash',
    'change',
    'savings',
    'thank',
    'invoice',
    'receipt',
    'balance',
    'due',
  };

  /// Keywords for promo/discount lines — consume a price slot but we discard them.
  static const _skipWords = {
    'special',
    'promo',
    'member',
    'reward',
    'coupon',
    'voucher',
  };

  // Helpers

  static String _toTitleCase(String s) => s
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');

  static String _guessCategory(String name) {
    final n = name.toLowerCase();
    if (RegExp(
      r'zucchini|broccoli|sprout|potato|tomato|onion|carrot|'
      r'lettuce|spinach|capsicum|celery|mushroom|eggplant|cucumber|'
      r'pumpkin|cabbage|garlic|ginger|peas|bean|snow|snap|salad|herb|'
      r'leek|silverbeet|bok|choy',
    ).hasMatch(n))
      return 'Produce';
    if (RegExp(
      r'banana|apple|grape|mango|orange|lemon|lime|berry|'
      r'strawberry|blueberry|watermelon|pineapple|pear|peach|plum|'
      r'kiwi|avocado|fruit',
    ).hasMatch(n))
      return 'Produce';
    if (RegExp(
      r'rice|wheat|flour|bread|pasta|noodle|atta|maida|oat|'
      r'cereal|grain|rawa|poha|sooji',
    ).hasMatch(n))
      return 'Grains';
    if (RegExp(
      r'milk|curd|yogurt|cheese|butter|cream|paneer|ghee|'
      r'lassi|dairy',
    ).hasMatch(n))
      return 'Dairy';
    if (RegExp(r'\boil\b|olive|sunflower|canola').hasMatch(n)) return 'Oils';
    if (RegExp(r'dal|lentil|chana|rajma|moong|masoor|urad|toor').hasMatch(n))
      return 'Pulses';
    if (RegExp(
      r'salt|pepper|spice|masala|turmeric|cumin|coriander|chilli',
    ).hasMatch(n))
      return 'Spices';
    if (RegExp(
      r'tea|coffee|juice|drink|water|soda|cola|cordial|energy',
    ).hasMatch(n))
      return 'Beverages';
    if (RegExp(
      r'chip|biscuit|cookie|snack|namkeen|chocolate|candy|popcorn',
    ).hasMatch(n))
      return 'Snacks';
    if (RegExp(
      r'chicken|beef|lamb|pork|fish|prawn|meat|mince|steak|bacon',
    ).hasMatch(n))
      return 'Meat';
    return 'Other';
  }
}

// Internal types

enum _SlotType { item, noise, skip }

class _Slot {
  final _SlotType type;
  final String name;
  double quantity = 1.0;
  String unit = 'pcs';
  _Slot(this.type, this.name);
}
