class EmailDomainPolicy {
  static const String _rawAllowedDomains = String.fromEnvironment(
    'ALLOWED_STUDENT_EMAIL_DOMAINS',
    defaultValue: 'iu.edu.jo,iu.edu.co,.edu.jo,.edu.co',
  );

  static List<String> get allowedDomains => _rawAllowedDomains
      .split(',')
      .map((String value) => value.trim().toLowerCase())
      .where((String value) => value.isNotEmpty)
      .toSet()
      .toList();

  static bool isAllowedStudentEmail(String value) {
    final String email = value.trim().toLowerCase();
    final List<String> domains = allowedDomains;
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
