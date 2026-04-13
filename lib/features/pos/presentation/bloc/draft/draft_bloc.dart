import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_terminal/core/network/api_exception.dart';
import 'package:pos_terminal/features/pos/data/models/draft_model.dart';
import 'package:pos_terminal/features/pos/data/pos_repository.dart';

// --- Events ---
sealed class DraftEvent extends Equatable {
  const DraftEvent();

  @override
  List<Object?> get props => [];
}

class DraftsLoadRequested extends DraftEvent {
  const DraftsLoadRequested();
}

class DraftSaveRequested extends DraftEvent {
  final Map<String, dynamic> payload;

  const DraftSaveRequested({required this.payload});

  @override
  List<Object?> get props => [payload];
}

class DraftLoadRequested extends DraftEvent {
  final int draftId;

  const DraftLoadRequested({required this.draftId});

  @override
  List<Object?> get props => [draftId];
}

class DraftDeleteRequested extends DraftEvent {
  final int draftId;

  const DraftDeleteRequested({required this.draftId});

  @override
  List<Object?> get props => [draftId];
}

// --- States ---
sealed class DraftState extends Equatable {
  const DraftState();

  @override
  List<Object?> get props => [];
}

class DraftInitial extends DraftState {
  const DraftInitial();
}

class DraftLoading extends DraftState {
  const DraftLoading();
}

class DraftsLoaded extends DraftState {
  final List<DraftModel> drafts;

  const DraftsLoaded({required this.drafts});

  @override
  List<Object?> get props => [drafts];
}

class DraftSaved extends DraftState {
  final DraftModel draft;

  const DraftSaved({required this.draft});

  @override
  List<Object?> get props => [draft];
}

class DraftDetailLoaded extends DraftState {
  final DraftModel draft;

  const DraftDetailLoaded({required this.draft});

  @override
  List<Object?> get props => [draft];
}

class DraftDeleted extends DraftState {
  final int draftId;

  const DraftDeleted({required this.draftId});

  @override
  List<Object?> get props => [draftId];
}

class DraftError extends DraftState {
  final String message;

  const DraftError({required this.message});

  @override
  List<Object?> get props => [message];
}

// --- BLoC ---
class DraftBloc extends Bloc<DraftEvent, DraftState> {
  final PosRepository _posRepository;

  DraftBloc({required PosRepository posRepository})
    : _posRepository = posRepository,
      super(const DraftInitial()) {
    on<DraftsLoadRequested>(_onLoadRequested);
    on<DraftSaveRequested>(_onSaveRequested);
    on<DraftLoadRequested>(_onLoadDraft);
    on<DraftDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onLoadRequested(
    DraftsLoadRequested event,
    Emitter<DraftState> emit,
  ) async {
    emit(const DraftLoading());
    try {
      final drafts = await _posRepository.getDrafts();
      emit(DraftsLoaded(drafts: drafts));
    } on ApiException catch (e) {
      emit(DraftError(message: e.message));
    }
  }

  Future<void> _onSaveRequested(
    DraftSaveRequested event,
    Emitter<DraftState> emit,
  ) async {
    emit(const DraftLoading());
    try {
      final draft = await _posRepository.saveDraft(event.payload);
      emit(DraftSaved(draft: draft));
    } on ApiException catch (e) {
      emit(DraftError(message: e.message));
    }
  }

  Future<void> _onLoadDraft(
    DraftLoadRequested event,
    Emitter<DraftState> emit,
  ) async {
    emit(const DraftLoading());
    try {
      final draft = await _posRepository.getDraft(event.draftId);
      emit(DraftDetailLoaded(draft: draft));
    } on ApiException catch (e) {
      emit(DraftError(message: e.message));
    }
  }

  Future<void> _onDeleteRequested(
    DraftDeleteRequested event,
    Emitter<DraftState> emit,
  ) async {
    try {
      await _posRepository.deleteDraft(event.draftId);
      emit(DraftDeleted(draftId: event.draftId));
      // Reload drafts list
      add(const DraftsLoadRequested());
    } on ApiException catch (e) {
      emit(DraftError(message: e.message));
    }
  }
}
