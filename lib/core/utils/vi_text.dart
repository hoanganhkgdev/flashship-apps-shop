/// Chuẩn hoá chuỗi tiếng Việt để so khớp khi tìm kiếm: chữ thường, bỏ dấu,
/// `đ` → `d`. Nhờ vậy gõ "san bay" vẫn tìm ra "Sân bay".
String foldVietnamese(String input) {
  const groups = <String, String>{
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  final lookup = <int, String>{
    for (final e in groups.entries)
      for (final r in e.value.runes) r: e.key,
  };
  final out = StringBuffer();
  for (final r in input.toLowerCase().runes) {
    out.write(lookup[r] ?? String.fromCharCode(r));
  }
  return out.toString();
}

/// Mọi từ trong [query] đều xuất hiện trong [text] (không phân biệt dấu/hoa
/// thường, không phụ thuộc thứ tự từ). [query] rỗng thì luôn khớp.
bool matchesVietnamese(String text, String query) {
  final tokens = foldVietnamese(query)
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return true;
  final haystack = foldVietnamese(text);
  return tokens.every(haystack.contains);
}
