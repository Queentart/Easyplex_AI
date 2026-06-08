/// Form field validators returning a Korean error string or null when valid.
class Validators {
  Validators._();

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? required(String? value, {String field = '값'}) {
    if (value == null || value.trim().isEmpty) return '$field을(를) 입력해주세요.';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return '이메일을 입력해주세요.';
    if (!_email.hasMatch(value.trim())) return '올바른 이메일 형식이 아닙니다.';
    return null;
  }

  static String? password(String? value, {int min = 8}) {
    if (value == null || value.isEmpty) return '비밀번호를 입력해주세요.';
    if (value.length < min) return '비밀번호는 최소 $min자 이상이어야 합니다.';
    return null;
  }
}
