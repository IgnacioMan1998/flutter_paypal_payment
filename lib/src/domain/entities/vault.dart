import 'payment_card.dart';

/// Request to vault a PayPal account.
class VaultPaypalRequest {
  const VaultPaypalRequest({
    required this.setupTokenId,
  });

  /// The setup token created via PayPal Setup Tokens API.
  final String setupTokenId;
}

/// Request to vault a card.
class VaultCardRequest {
  const VaultCardRequest({
    required this.setupTokenId,
    required this.card,
  });

  /// The setup token created via PayPal Setup Tokens API.
  final String setupTokenId;

  /// The card to vault.
  final PaymentCard card;
}

/// Result of a vault operation.
sealed class VaultResult {
  const VaultResult();
}

class VaultSuccess extends VaultResult {
  const VaultSuccess({
    required this.setupTokenId,
    this.status,
  });

  final String setupTokenId;
  final String? status;
}

class VaultFailure extends VaultResult {
  const VaultFailure({
    required this.message,
    this.code,
  });

  final String message;
  final String? code;
}
