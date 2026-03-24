import '../entities/account.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;

  const LoginUseCase(this._repository);

  Future<Account> call({
    required String email,
    required String password,
  }) =>
      _repository.login(email: email, password: password);
}
