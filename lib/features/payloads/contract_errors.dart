enum ContractErrorCode {
  malformedPayload,
  unsupportedVersion,
  unsupportedKind,
  payloadTooLarge,
  invalidAcknowledgementReference,
}

class ContractError implements Exception {
  const ContractError(this.code, this.message);

  final ContractErrorCode code;
  final String message;

  @override
  String toString() => 'ContractError($code, $message)';
}

void validateAllowedKeys(
  Map<String, Object?> json,
  Set<String> allowedKeys,
  String objectName,
) {
  for (final key in json.keys) {
    if (!allowedKeys.contains(key)) {
      throw ContractError(
        ContractErrorCode.malformedPayload,
        '$objectName contains unsupported field: $key.',
      );
    }
  }
}
