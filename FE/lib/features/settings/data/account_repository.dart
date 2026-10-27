import '../../../core/network/api_client.dart';
import '../../../core/network/api_contract.dart';
import '../../auth/data/models/auth_session.dart';

abstract interface class AccountRepository {
  Future<CurrentUser> load();
  Future<CurrentUser> update(Map<String, dynamic> body);
  Future<void> delete();
}

class ServerAccountRepository implements AccountRepository {
  const ServerAccountRepository(this.api);
  final ApiClient api;
  @override
  Future<CurrentUser> load() async =>
      CurrentUser.fromJson((await api.send('GET', ApiContract.me))!);
  @override
  Future<CurrentUser> update(Map<String, dynamic> body) async =>
      CurrentUser.fromJson(
        (await api.send('PATCH', ApiContract.me, body: body))!,
      );
  @override
  Future<void> delete() async {
    await api.send('DELETE', ApiContract.me);
  }
}
