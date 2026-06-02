## 🔧 API Documentation - MosqueService

### Overview
`MosqueService` is a singleton service that manages mosques and student data in Firebase Firestore with automatic synchronization.

---

## Class: MosqueService

### Factory Constructor
```dart
// Get singleton instance
final mosqueService = MosqueService();
```

---

## 🕌 Mosque Management Methods

### createMosque()
Creates a new mosque with Firebase auto-generating a unique ID.

```dart
Future<Mosque> createMosque({
  required String name,
  required String location,
  required String supervisor,
  String? phone,
})
```

**Parameters:**
- `name` (String): Mosque name
- `location` (String): Mosque location
- `supervisor` (String): Supervisor name
- `phone` (String, optional): Phone number

**Returns:** `Future<Mosque>` - The created mosque with Firebase-generated ID

**Example:**
```dart
final mosque = await mosqueService.createMosque(
  name: 'Mosque Al-Noor',
  location: 'Algiers',
  supervisor: 'Ahmed Mohamed',
  phone: '212612345678',
);
print('Created mosque with ID: ${mosque.id}');
```

---

### getMosques()
Fetches all mosques (one-time fetch with caching).

```dart
Future<List<Mosque>> getMosques()
```

**Returns:** `Future<List<Mosque>>`

**Example:**
```dart
try {
  final mosques = await mosqueService.getMosques();
  for (var mosque in mosques) {
    print('${mosque.name} - ${mosque.location}');
  }
} catch (e) {
  print('Error: $e');
}
```

---

### watchMosques()
Real-time listener for all mosques (updates automatically).

```dart
Stream<List<Mosque>> watchMosques()
```

**Returns:** `Stream<List<Mosque>>`

**Example:**
```dart
mosqueService.watchMosques().listen((mosques) {
  setState(() {
    _mosques = mosques;
  });
});
```

---

### getMosque()
Fetch a single mosque by ID.

```dart
Future<Mosque?> getMosque(String mosqueId)
```

**Parameters:**
- `mosqueId` (String): Firebase-generated mosque ID

**Returns:** `Future<Mosque?>` - Returns null if not found

**Example:**
```dart
final mosque = await mosqueService.getMosque('mosque_id_123');
if (mosque != null) {
  print('Found: ${mosque.name}');
}
```

---

### updateMosque()
Update mosque information.

```dart
Future<void> updateMosque(Mosque mosque)
```

**Parameters:**
- `mosque` (Mosque): Updated mosque object

**Example:**
```dart
final updated = mosque.copyWith(
  supervisor: 'New Supervisor Name',
);
await mosqueService.updateMosque(updated);
```

---

### deleteMosque()
⚠️ Deletes mosque and ALL associated student data and halqas.

```dart
Future<void> deleteMosque(String mosqueId)
```

**Parameters:**
- `mosqueId` (String): ID of mosque to delete

**Example:**
```dart
await mosqueService.deleteMosque('mosque_id_123');
```

---

## 👥 Student Management Methods

### getMosqueStudents()
Fetch all students in a mosque.

```dart
Future<List<Student>> getMosqueStudents(String mosqueId)
```

**Parameters:**
- `mosqueId` (String): Mosque ID

**Returns:** `Future<List<Student>>`

**Example:**
```dart
final students = await mosqueService.getMosqueStudents('mosque_id_123');
print('Found ${students.length} students');
```

---

### watchMosqueStudents()
Real-time listener for students in a mosque.

```dart
Stream<List<Student>> watchMosqueStudents(String mosqueId)
```

**Returns:** `Stream<List<Student>>`

**Example:**
```dart
mosqueService.watchMosqueStudents('mosque_id_123').listen((students) {
  setState(() => _students = students);
});
```

---

### addStudentToMosque()
Add a new student to a mosque.

```dart
Future<void> addStudentToMosque(String mosqueId, Student student)
```

**Parameters:**
- `mosqueId` (String): Target mosque ID
- `student` (Student): Student object to add

**Example:**
```dart
final student = Student(
  id: 'student_123',
  name: 'Ali',
  halqa: 'Halqa 1',
);
await mosqueService.addStudentToMosque('mosque_id_123', student);
```

---

### updateStudentInMosque()
Update a student in a mosque.

```dart
Future<void> updateStudentInMosque(String mosqueId, Student student)
```

**Example:**
```dart
final updated = student.copyWith(
  stars: student.stars + 10,
);
await mosqueService.updateStudentInMosque('mosque_id_123', updated);
```

---

### deleteStudentFromMosque()
Remove a student from a mosque.

```dart
Future<void> deleteStudentFromMosque(String mosqueId, String studentId)
```

**Example:**
```dart
await mosqueService.deleteStudentFromMosque('mosque_id_123', 'student_123');
```

---

## 📤 Transfer Methods

### transferStudent()
Move a student from one mosque to another (removes from source, atomic operation).

```dart
Future<void> transferStudent({
  required String studentId,
  required String fromMosqueId,
  required String toMosqueId,
  required Student student,
})
```

**Parameters:**
- `studentId` (String): Student ID
- `fromMosqueId` (String): Source mosque ID
- `toMosqueId` (String): Destination mosque ID
- `student` (Student): Student object

**Returns:** `Future<void>`

**Example:**
```dart
await mosqueService.transferStudent(
  studentId: 'student_123',
  fromMosqueId: 'mosque_1',
  toMosqueId: 'mosque_2',
  student: student,
);
```

