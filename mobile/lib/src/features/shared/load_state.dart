enum LoadStatus {
  idle,
  loading,
  success,
  failure,
}

class LoadState<T> {
  const LoadState._({
    required this.status,
    this.value,
    this.error,
  });

  final LoadStatus status;
  final T? value;
  final Object? error;

  const LoadState.idle([T? value]) : this._(status: LoadStatus.idle, value: value);

  const LoadState.loading([T? value]) : this._(status: LoadStatus.loading, value: value);

  const LoadState.success(T value) : this._(status: LoadStatus.success, value: value);

  const LoadState.failure(Object error, [T? value])
      : this._(status: LoadStatus.failure, value: value, error: error);

  bool get hasValue => value != null;
}

