import 'package:http/http.dart' as http;
import 'package:suga/models/power_interruption.dart';
import 'package:suga/services/api_client.dart';

export 'package:suga/services/api_client.dart' show ApiErrorKind, ApiException, friendlyError;

class InterruptionService {
  InterruptionService({http.Client? client, String? baseUrl})
      : _api = ApiClient(client: client, baseUrl: baseUrl);

  final ApiClient _api;

  // Needed for create, update and delete. AuthProvider sets it after the admin signs in.
  set authToken(String? token) => _api.authToken = token;

  // Pass [areaId] to get only the interruptions that affect that area.
  Future<List<PowerInterruption>> fetchInterruptions({int? areaId}) async {
    final body = await _api.get('/api/interruptions', query: {
      if (areaId != null) 'area_id': '$areaId',
    });
    return ApiClient.parseList(body, PowerInterruption.fromJson);
  }

  Future<PowerInterruption> fetchInterruption(int id) async {
    final body = await _api.get('/api/interruptions/$id');
    return ApiClient.parseOne(body, PowerInterruption.fromJson);
  }

  // Returns the saved interruption, including the id the server gave it.
  Future<PowerInterruption> createInterruption(PowerInterruption interruption) async {
    final body = await _api.post('/api/interruptions', interruption.toRequestJson());
    return ApiClient.parseOne(body, PowerInterruption.fromJson);
  }

  Future<PowerInterruption> updateInterruption(int id, PowerInterruption interruption) async {
    final body = await _api.patch('/api/interruptions/$id', interruption.toRequestJson());
    return ApiClient.parseOne(body, PowerInterruption.fromJson);
  }

  Future<void> deleteInterruption(int id) => _api.delete('/api/interruptions/$id');
}
