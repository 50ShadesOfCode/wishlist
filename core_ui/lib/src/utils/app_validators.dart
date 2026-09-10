import 'package:form_builder_validators/form_builder_validators.dart';

/// Shared form validator compositions (single source of truth).
/// Rules mirror the documented constraints: email format, password ≥ 6
/// chars, username 3–30 chars, city ≤ 60 chars.
abstract final class AppValidators {
  static final email = FormBuilderValidators.compose([
    FormBuilderValidators.required(),
    FormBuilderValidators.email(),
  ]);

  static final password = FormBuilderValidators.compose([
    FormBuilderValidators.required(),
    FormBuilderValidators.minLength(6),
  ]);

  static final username = FormBuilderValidators.compose([
    FormBuilderValidators.required(),
    FormBuilderValidators.minLength(3),
    FormBuilderValidators.maxLength(30),
  ]);

  static final city = FormBuilderValidators.maxLength(60);

  static final requiredField = FormBuilderValidators.required();
}
