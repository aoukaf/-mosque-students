## 💻 Code Examples - Mosque Management System

### Complete Example 1: Create a Mosque and Add Students

```dart
import 'package:flutter/material.dart';
import '../models/mosque_service.dart';
import '../models/mosque.dart';
import '../models/student.dart';

class MosqueSetupExample extends StatefulWidget {
  @override
  State<MosqueSetupExample> createState() => _MosqueSetupExampleState();
}

class _MosqueSetupExampleState extends State<MosqueSetupExample> {
  final _mosqueService = MosqueService();
  Mosque? _createdMosque;
  List<Student> _students = [];

  Future<void> _setupMosque() async {
    try {
      // Step 1: Create a new mosque
      final mosque = await _mosqueService.createMosque(
        name: 'Mosque Al-Noor',
        location: 'Algiers, Algeria',
        supervisor: 'Ahmed Mohamed',
        phone: '212612345678',
      );
      
      setState(() => _createdMosque = mosque);
      print('✅ Mosque created with ID: ${mosque.id}');

      // Step 2: Create sample students
      final students = [
        Student(
          id: 'student_1',
          name: 'Ali Hassan',
          halqa: 'الحلقة الأولى',
          partsCompleted: 5,
          stars: 100,
        ),
        Student(
          id: 'student_2',
          name: 'Fatima Ahmed',
          halqa: 'الحلقة الثانية',
          partsCompleted: 3,
          stars: 50,
        ),
      ];

      // Step 3: Add students to mosque
      for (var student in students) {
        await _mosqueService.addStudentToMosque(mosque.id, student);
        print('✅ Added student: ${student.name}');
      }

      setState(() => _students = students);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Setup complete! Mosque ID: ${mosque.id}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mosque Setup Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _setupMosque,
              child: const Text('Create Mosque & Add Students'),
            ),
            if (_createdMosque != null) ...[
              const SizedBox(height: 20),
              Text('Mosque: ${_createdMosque!.name}'),
              Text('ID: ${_createdMosque!.id}'),
              Text('Students: ${_students.length}'),
            ],
          ],
        ),
      ),
    );
  }
}
```

---

### Complete Example 2: Real-time Student List for a Mosque

```dart
class MosqueStudentsListScreen extends StatefulWidget {
  final String mosqueId;
  
  const MosqueStudentsListScreen({required this.mosqueId});

  @override
  State<MosqueStudentsListScreen> createState() =>
      _MosqueStudentsListScreenState();
}

class _MosqueStudentsListScreenState extends State<MosqueStudentsListScreen> {
  final _mosqueService = MosqueService();
  late Stream<List<Student>> _studentsStream;
  late Stream<List<String>> _halqasStream;

  @override
  void initState() {
    super.initState();
    // Listen to real-time updates
    _studentsStream = _mosqueService.watchMosqueStudents(widget.mosqueId);
    _halqasStream = _mosqueService.watchMosqueHalqas(widget.mosqueId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Students in Mosque'),
        subtitle: Text(widget.mosqueId),
      ),
      body: StreamBuilder<List<Student>>(
        stream: _studentsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final students = snapshot.data ?? [];

          if (students.isEmpty) {
            return const Center(
              child: Text('No students in this mosque'),
            );
          }

          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return ListTile(
                leading: CircleAvatar(child: Text(student.name[0])),
                title: Text(student.name),
                subtitle: Text('${student.halqa} - ⭐ ${student.stars}'),
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Text('Edit'),
                      onTap: () => _editStudent(student),
                    ),
                    PopupMenuItem(
                      child: const Text('Delete'),
                      onTap: () => _deleteStudent(student),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editStudent(Student student) async {
    // Implementation for editing
  }

  Future<void> _deleteStudent(Student student) async {
    try {
      await _mosqueService.deleteStudentFromMosque(
        widget.mosqueId,
        student.id,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
```

---

### Complete Example 3: Transfer Students Between Mosques

