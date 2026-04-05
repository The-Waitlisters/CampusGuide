import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:proj/models/user_role.dart';
import 'package:proj/models/course_schedule_entry.dart';
import 'package:proj/services/auth/user_profile_service.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late MockFirebaseFirestore firestore;
  late MockCollectionReference usersCollection;
  late MockDocumentReference docRef;
  late MockDocumentSnapshot docSnapshot;
  late UserProfileService service;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    firestore = MockFirebaseFirestore();
    usersCollection = MockCollectionReference();
    docRef = MockDocumentReference();
    docSnapshot = MockDocumentSnapshot();

    when(() => firestore.collection('users')).thenReturn(usersCollection);
    when(() => usersCollection.doc(any())).thenReturn(docRef);
    when(() => docRef.get()).thenAnswer((_) async => docSnapshot);
    when(() => docRef.set(any())).thenAnswer((_) async {});

    service = UserProfileService(firestore: firestore);
  });

  test('createUserProfile writes expected fields', () async {
    await service.createUserProfile(
      uid: 'u1',
      email: 'u1@test.com',
      firstName: 'Sam',
      lastName: 'User',
    );

    verify(
          () => docRef.set(
        any(
          that: isA<Map<String, dynamic>>()
              .having((m) => m['email'], 'email', 'u1@test.com')
              .having((m) => m['role'], 'role', UserRole.user.value)
              .having((m) => m['firstName'], 'firstName', 'Sam')
              .having((m) => m['lastName'], 'lastName', 'User'),
        ),
      ),
    ).called(1);
  });

  test('getUserProfile returns document data', () async {
    when(() => docSnapshot.data()).thenReturn({
      'role': 'user-authenticated',
      'firstName': 'Sam',
    });

    final profile = await service.getUserProfile('u1');

    expect(profile, isNotNull);
    expect(profile!['firstName'], 'Sam');
  });

  test('getUserRole falls back to guest when data is null', () async {
    when(() => docSnapshot.data()).thenReturn(null);

    final role = await service.getUserRole('u1');

    expect(role, UserRole.guest);
  });

  test('getUserRole falls back to guest when role key is missing', () async {
    when(() => docSnapshot.data()).thenReturn({'firstName': 'NoRole'});

    final role = await service.getUserRole('u1');

    expect(role, UserRole.guest);
  });

  test('getUserRole maps persisted role value', () async {
    when(() => docSnapshot.data()).thenReturn({'role': 'student'});

    final role = await service.getUserRole('u1');

    expect(role, UserRole.user);
  });

  test('saveSchedule calls update with serialized entries', () async {
    when(() => docRef.update(any())).thenAnswer((_) async {});

    final entries = [
      const CourseScheduleEntry(
        courseCode: 'SOEN 363',
        section: 'LEC H',
        dayText: 'Mon - Wed',
        timeText: '08:45 - 10:00',
        room: 'H-937',
        campus: 'SGW',
        buildingCode: 'H',
      ),
    ];

    await service.saveSchedule(uid: 'u1', entries: entries);

    verify(() => docRef.update(any())).called(1);
  });

  test('loadSchedule returns empty list when data is null', () async {
    when(() => docSnapshot.data()).thenReturn(null);

    final result = await service.loadSchedule(uid: 'u1');

    expect(result, isEmpty);
  });

  test('loadSchedule returns empty list when schedule key is null', () async {
    when(() => docSnapshot.data()).thenReturn({'firstName': 'Sam'});

    final result = await service.loadSchedule(uid: 'u1');

    expect(result, isEmpty);
  });

}