import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlHelper {
  /// Format phone number into clean international digits without leading zeroes
  static String formatPhoneNumber(String phone) {
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      digits = digits.replaceFirst(RegExp(r'^0+'), '');
    }
    // If it's a 10-digit Indian number, prepend 91
    if (digits.length == 10) {
      digits = '91$digits';
    }
    return digits;
  }

  /// Launch WhatsApp with multi-tier fallback (native app -> wa.me -> api.whatsapp.com)
  static Future<bool> launchWhatsApp({required String phone, required String message}) async {
    final cleanPhone = formatPhoneNumber(phone);
    if (cleanPhone.isEmpty) return false;

    final encodedMessage = Uri.encodeComponent(message);

    // 1. Native WhatsApp intent URI (fastest direct app opening on mobile)
    final nativeUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMessage');

    // 2. Standard Universal wa.me link
    final waMeUri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');

    // 3. Fallback web API link
    final apiUri = Uri.parse('https://api.whatsapp.com/send?phone=$cleanPhone&text=$encodedMessage');

    try {
      // On mobile devices, try native app intent first
      if (!kIsWeb) {
        if (await canLaunchUrl(nativeUri)) {
          final success = await launchUrl(nativeUri, mode: LaunchMode.externalNonBrowserApplication);
          if (success) return true;
        }
      }

      // Try wa.me
      if (await canLaunchUrl(waMeUri)) {
        final success = await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
        if (success) return true;
      }

      // Direct fallback attempts without canLaunchUrl blocking
      try {
        final success = await launchUrl(waMeUri, mode: LaunchMode.platformDefault);
        if (success) return true;
      } catch (_) {}

      if (await canLaunchUrl(apiUri)) {
        return await launchUrl(apiUri, mode: LaunchMode.externalApplication);
      }

      return await launchUrl(apiUri, mode: LaunchMode.platformDefault);
    } catch (e) {
      debugPrint('UrlHelper launchWhatsApp error: $e');
      return false;
    }
  }

  static Future<bool> launchPhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return false;
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (e) {
      debugPrint('UrlHelper launchPhoneCall error: $e');
      return false;
    }
  }
}
