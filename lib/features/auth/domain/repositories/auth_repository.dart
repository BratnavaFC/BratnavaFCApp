import '../entities/account.dart';

abstract class AuthRepository {
  Future<Account> login({required String email, required String password});

  Future<void> register({
    required String userName,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  });
}
