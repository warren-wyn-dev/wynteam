import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/follow/data/follow_request_repository.dart';
import 'package:wyn/features/profile/data/profile.dart';

/// A FollowRequestRepository whose network-touching methods are
/// overridden to just record what they were called with / return canned
/// data, instead of making a real Supabase call. Mirrors
/// RecordingFollowRepository -- see .wyn/learning/PATTERNS.md.
class RecordingFollowRequestRepository extends FollowRequestRepository {
  RecordingFollowRequestRepository({
    this.hasPendingRequestResult = false,
    List<Profile>? pendingRequests,
    this.countPendingRequestsResult = 0,
    this.sendRequestError,
    this.cancelRequestError,
    this.acceptRequestError,
    this.rejectRequestError,
  })  : pendingRequests = pendingRequests ?? [],
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [hasPendingRequest], regardless of userId.
  bool hasPendingRequestResult;

  /// Returned by [fetchPendingRequests] for page 0 only (page 1+ returns
  /// empty).
  final List<Profile> pendingRequests;

  /// Returned by [countPendingRequests].
  int countPendingRequestsResult;

  Object? sendRequestError;
  Object? cancelRequestError;
  Object? acceptRequestError;
  Object? rejectRequestError;

  int sendRequestCalls = 0;
  int cancelRequestCalls = 0;
  final List<String> acceptRequestArgs = [];
  final List<String> rejectRequestArgs = [];

  @override
  Future<void> sendRequest({required String userId}) async {
    sendRequestCalls++;
    final error = sendRequestError;
    if (error != null) throw error;
  }

  @override
  Future<void> cancelRequest({required String userId}) async {
    cancelRequestCalls++;
    final error = cancelRequestError;
    if (error != null) throw error;
  }

  @override
  Future<void> acceptRequest({required String requesterId}) async {
    acceptRequestArgs.add(requesterId);
    final error = acceptRequestError;
    if (error != null) throw error;
  }

  @override
  Future<void> rejectRequest({required String requesterId}) async {
    rejectRequestArgs.add(requesterId);
    final error = rejectRequestError;
    if (error != null) throw error;
  }

  @override
  Future<bool> hasPendingRequest({required String userId}) async =>
      hasPendingRequestResult;

  @override
  Future<List<Profile>> fetchPendingRequests({required int page}) async {
    return page == 0 ? pendingRequests : <Profile>[];
  }

  @override
  Future<int> countPendingRequests() async => countPendingRequestsResult;
}