```dart
class TransferStudentExample {
  final _mosqueService = MosqueService();

  // Scenario: Move a student from Mosque A to Mosque B
  Future<void> transferStudentBetweenMosques({
    required String studentId,
    required Student studentData,
    required String sourceMosqueId,
    required String destinationMosqueId,
  }) async {
    try {
      print('📤 Starting transfer...');
      print('From: $sourceMosqueId → To: $destinationMosqueId');
      
      // Perform atomic transfer
      await _mosqueService.transferStudent(
        studentId: studentId,
        fromMosqueId: sourceMosqueId,
        toMosqueId: destinationMosqueId,
        student: studentData,
      );
      
      print('✅ Transfer completed successfully!');
      print('✅ Transfer record saved automatically');
    } catch (e) {
      print('❌ Transfer failed: $e');
      rethrow;
    }
  }

  // Scenario: Share a student (copy) from Mosque A to Mosque B
  Future<void> copyStudentToAnotherMosque({
    required String studentId,
    required Student studentData,
    required String sourceMosqueId,
    required String destinationMosqueId,
  }) async {
    try {
      print('📋 Starting copy...');
      
      await _mosqueService.copyStudentToMosque(
        studentId: studentId,
        fromMosqueId: sourceMosqueId,
        toMosqueId: destinationMosqueId,
        student: studentData,
      );
      
      print('✅ Copy completed!');
      print('✅ Original student still exists in source mosque');
    } catch (e) {
      print('❌ Copy failed: $e');
      rethrow;
    }
  }
}

// Usage in a Widget
class TransferStudentWidget extends StatefulWidget {
  @override
  State<TransferStudentWidget> createState() => _TransferStudentWidgetState();
}

class _TransferStudentWidgetState extends State<TransferStudentWidget> {
  final _example = TransferStudentExample();
  bool _isTransferring = false;

  Future<void> _performTransfer(
    String studentId,
    Student student,
    String fromId,
    String toId,
  ) async {
    setState(() => _isTransferring = true);
    
    try {
      await _example.transferStudentBetweenMosques(
        studentId: studentId,
        studentData: student,
        sourceMosqueId: fromId,
        destinationMosqueId: toId,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Student transferred successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Transfer failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTransferring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isTransferring
          ? null
          : () => _performTransfer(
            'student_123',
            Student(id: 'student_123', name: 'Ali', halqa: 'Halqa 1'),
            'mosque_1',
            'mosque_2',
          ),
      child: _isTransferring
          ? const CircularProgressIndicator()
          : const Text('Transfer Student'),
    );
  }
}
```

---

### Example 4: Bulk Operations (Transfer Multiple Students)

```dart
class BulkTransferExample {
  final _mosqueService = MosqueService();

  Future<void> transferMultipleStudents({
    required List<Student> students,
    required String fromMosqueId,
    required String toMosqueId,
  }) async {
    int successful = 0;
    int failed = 0;

    for (final student in students) {
      try {
        await _mosqueService.transferStudent(
          studentId: student.id,
          fromMosqueId: fromMosqueId,
          toMosqueId: toMosqueId,
          student: student,
        );
        successful++;
        print('✅ Transferred: ${student.name}');
      } catch (e) {
        failed++;
        print('❌ Failed to transfer ${student.name}: $e');
      }
    }

    print('\n📊 Results:');
    print('✅ Successful: $successful');
    print('❌ Failed: $failed');
    print('📈 Total: ${students.length}');
  }

  // Example usage
  Future<void> demo() async {
    final students = [
      Student(id: 's1', name: 'Ali', halqa: 'H1'),
      Student(id: 's2', name: 'Fatima', halqa: 'H2'),
      Student(id: 's3', name: 'Omar', halqa: 'H1'),
    ];

    await transferMultipleStudents(
      students: students,
      fromMosqueId: 'mosque_1',
      toMosqueId: 'mosque_2',
    );
  }
}
```

---

### Example 5: Get Statistics for a Mosque

