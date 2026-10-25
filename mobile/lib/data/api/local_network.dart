/// Whether [host] is this computer or a device in a home network: localhost,
/// the Android emulator's 10.0.2.2, the private IPv4 ranges (10/8,
/// 172.16/12, 192.168/16), Tailscale's 100.64/10 and `.local` names.
///
/// Such a server is a developer's computer running the API locally: it
/// answers within milliseconds when it is up. The app normally talks to the
/// server on the internet (`CB_API_BASE_URL`).
bool isLocalNetworkHost(String host) {
  final name = host.toLowerCase();
  if (name == 'localhost' || name.endsWith('.local')) return true;
  final parts = name.split('.');
  if (parts.length != 4) return false;
  final bytes = [for (final part in parts) int.tryParse(part)];
  if (bytes.any((b) => b == null || b < 0 || b > 255)) return false;
  final a = bytes[0]!;
  final b = bytes[1]!;
  return a == 127 ||
      a == 10 ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 192 && b == 168) ||
      (a == 100 && b >= 64 && b <= 127);
}
