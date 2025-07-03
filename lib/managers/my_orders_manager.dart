// lib/managers/my_orders_manager.dart

class MyOrdersManager {
  MyOrdersManager._();

  static final Set<String> _myOrderIds = {};

  /// Добавляет ID трека в список заказов текущего пользователя
  static void add(String trackId) {
    _myOrderIds.add(trackId);
  }

  /// Проверяет, был ли трек заказан текущим пользователем
  static bool isMyOrder(String trackId) {
    return _myOrderIds.contains(trackId);
  }

  /// Очищает список заказов (например, при выходе)
  static void clear() {
    _myOrderIds.clear();
  }
}
