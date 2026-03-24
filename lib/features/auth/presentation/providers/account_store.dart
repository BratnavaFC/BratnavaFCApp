import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/entities/account.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class AccountState {
  final List<Account> accounts;
  final String? activeAccountId;

  const AccountState({
    this.accounts        = const [],
    this.activeAccountId,
  });

  Account? get activeAccount {
    if (activeAccountId == null && accounts.isEmpty) return null;
    try {
      return accounts.firstWhere(
        (a) => a.userId == activeAccountId,
        orElse: () => accounts.first,
      );
    } catch (_) {
      return null;
    }
  }

  bool get isLoggedIn => activeAccount != null;

  AccountState copyWith({
    List<Account>? accounts,
    String? activeAccountId,
  }) =>
      AccountState(
        accounts:        accounts        ?? this.accounts,
        activeAccountId: activeAccountId ?? this.activeAccountId,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AccountStore extends StateNotifier<AccountState> {
  final SharedPreferences _prefs;

  AccountStore(this._prefs) : super(const AccountState()) {
    _load();
  }

  // ── Persistência ──────────────────────────────────────────────────────────

  void _load() {
    final raw      = _prefs.getString(AppConstants.accountsStorageKey);
    final activeId = _prefs.getString(AppConstants.activeAccountKey);

    if (raw == null) return;

    try {
      final list = (json.decode(raw) as List)
          .map((e) => Account.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AccountState(accounts: list, activeAccountId: activeId);
    } catch (_) {}
  }

  Future<void> _persist() async {
    final encoded = json.encode(state.accounts.map((a) => a.toJson()).toList());
    await _prefs.setString(AppConstants.accountsStorageKey, encoded);
    if (state.activeAccountId != null) {
      await _prefs.setString(
          AppConstants.activeAccountKey, state.activeAccountId!);
    } else {
      await _prefs.remove(AppConstants.activeAccountKey);
    }
  }

  // ── API pública ───────────────────────────────────────────────────────────

  /// Adiciona ou atualiza uma conta e a torna ativa.
  Future<void> upsertAccount(Account account) async {
    final existing = state.accounts.indexWhere((a) => a.userId == account.userId);
    final list = List<Account>.from(state.accounts);

    if (existing >= 0) {
      list[existing] = account;
    } else {
      list.add(account);
    }

    state = AccountState(accounts: list, activeAccountId: account.userId);
    await _persist();
  }

  Future<void> setActive(String userId) async {
    state = state.copyWith(activeAccountId: userId);
    await _persist();
  }

  /// Atualiza tokens do active account após um refresh.
  Future<void> updateTokens(String accessToken, String refreshToken) async {
    final active = state.activeAccount;
    if (active == null) return;
    await upsertAccount(
      active.copyWith(
        accessToken:  accessToken,
        refreshToken: refreshToken,
      ),
    );
  }

  /// Patch genérico do active account (ex.: activeGroupId, groupAdminIds…).
  Future<void> patchActive(Account Function(Account) updater) async {
    final active = state.activeAccount;
    if (active == null) return;
    await upsertAccount(updater(active));
  }

  /// Faz logout da conta ativa. Se houver outra, troca para ela.
  Future<void> logout() async {
    final activeId = state.activeAccountId;
    final list     = state.accounts.where((a) => a.userId != activeId).toList();
    final nextId   = list.isNotEmpty ? list.first.userId : null;

    state = AccountState(accounts: list, activeAccountId: nextId);
    await _persist();
  }

  Future<void> logoutAll() async {
    state = const AccountState();
    await _prefs.remove(AppConstants.accountsStorageKey);
    await _prefs.remove(AppConstants.activeAccountKey);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final accountStoreProvider =
    StateNotifierProvider<AccountStore, AccountState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AccountStore(prefs);
});
