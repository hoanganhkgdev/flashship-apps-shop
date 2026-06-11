class NotificationItem {
  final String    id;
  final String    title;
  final String    body;
  final String?   orderCode;
  final DateTime  createdAt;
  final bool      isRead;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.orderCode,
    required this.createdAt,
    this.isRead = false,
  });

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
    id:        id,
    title:     title,
    body:      body,
    orderCode: orderCode,
    createdAt: createdAt,
    isRead:    isRead ?? this.isRead,
  );

  Map<String, dynamic> toJson() => {
    'id':         id,
    'title':      title,
    'body':       body,
    'order_code': orderCode,
    'created_at': createdAt.toIso8601String(),
    'is_read':    isRead,
  };

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
    id:        j['id'].toString(),
    title:     j['title'] as String,
    body:      j['body']  as String,
    orderCode: j['order_code'] as String?,
    createdAt: _parseDate(j['created_at'] as String),
    isRead:    j['is_read'] == true || j['is_read'] == 1,
  );

  static DateTime _parseDate(String s) {
    // Handle both ISO 8601 ('T' separator) and MySQL datetime (' ' separator)
    return DateTime.parse(s.contains('T') ? s : s.replaceFirst(' ', 'T'));
  }
}
