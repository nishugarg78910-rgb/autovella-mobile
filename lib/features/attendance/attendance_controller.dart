import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/endpoints.dart';
import '../../core/providers/app_providers.dart';
import '../../core/util/json.dart';
import '../../models/hr.dart';

/// Today's attendance record for the signed-in user, or null before the
/// first check-in of the day.
final todayAttendanceProvider =
    FutureProvider.autoDispose<Attendance?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get(Api.attendanceToday);
  final json = J.mapOrNull(data);
  if (json == null || J.str(json['id']).isEmpty) return null;
  return Attendance.fromJson(json);
});

/// Recent attendance history.
final attendanceHistoryProvider =
    FutureProvider.autoDispose<List<Attendance>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.list(
    Api.attendance,
    Attendance.fromJson,
    query: {'limit': 30},
  );
});

/// Drives check-in / check-out.
///
/// Location is best-effort by design: a warehouse or basement office often
/// has no GPS fix, and refusing to let someone clock in because of that would
/// be worse than recording the punch without coordinates. Permission denial
/// and timeout both fall through to a location-less punch.
class AttendanceController extends StateNotifier<AsyncValue<void>> {
  AttendanceController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  /// The API has one punch endpoint and decides in/out itself
  /// (`{type: "auto"}`), so the UI does not have to track which way round
  /// it is — it only reports what happened.
  Future<bool> punch({String? notes}) async {
    state = const AsyncValue.loading();
    try {
      final position = await _tryLocate();
      await _ref.read(apiClientProvider).post(
        Api.attendancePunch,
        body: {
          'type': 'auto',
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (position != null) ...{
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
          },
        },
      );
      state = const AsyncValue.data(null);
      _ref.invalidate(todayAttendanceProvider);
      _ref.invalidate(attendanceHistoryProvider);
      return true;
    } on ApiException catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Returns a fix, or null if location is unavailable for any reason.
  Future<Position?> _tryLocate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

final attendanceControllerProvider =
    StateNotifierProvider<AttendanceController, AsyncValue<void>>(
  AttendanceController.new,
);
