class EmailDomainPolicy {
  static const String _rawAllowedDomains = String.fromEnvironment(
    'ALLOWED_STUDENT_EMAIL_DOMAINS',
    defaultValue: 'iu.edu.jo,iu.edu.co,.edu.jo,.edu.co',
  );

  static const String _rawMicrosoftAllowedDomains = String.fromEnvironment(
    'MICROSOFT_ALLOWED_EMAIL_DOMAINS',
    defaultValue: 'iu.edu.jo',
  );

  static List<String> get allowedDomains => _rawAllowedDomains
      .split(',')
      .map((String value) => value.trim().toLowerCase())
      .where((String value) => value.isNotEmpty)
      .toSet()
      .toList();

  static List<String> get microsoftAllowedDomains => _rawMicrosoftAllowedDomains
      .split(',')
      .map((String value) => value.trim().toLowerCase())
      .where((String value) => value.isNotEmpty)
      .toSet()
      .toList();

  static bool isAllowedStudentEmail(String value) {
    final String email = value.trim().toLowerCase();
    return _isAllowedByDomains(email, allowedDomains);
  }

  static bool isAllowedMicrosoftEmail(String value) {
    final String email = value.trim().toLowerCase();
    return _isAllowedByDomains(email, microsoftAllowedDomains);
  }

  static bool _isAllowedByDomains(String email, List<String> domains) {
    if (email.isEmpty || !email.contains('@') || domains.isEmpty) {
      return false;
    }

    final int atIndex = email.lastIndexOf('@');
    if (atIndex <= 0 || atIndex == email.length - 1) {
      return false;
    }

    final String domain = email.substring(atIndex + 1);
    final String localPart = email.substring(0, atIndex);
    if (localPart.isEmpty || localPart.contains(' ')) {
      return false;
    }

    for (final String allowed in domains) {
      if (allowed.startsWith('.')) {
        if (domain.endsWith(allowed)) {
          return true;
        }
      } else if (domain == allowed) {
        return true;
      }
    }

    return false;
  }
}
