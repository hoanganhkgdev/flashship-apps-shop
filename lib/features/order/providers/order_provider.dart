import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/order_model.dart';

class OrderListState {
  final List<OrderModel> orders;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int page;

  const OrderListState({
    this.orders    = const [],
    this.isLoading = false,
    this.hasMore   = true,
    this.error,
    this.page      = 1,
  });

  List<OrderModel> get active   => orders.where((o) => o.isActive).toList();
  List<OrderModel> get history  => orders.where((o) => !o.isActive).toList();

  OrderListState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? page,
    bool clearError = false,
  }) =>
      OrderListState(
        orders:    orders    ?? this.orders,
        isLoading: isLoading ?? this.isLoading,
        hasMore:   hasMore   ?? this.hasMore,
        error:     clearError ? null : (error ?? this.error),
        page:      page      ?? this.page,
      );
}

class OrderListNotifier extends StateNotifier<OrderListState> {
  final ApiClient _api;
  OrderListNotifier(this._api) : super(const OrderListState()) {
    fetch();
  }

  Future<void> fetch({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(orders: [], page: 1, hasMore: true, isLoading: true, clearError: true);
    } else {
      if (state.isLoading || !state.hasMore) return;
      state = state.copyWith(isLoading: true);
    }

    try {
      final page = refresh ? 1 : state.page;
      final res  = await _api.get('/shop/orders', params: {'page': page});
      final data = res.data['data'] as List<dynamic>;
      final meta = res.data['meta']    as Map<String, dynamic>? ?? {};
      final hasMore = meta['has_more'] as bool? ?? false;

      final fetched = data.map((e) => OrderModel.fromJson(e as Map<String, dynamic>)).toList();
      final current = refresh ? <OrderModel>[] : state.orders;

      state = state.copyWith(
        orders:    [...current, ...fetched],
        isLoading: false,
        hasMore:   hasMore,
        page:      page + 1,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void addOrder(OrderModel order) {
    state = state.copyWith(orders: [order, ...state.orders]);
  }

  void updateOrder(OrderModel updated) {
    final list = state.orders.map((o) => o.id == updated.id ? updated : o).toList();
    state = state.copyWith(orders: list);
  }

  void removeOrder(int id) {
    state = state.copyWith(orders: state.orders.where((o) => o.id != id).toList());
  }
}

final orderListProvider = StateNotifierProvider<OrderListNotifier, OrderListState>((ref) {
  return OrderListNotifier(ref.read(apiClientProvider));
});
