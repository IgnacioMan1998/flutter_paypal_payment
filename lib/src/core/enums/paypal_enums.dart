/// PayPal SDK environment.
enum PaypalEnvironment { sandbox, live }

/// Funding source for a PayPal web checkout payment.
enum PaypalFundingSource {
  /// Standard PayPal checkout.
  paypal,

  /// Pay Later (e.g. Pay in 4, Pagar en 3 plazos).
  payLater,

  /// Venmo (US only). Opens the Venmo app when available.
  venmo,

  /// PayPal Credit card (revolving line of credit).
  credit,

  /// Debit card via PayPal.
  debit,
}


