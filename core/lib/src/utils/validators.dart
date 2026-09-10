final _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class Validators {
  static bool isValidEmail(String value) => _emailRegExp.hasMatch(value);
  static bool isValidPassword(String value) => value.length >= 6;
  static bool isValidUsername(String value) =>
      value.trim().length >= 3 && value.trim().length <= 30;
}
