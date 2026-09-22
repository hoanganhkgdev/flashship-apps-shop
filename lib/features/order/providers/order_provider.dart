import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../data/order_repository.dart';
import '../models/order_model.dart';

class OrderListState {
  final List<OrderModel> orders;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int page;

  const OrderListState({
    this.orders = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.page = 1,
  });

  List<OrderModel> get active => orders.where((o) => o.isActive).toList();
  List<OrderModel> get history => orders.where((o) => !o.isActive).toList();

  OrderListState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? page,
    bool clearError = false,
  }) =>
      OrderListState(
        orders: orders ?? this.orders,
        isLoading: isLoading ?? this.isLoading,
        hasMore: hasMore ?? this.hasMore,
        error: clearError ? null : (error ?? this.error),
        page: page ?? this.page,
      );
}

class OrderListNotifier extends StateNotifier<OrderListState> {
  final OrderRepository _repository;
  OrderListNotifier(this._repository) : super(const OrderListState()) {
    fetch();
  }

  Future<void> fetch({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(
          orders: [],
          page: 1,
          hasMore: true,
          isLoading: true,
          clearError: true);
    } else {
      if (state.isLoading || !state.hasMore) return;
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final page = refresh ? 1 : state.page;
      final result = await _repository.fetchPage(page);
      final current = refresh ? <OrderModel>[] : state.orders;

      state = state.copyWith(
        orders: [...current, ...result.orders],
        isLoading: false,
        hasMore: result.hasMore,
        page: page + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: parseApiError(e, fallback: 'Không tải được danh sách đơn'),
      );
    }
  }

  void addOrder(OrderModel order) {
    state = state.copyWith(orders: [order, ...state.orders]);
  }

  void updateOrder(OrderModel updated) {
    final list =
        state.orders.map((o) => o.id == updated.id ? updated : o).toList();
    state = state.copyWith(orders: list);
  }

  void removeOrder(int id) {
    state =
        state.copyWith(orders: state.orders.where((o) => o.id != id).toList());
  }
}

final orderListProvider =
    StateNotifierProvider<OrderListNotifier, OrderListState>((ref) {
  return OrderListNotifier(ref.read(orderRepositoryProvider));
});
