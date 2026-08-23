import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/support_config_item.dart';
import 'support_config_repository.dart';

final supportConfigProvider =
    FutureProvider.autoDispose<List<SupportConfigItem>>((ref) async {
  return ref.read(supportConfigRepositoryProvider).fetchAll();
});
