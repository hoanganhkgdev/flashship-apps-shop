class ShopUserModel {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final String? profilePhotoPath;
  final String? avatarUrl;
  final int cityId;
  final String? cityName;

  const ShopUserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.profilePhotoPath,
    this.avatarUrl,
    this.cityId = 1,
    this.cityName,
  });

  factory ShopUserModel.fromJson(Map<String, dynamic> json) => ShopUserModel(
    id:               json['id']   as int,
    name:             json['name'] as String? ?? '',
    phone:            json['phone'] as String? ?? '',
    email:            json['email'] as String?,
    address:          json['address'] as String?,
    profilePhotoPath: json['profile_photo_path'] as String?,
    avatarUrl:        json['avatar_url'] as String?,
    cityId:           json['city_id'] as int? ?? 1,
    cityName:         json['city_name'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'phone': phone,
    'email': email, 'address': address,
    'profile_photo_path': profilePhotoPath,
    'avatar_url': avatarUrl,
    'city_id': cityId, 'city_name': cityName,
  };

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return parts.last.substring(0, 1).toUpperCase();
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'S';
  }
}
