#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
#
Pod::Spec.new do |s|
  s.name             = 'paypal_checkout_flutter'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for PayPal payments on iOS and Android.'
  s.description      = <<-DESC
A Flutter package for PayPal payments using Pigeon for type-safe communication.
Supports PayPal checkout, card payments, and vaulting.
                       DESC
  s.homepage         = 'https://github.com/IgnacioMan1998/flutter_paypal_payment'
  s.license          = { :type => 'BSD', :file => '../LICENSE' }
  s.author           = { 'Danis Manchu' => 'your-email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'PayPal/CorePayments', '~> 2.0'
  s.dependency 'PayPal/CardPayments', '~> 2.0'
  s.dependency 'PayPal/PayPalWebPayments', '~> 2.0'
  s.platform         = :ios, '16.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