```dart
class MosqueStatisticsExample {
  final _mosqueService = MosqueService();

  Future<void> displayMosqueStats(String mosqueId) async {
    try {
      // Get basic info
      final mosque = await _mosqueService.getMosque(mosqueId);
      if (mosque == null) {
        print('❌ Mosque not found');
        return;
      }

      // Get all students
      final students = await _mosqueService.getMosqueStudents(mosqueId);

      // Get statistics
      final stats = await _mosqueService.getMosqueStatistics(mosqueId);

      // Calculate totals
      final totalStars = students.fold<int>(0, (sum, s) => sum + s.stars);
      final avgStars = students.isEmpty ? 0 : totalStars ~/ students.length;

      print('\n📊 Mosque Statistics: ${mosque.name}');
      print('📍 Location: ${mosque.location}');
      print('👤 Supervisor: ${mosque.supervisor}');
      print('🎓 Total Students: ${students.length}');
      print('⭐ Average Stars: $avgStars');
      print('📚 Total Stars: $totalStars');
      
      print('\n📈 Students per Halqa:');
      stats.forEach((halqa, count) {
        print('  • $halqa: $count students');
      });

    } catch (e) {
      print('❌ Error: $e');
    }
  }
}
```

---

### Example 6: Error Handling Best Practices

```dart
class ErrorHandlingExample {
  final _mosqueService = MosqueService();

  Future<void> robustTransfer(
    String studentId,
    Student student,
    String fromId,
    String toId,
  ) async {
    try {
      // Check if source mosque exists
      final sourceMosque = await _mosqueService.getMosque(fromId);
      if (sourceMosque == null) {
        throw Exception('Source mosque not found');
      }

      // Check if destination mosque exists
      final destMosque = await _mosqueService.getMosque(toId);
      if (destMosque == null) {
        throw Exception('Destination mosque not found');
      }

      // Check if student exists in source
      final sourceStudents = await _mosqueService.getMosqueStudents(fromId);
      if (!sourceStudents.any((s) => s.id == studentId)) {
        throw Exception('Student not found in source mosque');
      }

      // Perform transfer
      await _mosqueService.transferStudent(
        studentId: studentId,
        fromMosqueId: fromId,
        toMosqueId: toId,
        student: student,
      );

      print('✅ Transfer successful');
    } on FirebaseException catch (e) {
      print('❌ Firebase Error: ${e.message}');
      rethrow;
    } on Exception catch (e) {
      print('❌ Validation Error: $e');
      rethrow;
    } catch (e) {
      print('❌ Unknown Error: $e');
      rethrow;
    }
  }
}
```

---

### Example 7: Watch Real-time Changes

```dart
class RealtimeWatchExample extends StatefulWidget {
  final String mosqueId;

  const RealtimeWatchExample({required this.mosqueId});

  @override
  State<RealtimeWatchExample> createState() => _RealtimeWatchExampleState();
}

class _RealtimeWatchExampleState extends State<RealtimeWatchExample> {
  final _mosqueService = MosqueService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Real-time Mosque Updates')),
      body: Column(
        children: [
          // Watch all mosques
          Expanded(
            child: StreamBuilder<List<Mosque>>(
              stream: _mosqueService.watchMosques(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, i) {
                    final mosque = snapshot.data![i];
                    return ListTile(
                      title: Text(mosque.name),
                      subtitle: Text(mosque.location),
                    );
                  },
                );
              },
            ),
          ),
          
          // Watch students in specific mosque
          Expanded(
            child: StreamBuilder<List<Student>>(
              stream: _mosqueService.watchMosqueStudents(widget.mosqueId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, i) {
                    final student = snapshot.data![i];
                    return ListTile(
                      title: Text(student.name),
                      subtitle: Text('${student.halqa} - ⭐${student.stars}'),
                    );
                  },
                );
              },
            ),
          ),
          
          // Watch halqas in specific mosque
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: _mosqueService.watchMosqueHalqas(widget.mosqueId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, i) {
                    final halqa = snapshot.data![i];
                    return ListTile(title: Text(halqa));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

---

**Last Updated**: 2026-05-06  
**Version**: 2.0.0
