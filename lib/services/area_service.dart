import 'package:http/http.dart' as http;
import 'package:suga/models/area.dart';
import 'package:suga/services/api_client.dart';

export 'package:suga/services/api_client.dart' show ApiErrorKind, ApiException, friendlyError;

class AreaService {
  AreaService({http.Client? client, String? baseUrl})
      : _api = ApiClient(client: client, baseUrl: baseUrl);

  final ApiClient _api;

  Future<List<Area>> fetchAreas({String? search}) async {
    final body = await _api.get('/api/areas', query: {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });
    return ApiClient.parseList(body, Area.fromJson);
  }

  Future<Area> fetchArea(int id) async {
    final body = await _api.get('/api/areas/$id');
    return ApiClient.parseOne(body, Area.fromJson);
  }
}
