enum ShopOrderType {
  delivery,
  pickup,
  batch;

  bool get isOutbound => this == ShopOrderType.delivery;
}
