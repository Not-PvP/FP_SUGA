import 'package:http/http.dart' as http;
import 'package:suga/models/area.dart';
import 'package:suga/services/api_client.dart';

export 'package:suga/services/api_client.dart' show ApiException;

class AreaService {
  AreaService({http.Client? client, String? baseUrl})
      : _api = ApiClient(client: client, baseUrl: baseUrl);

  final ApiClient _api;

  Future<List<Area>> fetchAreas({String? search}) async {
    final body = await _api.get('/api/areas', query: {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });
    return [
      for (final item in body['data'] as List<dynamic>)
        Area.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<Area> fetchArea(int id) async {
    final body = await _api.get('/api/areas/$id');
    return Area.fromJson(body['data'] as Map<String, dynamic>);
  }
}
