# Flutter Model Best Practices

Guidelines for creating robust Dart models that handle API responses safely.

---

## fromJson Null Safety

All `fromJson()` factory constructors MUST handle:
1. Missing fields (null)
2. Renamed fields (API changed the field name)
3. Wrong types (API returns int instead of string)

### Pattern: Safe fromJson

```dart
class MaintenanceRequest {
  final String id;
  final String title;
  final String status;
  final String? adminNote;
  final List<String> photoUrls;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MaintenanceRequest({
    required this.id,
    required this.title,
    required this.status,
    this.adminNote,
    required this.photoUrls,
    required this.createdAt,
    this.updatedAt,
  });

  factory MaintenanceRequest.fromJson(Map<String, dynamic> json) {
    return MaintenanceRequest(
      // Required fields — provide type-safe defaults
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      
      // Enum-like fields — always have a safe default
      status: json['status'] as String? ?? 'pending',
      
      // Renamed fields — check both old and new names
      adminNote: (json['notes'] as String?) ?? (json['adminNote'] as String?),
      
      // Lists — cast safely with fallback to empty
      photoUrls: (json['photoUrls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      
      // Dates — parse with fallback
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      
      // Optional dates
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}
```

---

## Common Patterns

### Lists with nested objects

```dart
// ❌ Wrong — crashes if items is null
items: (json['items'] as List)
    .map((e) => Item.fromJson(e))
    .toList(),

// ✅ Correct — handles null list
items: (json['items'] as List<dynamic>?)
    ?.map((e) => Item.fromJson(e as Map<String, dynamic>))
    .toList() ?? [],
```

### Numeric fields

```dart
// ❌ Wrong — crashes if amount is null or int
amount: json['amount'] as double,

// ✅ Correct — handles int, double, and null
amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
```

### Boolean fields

```dart
// ❌ Wrong — crashes if field is missing
isActive: json['isActive'] as bool,

// ✅ Correct — handles null
isActive: json['isActive'] as bool? ?? false,
```

### Nested objects

```dart
// ❌ Wrong — crashes if unit is null
unit: Unit.fromJson(json['unit']),

// ✅ Correct — handles null
unit: json['unit'] != null 
    ? Unit.fromJson(json['unit'] as Map<String, dynamic>) 
    : null,
```

### Flat vs nested fields

Sometimes API returns nested data, sometimes flat. Handle both:

```dart
// API might return either:
// { "user": { "name": "John" } }  OR  { "userName": "John" }

final userName = (json['user'] as Map<String, dynamic>?)?['name'] as String?
    ?? json['userName'] as String?
    ?? '';
```

---

## Enum Handling

Backend returns lowercase strings. Map to Dart enums safely:

```dart
enum BillStatus { pending, paid, overdue, cancelled }

factory Bill.fromJson(Map<String, dynamic> json) {
  final statusStr = json['status'] as String? ?? 'pending';
  final status = BillStatus.values.firstWhere(
    (s) => s.name == statusStr,
    orElse: () => BillStatus.pending,  // Safe fallback
  );
  
  return Bill(status: status, ...);
}
```

---

## Date Parsing

Always handle invalid dates gracefully:

```dart
DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}

// Usage
createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
```

---

## toJson for API requests

When sending data TO the API, match the field names the backend expects:

```dart
Map<String, dynamic> toJson() {
  return {
    'title': title,
    'description': description,
    'category': category.toUpperCase(),  // Backend expects UPPERCASE
    'photoUrls': photoUrls,
  };
}
```

---

## Testing Models

Always test fromJson with edge cases:

```dart
void main() {
  group('MaintenanceRequest.fromJson', () {
    test('handles complete data', () {
      final json = {'id': '123', 'title': 'Fix AC', 'status': 'pending'};
      final request = MaintenanceRequest.fromJson(json);
      expect(request.id, '123');
    });

    test('handles missing optional fields', () {
      final json = {'id': '123', 'title': 'Fix AC'};
      final request = MaintenanceRequest.fromJson(json);
      expect(request.status, 'pending');  // Default
      expect(request.photoUrls, isEmpty);  // Empty list
    });

    test('handles renamed fields', () {
      final json = {'id': '123', 'title': 'Fix AC', 'notes': 'Check filter'};
      final request = MaintenanceRequest.fromJson(json);
      expect(request.adminNote, 'Check filter');  // Mapped from 'notes'
    });

    test('handles null response gracefully', () {
      final json = <String, dynamic>{};
      // Should not throw, should return object with defaults
      expect(() => MaintenanceRequest.fromJson(json), returnsNormally);
    });
  });
}
```

---

## Checklist

Before shipping a model:

```
[ ] All required fields have ?? fallback defaults
[ ] All lists use ?.map() ?? [] pattern
[ ] All nested objects check for null before parsing
[ ] All dates use try/catch or null-safe parsing
[ ] All enums use firstWhere with orElse fallback
[ ] Renamed fields check both old and new names
[ ] Model is tested with empty/partial JSON
```
