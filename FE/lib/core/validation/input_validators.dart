abstract final class InputValidators {
  static String? nickname(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 2 || text.length > 20) return '닉네임은 2~20자로 입력해 주세요.';
    return null;
  }

  static String? email(String? value) {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')) {
      return '올바른 이메일 주소를 입력해 주세요.';
    }
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.length < 8 ||
        text.length > 64 ||
        !RegExp('[a-zA-Z]').hasMatch(text) ||
        !RegExp('[0-9]').hasMatch(text)) {
      return '8~64자, 영문과 숫자를 함께 사용해 주세요.';
    }
    return null;
  }

  static String? metric(
    String? value, {
    required String label,
    required num min,
    required num max,
    bool integer = false,
  }) {
    final number = num.tryParse(value?.trim() ?? '');
    if (number == null ||
        !number.isFinite ||
        number < min ||
        number > max ||
        (integer && number != number.roundToDouble())) {
      return '$min~$max${integer ? ' 정수' : ''}';
    }
    return null;
  }
}
