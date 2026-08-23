import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/order_model.dart';

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => ApiOrderRepository(ref.read(apiClientProvider)),
);

class OrderPage {
  final List<OrderModel> orders;
  final bool hasMore;

  const OrderPage({required this.orders, required this.hasMore});
}

class PricingEstimate {
  final int fee;
  final int nightSurcharge;
  final double? distanceKm;

  const PricingEstimate({
    required this.fee,
    required this.nightSurcharge,
    this.distanceKm,
  });
}

class NearbyDriver {
  final Object id;
  final double lat;
  final double lng;
  final double bearing;

  const NearbyDriver({
    required this.id,
    required this.lat,
    required this.lng,
    this.bearing = 0,
  });

  factory NearbyDriver.fromJson(Map<String, dynamic> json) => NearbyDriver(
        id: json['id'] as Object,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        bearing: (json['bearing'] as num?)?.toDouble() ?? 0,
      );
}

class CreateOrderRequest {
  final bool isOutbound;
  final String pickupAddress;
  final String deliveryAddress;
  final String deliveryPhone;
  final String? deliveryName;
  final String? pickupName;
  final String? pickupPhone;
  final String? orderNote;
  final String cargoType;
  final double? cargoWeight;
  final int? codAmount;
  final String? pickupPlaceName;
  final String? deliveryPlaceName;
  final double? pickupLat;
  final double? pickupLng;
  final double? deliveryLat;
  final double? deliveryLng;
  final String? voucherCode;

  const CreateOrderRequest({
    required this.isOutbound,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.deliveryPhone,
    this.deliveryName,
    this.pickupName,
    this.pickupPhone,
    this.orderNote,
    required this.cargoType,
    this.cargoWeight,
    this.codAmount,
    this.pickupPlaceName,
    this.deliveryPlaceName,
    this.pickupLat,
    this.pickupLng,
    this.deliveryLat,
    this.deliveryLng,
    this.voucherCode,
  });

  Map<String, dynamic> toJson() => {
        'is_outbound': isOutbound ? 1 : 0,
        'pickup_address': pickupAddress,
        'delivery_address': deliveryAddress,
        'delivery_phone': deliveryPhone,
        if (deliveryName?.isNotEmpty == true) 'delivery_name': deliveryName,
        if (pickupName?.isNotEmpty == true) 'pickup_name': pickupName,
        if (pickupPhone?.isNotEmpty == true) 'pickup_phone': pickupPhone,
        if (orderNote?.isNotEmpty == true) ...{
          'order_note': orderNote,
          'cargo_note': orderNote,
        },
        'cargo_type': cargoType,
        if (cargoWeight != null) 'cargo_weight': cargoWeight,
        if (codAmount != null) 'cod_amount': codAmount,
        if (pickupPlaceName != null) 'pickup_place_name': pickupPlaceName,
        if (deliveryPlaceName != null) 'delivery_place_name': deliveryPlaceName,
        if (pickupLat != null) 'pickup_lat': pickupLat,
        if (pickupLng != null) 'pickup_lng': pickupLng,
        if (deliveryLat != null) 'delivery_lat': deliveryLat,
        if (deliveryLng != null) 'delivery_lng': deliveryLng,
        if (voucherCode != null) 'voucher_code': voucherCode,
      };
}

class BatchPricingStop {
  final String address;
  final double? lat;
  final double? lng;
  final double? cargoWeight;

  const BatchPricingStop({
    required this.address,
    this.lat,
    this.lng,
    this.cargoWeight,
  });

  Map<String, dynamic> toJson() => {
        'address': address,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (cargoWeight != null) 'cargo_weight': cargoWeight,
      };
}

class BatchStopEstimate {
  final int fee;
  final double? distanceKm;

  const BatchStopEstimate({required this.fee, this.distanceKm});
}

class BatchPricingEstimate {
  final int totalFee;
  final List<BatchStopEstimate> stops;

  const BatchPricingEstimate({required this.totalFee, required this.stops});
}

class CreateBatchStopRequest {
  final String address;
  final String phone;
  final String name;
  final String note;
  final double lat;
  final double lng;
  final int? codAmount;

  const CreateBatchStopRequest({
    required this.address,
    required this.phone,
    required this.name,
    required this.note,
    required this.lat,
    required this.lng,
    this.codAmount,
  });

  Map<String, dynamic> toJson() => {
        'address': address,
        'phone': phone,
        'name': name,
        'note': note,
        'lat': lat,
        'lng': lng,
        if (codAmount != null) 'cod_amount': codAmount,
      };
}

class CreateBatchOrderRequest {
  final String pickupAddress;
  final String pickupPhone;
  final String orderNote;
  final String cargoType;
  final double pickupLat;
  final double pickupLng;
  final double? cargoWeight;
  final String? voucherCode;
  final List<CreateBatchStopRequest> stops;

