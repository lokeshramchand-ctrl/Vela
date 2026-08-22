import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String email,
    String? fullName,
    required bool isActive,
    required DateTime createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

extension UserDisplay on User {
  /// Up to 2 uppercase initials from [fullName], falling back to the first
  /// letter of [email] when no name is set.
  String get initials {
    final trimmedName = fullName?.trim();
    if (trimmedName == null || trimmedName.isEmpty) return email.substring(0, 1).toUpperCase();
    return trimmedName.split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase();
  }
}
