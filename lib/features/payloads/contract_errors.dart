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
