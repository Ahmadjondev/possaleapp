/// Generic in-memory cache with TTL (time-to-live) and max-entries eviction.
class MemoryCache<K, V> {
  final Duration ttl;
  final int maxEntries;
  final _store = <K, _CacheEntry<V>>{};

  MemoryCache({required this.ttl, this.maxEntries = 50});

  /// Returns cached value if present and not expired, otherwise `null`.
  V? get(K key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.createdAt) > ttl) {
      _store.remove(key);
      return null;
    }
    return entry.value;
  }

  /// Stores a value. Evicts oldest entry if [maxEntries] exceeded.
  void set(K key, V value) {
    _store[key] = _CacheEntry(value: value, createdAt: DateTime.now());
    if (_store.length > maxEntries) {
      _store.remove(_store.keys.first);
    }
  }

  /// Removes a specific key.
  void invalidate(K key) => _store.remove(key);

  /// Removes all entries.
  void clear() => _store.clear();

  /// Whether the cache contains a non-expired entry for [key].
  bool has(K key) => get(key) != null;

  int get length => _store.length;
}

class _CacheEntry<V> {
  final V value;
  final DateTime createdAt;

  _CacheEntry({required this.value, required this.createdAt});
}