**What it does:**
- ✅ Adds student to destination mosque
- ✅ Removes student from source mosque
- ✅ Records transfer in `transfers` collection
- ✅ Marks student with `transferredAt` timestamp
- ⚠️ Atomic operation - either fully succeeds or fully fails

---

### copyStudentToMosque()
Copy a student to another mosque WITHOUT removing from source.

```dart
Future<void> copyStudentToMosque({
  required String studentId,
  required String fromMosqueId,
  required String toMosqueId,
  required Student student,
})
```

**Example:**
```dart
await mosqueService.copyStudentToMosque(
  studentId: 'student_123',
  fromMosqueId: 'mosque_1',
  toMosqueId: 'mosque_2',
  student: student,
);
```

**What it does:**
- ✅ Adds student to destination mosque
- ✅ Keeps student in source mosque
- ✅ Records copy in `transfers_copies` collection
- ✅ Marks student with `copiedAt` timestamp

---

## 📚 Halqa (Group) Methods

### getMosqueHalqas()
Get all halqas (groups) in a mosque.

```dart
Future<List<String>> getMosqueHalqas(String mosqueId)
```

**Example:**
```dart
final halqas = await mosqueService.getMosqueHalqas('mosque_id_123');
// Returns: ['الحلقة الأولى', 'الحلقة الثانية', 'الحلقة الثالثة']
```

---

### watchMosqueHalqas()
Real-time listener for halqas.

```dart
Stream<List<String>> watchMosqueHalqas(String mosqueId)
```

---

### addHalqaToMosque()
Add a new halqa to a mosque.

```dart
Future<void> addHalqaToMosque(String mosqueId, String halqa)
```

**Example:**
```dart
await mosqueService.addHalqaToMosque('mosque_id_123', 'الحلقة الرابعة');
```

---

### deleteHalqaFromMosque()
Delete a halqa from a mosque (unlinks all students).

```dart
Future<void> deleteHalqaFromMosque(String mosqueId, String halqa)
```

---

### getMosqueStatistics()
Get statistics about students per halqa.

```dart
Future<Map<String, int>> getMosqueStatistics(String mosqueId)
```

**Returns:** `Future<Map<String, int>>` - Halqa name mapped to student count

**Example:**
```dart
final stats = await mosqueService.getMosqueStatistics('mosque_id_123');
// Returns: {
//   'الحلقة الأولى': 15,
//   'الحلقة الثانية': 12,
//   'الحلقة الثالثة': 8,
// }
```

---

## 📊 Data Models

### Mosque
```dart
class Mosque {
  final String id;              // Firebase-generated unique ID
  final String name;            // Mosque name
  final String location;        // Location
  final String supervisor;      // Supervisor name
  final String? phone;          // Optional phone number
  final DateTime createdAt;     // Creation timestamp
  final DateTime updatedAt;     // Last update timestamp

  // Methods
  Mosque copyWith({...});      // Create modified copy
  Map<String, dynamic> toMap(); // Convert to map
  String toJson();              // Convert to JSON
}
```

---

## 🔄 Error Handling

All methods throw exceptions on failure. Always use try-catch:

```dart
try {
  final mosque = await mosqueService.createMosque(
    name: 'Mosque Al-Fajr',
    location: 'Casablanca',
    supervisor: 'Muhammad Ali',
  );
  print('Success: ${mosque.id}');
} on FirebaseException catch (e) {
  print('Firebase Error: ${e.message}');
} catch (e) {
  print('General Error: $e');
}
```

---

## 💾 Offline Support

- ✅ MosqueService uses Firebase's offline persistence
- ✅ Write operations are queued when offline
- ✅ Synced automatically when internet returns
- ✅ Local cache is always available for reads

---

## 📝 Best Practices

1. **Use streams for real-time updates:**
   ```dart
   // Good ✅
   watchMosqueStudents('mosque_id').listen(...)
   
   // Less ideal for real-time
   Timer.periodic(...) { getMosqueStudents('mosque_id') }
   ```

2. **Use copyWith() for updates:**
   ```dart
   // Good ✅
   final updated = mosque.copyWith(supervisor: 'New Name');
   await mosqueService.updateMosque(updated);
   
   // Avoid ❌
   mosque.supervisor = 'New Name'; // Doesn't persist
   ```

3. **Atomic transfers:**
   ```dart
   // Good ✅ - Atomic operation
   await mosqueService.transferStudent(...);
   
   // Avoid ❌ - Two operations = risk of inconsistency
   await mosqueService.deleteStudentFromMosque(...);
   await mosqueService.addStudentToMosque(...);
   ```

4. **Handle errors properly:**
   ```dart
   // Good ✅
   try {
     final mosque = await mosqueService.getMosque('id');
   } catch (e) {
     ScaffoldMessenger.of(context).showSnackBar(...);
   }
   ```

---

## 🗂️ Collection Structure

```
Firestore
├── mosques/{mosqueId}
│   ├── (mosque document fields)
│   ├── students/{studentId}
│   │   └── (student document fields)
│   └── halqas/{halqaName}
│       └── (halqa document fields)
├── transfers/{transferId}
│   └── (transfer record)
└── transfers_copies/{copyId}
    └── (copy record)
```

---

**Version**: 2.0.0  
**Last Updated**: 2026-05-06
