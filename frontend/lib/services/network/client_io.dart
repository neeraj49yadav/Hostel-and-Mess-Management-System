import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Resilient HTTP client for Android / iOS / Desktop:
/// Solves mobile 5G/4G & Hotspot "Network is unreachable (errno = 101)" by prioritizing
/// IPv4 connection establishment over unreachable NAT64 synthesized IPv6 prefixes.
http.Client createHttpClient() {
  final innerClient = HttpClient();
  innerClient.connectionTimeout = const Duration(seconds: 15);
  innerClient.badCertificateCallback = (cert, host, port) => true;

  innerClient.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
    dynamic target;
    try {
      // Prioritize IPv4 addresses on mobile cellular networks & hotspots
      final ipv4Addresses = await InternetAddress.lookup(uri.host, type: InternetAddressType.IPv4);
      target = ipv4Addresses.isNotEmpty ? ipv4Addresses.first : uri.host;
    } catch (_) {
      target = uri.host;
    }

    if (uri.scheme == 'https') {
      return SecureSocket.startConnect(
        target,
        uri.port,
        onBadCertificate: (cert) => true,
        supportedProtocols: ['http/1.1'],
      );
    } else {
      return Socket.startConnect(target, uri.port);
    }
  };

  return IOClient(innerClient);
}
