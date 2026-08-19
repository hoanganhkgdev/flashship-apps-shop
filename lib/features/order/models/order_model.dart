class DriverInfo {
  final int id;
  final String name;
  final String phone;
  final String? avatarUrl;
  final double? latitude;
  final double? longitude;

  const DriverInfo({
    required this.id,
    required this.name,
    required this.phone,
    this.avatarUrl,
    this.latitude,
    this.longitude,
  });

  factory DriverInfo.fromJson(Map<String, dynamic> j) => DriverInfo(
    id:        j['id']   as int,
    name:      j['name'] as String? ?? '',
    phone:     j['phone'] as String? ?? '',
    avatarUrl: j['avatar_url'] as String?,
    latitude:  (j['latitude']  as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
  );
}

class TrackingInfo {
  final String firebaseDbUrl;
  final String rtdbPath;
  final String? driverLocationPath;

  const TrackingInfo({
    required this.firebaseDbUrl,
    required this.rtdbPath,
    this.driverLocationPath,
  });

  factory TrackingInfo.fromJson(Map<String, dynamic> j) => TrackingInfo(
    firebaseDbUrl:      j['firebase_db_url']      as String? ?? '',
    rtdbPath:           j['rtdb_path']            as String? ?? '',
    driverLocationPath: j['driver_location_path'] as String?,
  );
}

class OrderModel {
  final int id;
  final String code;
  final String status;
  final String? cancelReason;
  final String pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String? pickupPhone;
  final String? senderName;
  final String? storeName;
  final String? pickupPlaceName;
  final String deliveryAddress;
  final String? deliveryPlaceName;
  final double? deliveryLat;
  final double? deliveryLng;
  final String deliveryPhone;
  final String? receiverName;
  final int shippingFee;
  final String? voucherCode;
  final int discountAmount;
  final double? distanceKm;
  final String? orderNote;
  final String cargoType;
  final String? cargoNote;
  final double? cargoWeight;
  final int? codAmount;
  final int nightSurcharge;
  final int? driverRating;
  final bool    isBatch;
  final String? shopServiceType;
  final List<Map<String, dynamic>> stops;
  final DateTime? scheduledAt;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DriverInfo? driver;
  final TrackingInfo? tracking;

  const OrderModel({
    required this.id,
    required this.code,
    required this.status,
    this.cancelReason,
    required this.pickupAddress,
    this.pickupLat,
    this.pickupLng,
    this.pickupPhone,
    this.senderName,
    this.storeName,
    this.pickupPlaceName,
    required this.deliveryAddress,
    this.deliveryPlaceName,
    this.deliveryLat,
    this.deliveryLng,
    required this.deliveryPhone,
    this.receiverName,
    required this.shippingFee,
    this.voucherCode,
    this.discountAmount = 0,
    this.distanceKm,
    this.orderNote,
    this.cargoType = 'food',
    this.cargoNote,
    this.cargoWeight,
    this.codAmount,
    this.nightSurcharge = 0,
    this.driverRating,
    this.isBatch = false,
    this.shopServiceType,
    this.stops = const [],
    this.scheduledAt,
    required this.createdAt,
    this.completedAt,
    this.driver,
    this.tracking,
  });

  factory OrderModel.fromJson(Map<String, dynamic> j) => OrderModel(
    id:              j['id']    as int,
    code:            j['code']  as String? ?? '',
    status:          j['status'] as String? ?? '',
    cancelReason:    j['cancel_reason'] as String?,
    pickupAddress:   j['pickup_address'] as String? ?? '',
    pickupLat:       (j['pickup_lat']  as num?)?.toDouble(),
    pickupLng:       (j['pickup_lng']  as num?)?.toDouble(),
    pickupPhone:     j['pickup_phone'] as String?,
    senderName:        j['sender_name']        as String?,
    storeName:         j['store_name']         as String?,
    pickupPlaceName:   j['pickup_place_name']  as String?,
    deliveryAddress:   j['delivery_address']   as String? ?? '',
    deliveryPlaceName: j['delivery_place_name'] as String?,
    deliveryLat:       (j['delivery_lat'] as num?)?.toDouble(),
    deliveryLng:     (j['delivery_lng'] as num?)?.toDouble(),
    deliveryPhone:   j['delivery_phone'] as String? ?? '',
    receiverName:    j['receiver_name'] as String?,
    shippingFee:     (j['shipping_fee']   as num?)?.toInt() ?? 0,
    voucherCode:     j['voucher_code']    as String?,
    discountAmount:  (j['discount_amount'] as num?)?.toInt() ?? 0,
    distanceKm:      (j['distance_km']    as num?)?.toDouble(),
    orderNote:       j['order_note']    as String?,
    cargoType:       j['cargo_type']    as String? ?? 'food',
    cargoNote:       j['cargo_note']    as String?,
    cargoWeight:     (j['cargo_weight'] as num?)?.toDouble(),
    codAmount:       (j['cod_amount']   as num?)?.toInt(),
    nightSurcharge:  (j['night_surcharge'] as num?)?.toInt() ?? 0,
    driverRating:    j['driver_rating']  as int?,
    isBatch:          j['is_batch']          as bool? ?? false,
    shopServiceType:  j['shop_service_type'] as String?,
    stops:            (j['stops'] as List? ?? [])
        .cast<Map<String, dynamic>>(),
    scheduledAt: j['scheduled_at'] != null
        ? DateTime.tryParse(j['scheduled_at'] as String)
        : null,
    createdAt: DateTime.parse(j['created_at'] as String),
    completedAt: j['completed_at'] != null
        ? DateTime.tryParse(j['completed_at'] as String)
        : null,
    driver: j['driver'] != null
        ? DriverInfo.fromJson(j['driver'] as Map<String, dynamic>)
        : null,
    tracking: j['tracking'] != null
        ? TrackingInfo.fromJson(j['tracking'] as Map<String, dynamic>)
        : null,
  );

  bool get isActive    => const {'pending', 'assigned', 'processing', 'on_the_way'}.contains(status);
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get canCancel   => status == 'pending';
  bool get canRate {
    if (!isCompleted || driverRating != null) return false;
    if (completedAt == null) return true; // đơn cũ trước khi có field này, không chặn
    return DateTime.now().difference(completedAt!).inHours <= 24;
  }

  OrderModel copyWith({
    String? status,
    DriverInfo? driver,
    int? driverRating,
    List<Map<String, dynamic>>? stops,
  }) => OrderModel(
    id: id, code: code,
    status: status ?? this.status,
    cancelReason: cancelReason,
    pickupAddress: pickupAddress, pickupLat: pickupLat, pickupLng: pickupLng,
    pickupPhone: pickupPhone, senderName: senderName, storeName: storeName,
    pickupPlaceName: pickupPlaceName,
    deliveryAddress: deliveryAddress, deliveryPlaceName: deliveryPlaceName,
    deliveryLat: deliveryLat, deliveryLng: deliveryLng,
    deliveryPhone: deliveryPhone, receiverName: receiverName,
    shippingFee: shippingFee, voucherCode: voucherCode, discountAmount: discountAmount, distanceKm: distanceKm,
    orderNote: orderNote, cargoType: cargoType, cargoNote: cargoNote,
    cargoWeight: cargoWeight, codAmount: codAmount,
    nightSurcharge: nightSurcharge,
    driverRating: driverRating ?? this.driverRating,
    isBatch: isBatch,
    shopServiceType: shopServiceType,
    stops: stops ?? this.stops,
    scheduledAt: scheduledAt, createdAt: createdAt,
    completedAt: completedAt,
    driver: driver ?? this.driver,
    tracking: tracking,
  );
}
