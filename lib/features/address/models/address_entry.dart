class AddressEntry {
  final int     id;
  final String? label;
  final String  name;
  final String  phone;
  final String  address;
  final double? lat;
  final double? lng;

  const AddressEntry({
    required this.id,
    this.label,
    required this.name,
    required this.phone,
    required this.address,
    this.lat,
    this.lng,
  });

  String get displayName => label?.isNotEmpty == true ? label! : name;

  factory AddressEntry.fromJson(Map<String, dynamic> j) => AddressEntry(
    id:      j['id'] as int,
    label:   j['label']   as String?,
    name:    j['name']    as String,
    phone:   j['phone']   as String,
    address: j['address'] as String,
    lat:     (j['lat']  as num?)?.toDouble(),
    lng:     (j['lng']  as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'label':   label,
    'name':    name,
    'phone':   phone,
    'address': address,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
  };
}
