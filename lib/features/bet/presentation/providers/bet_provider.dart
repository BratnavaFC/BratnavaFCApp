import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/bet_remote_datasource.dart';

// ── DataSource ────────────────────────────────────────────────────────────────

final betDsProvider = Provider<BetRemoteDataSource>(
  (ref) => BetRemoteDataSource(ref.watch(dioProvider)),
);