  const CreateBatchOrderRequest({
    required this.pickupAddress,
    required this.pickupPhone,
    required this.orderNote,
    required this.cargoType,
    required this.pickupLat,
    required this.pickupLng,
    this.cargoWeight,
    this.voucherCode,
    required this.stops,
  });

  Map<String, dynamic> toJson() => {
        'pickup_address': pickupAddress,
        'pickup_phone': pickupPhone,
        'order_note': orderNote,
        'cargo_type': cargoType,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        if (cargoWeight != null) 'cargo_weight': cargoWeight,
        if (voucherCode != null) 'voucher_code': voucherCode,
        'stops': stops.map((stop) => stop.toJson()).toList(growable: false),
      };
}

abstract interface class OrderRepository {
  Future<OrderPage> fetchPage(int page);
  Future<List<NearbyDriver>> fetchNearbyDrivers({
    required double lat,
    required double lng,
    double radiusKm = 5,
  });
  Future<PricingEstimate> estimate(Map<String, dynamic> params);
  Future<OrderModel> create(CreateOrderRequest request);
  Future<BatchPricingEstimate> estimateBatch({
    required String cargoType,
    required String pickupAddress,
    required double? pickupLat,
    required double? pickupLng,
    required List<BatchPricingStop> stops,
  });
  Future<OrderModel> createBatch(CreateBatchOrderRequest request);
  Future<OrderModel> findByCode(String code);
  Future<void> cancel(String code);
  Future<void> deliverStop(String code, int sequence);
  Future<void> rate(String code, {required int rating, String? note});
}

class ApiOrderRepository implements OrderRepository {
  final ApiClient _api;

  const ApiOrderRepository(this._api);

  @override
  Future<OrderPage> fetchPage(int page) async {
    final response = await _api.get('/shop/orders', params: {'page': page});
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? const [];

    return OrderPage(
      orders: data
          .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      hasMore: apiHasMore(response),
    );
  }

  @override
  Future<List<NearbyDriver>> fetchNearbyDrivers({
    required double lat,
    required double lng,
    double radiusKm = 5,
  }) async {
    final response = await _api.get('/customer/drivers/nearby', params: {
      'lat': lat,
      'lng': lng,
      'radius': radiusKm,
    });
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? const [];
    return data
        .map((item) => NearbyDriver.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<PricingEstimate> estimate(Map<String, dynamic> params) async {
    final response = await _api.get('/shop/pricing/estimate', params: params);
    final data = unwrap(response) as Map<String, dynamic>;
    return PricingEstimate(
      fee: (data['fee'] as num).toInt(),
      nightSurcharge: (data['night_surcharge'] as num?)?.toInt() ?? 0,
      distanceKm: (data['distance_km'] as num?)?.toDouble(),
    );
  }

  @override
  Future<OrderModel> create(CreateOrderRequest request) async {
    final response = await _api.post('/shop/orders', data: request.toJson());
    return OrderModel.fromJson(unwrap(response) as Map<String, dynamic>);
  }

  @override
  Future<BatchPricingEstimate> estimateBatch({
    required String cargoType,
    required String pickupAddress,
    required double? pickupLat,
    required double? pickupLng,
    required List<BatchPricingStop> stops,
  }) async {
    final response = await _api.post('/shop/pricing/estimate-batch', data: {
      'cargo_type': cargoType,
      if (pickupLat != null) 'pickup_lat': pickupLat,
      if (pickupLng != null) 'pickup_lng': pickupLng,
      'pickup_address': pickupAddress,
      'stops': stops.map((stop) => stop.toJson()).toList(growable: false),
    });
    final data = unwrap(response) as Map<String, dynamic>;
    final rawStops = data['stops'] as List<dynamic>? ?? const [];
    return BatchPricingEstimate(
      totalFee: (data['total_fee'] as num).toInt(),
      stops: rawStops
          .map((item) => item as Map<String, dynamic>)
          .map((item) => BatchStopEstimate(
                fee: (item['fee'] as num).toInt(),
                distanceKm: (item['distance_km'] as num?)?.toDouble(),
              ))
          .toList(growable: false),
    );
  }

  @override
  Future<OrderModel> createBatch(CreateBatchOrderRequest request) async {
    final response =
        await _api.post('/shop/orders/batch', data: request.toJson());
    return OrderModel.fromJson(unwrap(response) as Map<String, dynamic>);
  }

  @override
  Future<OrderModel> findByCode(String code) async {
    final response = await _api.get('/shop/orders/$code');
    return OrderModel.fromJson(unwrap(response) as Map<String, dynamic>);
  }

  @override
  Future<void> cancel(String code) async {
    await _api.post('/shop/orders/$code/cancel');
  }

  @override
  Future<void> deliverStop(String code, int sequence) async {
    await _api.post('/shop/orders/$code/stops/$sequence/deliver');
  }

  @override
  Future<void> rate(String code, {required int rating, String? note}) async {
    await _api.post('/shop/orders/$code/rate', data: {
      'rating': rating,
      if (note?.isNotEmpty == true) 'note': note,
    });
  }
}
