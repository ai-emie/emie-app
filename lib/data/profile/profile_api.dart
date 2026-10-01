import 'package:dio/dio.dart';
import '../../api/client.dart';

class EditableProfile {
  const EditableProfile(
      {required this.id,
      required this.email,
      required this.username,
      required this.bio,
      required this.dailyGoal});
  final String id, email, username, bio, dailyGoal;
  factory EditableProfile.fromJson(Map<String, dynamic> json) =>
      EditableProfile(
          id: json['id'] as String,
          email: json['email'] as String,
          username: json['username'] as String,
          bio: json['bio'] as String,
          dailyGoal: json['daily_goal'] as String);
}

class ProfileApi {
  ProfileApi({Dio? dio}) : dio = dio ?? ApiClient().dio;
  final Dio dio;
  Future<EditableProfile> get(int generation) async =>
      EditableProfile.fromJson((await dio.get('/v1/profile',
              options: ApiClient.sessionOptions(generation)))
          .data);
  Future<EditableProfile> save(
          {required String username,
          required String bio,
          required String dailyGoal,
          required int generation}) async =>
      EditableProfile.fromJson((await dio.put('/v1/profile',
              data: {'username': username, 'bio': bio, 'daily_goal': dailyGoal},
              options: ApiClient.sessionOptions(generation, noRefresh: true)))
          .data);
}
