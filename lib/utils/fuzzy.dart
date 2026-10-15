// Tolerant search helpers used by the search screen.
// Pure functions with no dependencies so they are easy to unit test.

// Lowercase the text, replace every run of non-alphanumeric characters
// with a single space, then collapse whitespace and trim.
// Unicode letters and numbers are kept, so non-Latin scripts still work.
String normalize(String text) {
  final lower = text.toLowerCase();
  final spaced =
      lower.replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ');
  final collapsed = spaced.replaceAll(RegExp(r'\s+'), ' ');
  return collapsed.trim();
}

// Return true when every normalized query token appears as a substring
// of the normalized haystack. Token order does not matter, so
// "faded alan walker" matches "Faded - Alan Walker".
// An empty or blank query matches everything (vacuous truth).
// A non-empty query never matches an empty haystack.
bool fuzzyMatch(String haystack, String query) {
  final normalizedHaystack = normalize(haystack);
  final normalizedQuery = normalize(query);
  if (normalizedQuery.isEmpty) return true;
  if (normalizedHaystack.isEmpty) return false;
  final tokens = normalizedQuery.split(' ');
  for (final token in tokens) {
    if (token.isEmpty) continue;
    if (!normalizedHaystack.contains(token)) return false;
  }
  return true;
}
