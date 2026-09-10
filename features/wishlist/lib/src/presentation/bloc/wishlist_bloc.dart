import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/wishlist_repository.dart';
import 'wishlist_event.dart';
import 'wishlist_state.dart';

class WishlistBloc extends Bloc<WishlistEvent, WishlistState> {
  WishlistBloc(this._repo, {this._deleteChatsForItem})
    : super(const WishlistState()) {
    on<WishlistLoad>(_onLoad);
    on<WishlistAdd>(_onAdd);
    on<WishlistUpdate>(_onUpdate);
    on<WishlistDelete>(_onDelete);
    on<WishlistToggleHide>(_onToggle);
  }

  final WishlistRepository _repo;

  /// Hook for deleting the item's Firestore chats (provided by the app's DI
  /// so this package does not depend on the chat package). Chats are deleted
  /// first: if chat deletion fails the item is kept and an error is emitted,
  /// so a failed delete never orphans chats or silently drops the item.
  final Future<void> Function(String itemId)? _deleteChatsForItem;

  Future<void> _onLoad(WishlistLoad e, Emitter<WishlistState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final items = e.visibleOnly
          ? await _repo.getVisibleItems(e.ownerId)
          : await _repo.getMyItems(e.ownerId);
      emit(state.copyWith(items: items, isLoading: false));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, error: f.message));
    } catch (err) {
      emit(state.copyWith(isLoading: false, error: err.toString()));
    }
  }

  Future<void> _onAdd(WishlistAdd e, Emitter<WishlistState> emit) async {
    try {
      final saved = await _repo.addItem(e.item);
      emit(state.copyWith(items: [...state.items, saved]));
    } catch (err) {
      emit(state.copyWith(error: err.toString()));
    }
  }

  Future<void> _onUpdate(WishlistUpdate e, Emitter<WishlistState> emit) async {
    try {
      final saved = await _repo.updateItem(e.item);
      emit(
        state.copyWith(
          items: state.items.map((i) => i.id == saved.id ? saved : i).toList(),
        ),
      );
    } catch (err) {
      emit(state.copyWith(error: err.toString()));
    }
  }

  Future<void> _onDelete(WishlistDelete e, Emitter<WishlistState> emit) async {
    try {
      await _deleteChatsForItem?.call(e.itemId);
      await _repo.deleteItem(e.itemId);
      emit(
        state.copyWith(
          items: state.items.where((i) => i.id != e.itemId).toList(),
        ),
      );
    } catch (err) {
      emit(state.copyWith(error: err.toString()));
    }
  }

  Future<void> _onToggle(
    WishlistToggleHide e,
    Emitter<WishlistState> emit,
  ) async {
    try {
      await _repo.setHidden(e.itemId, e.hidden);
      add(WishlistLoad(e.ownerId));
    } catch (err) {
      emit(state.copyWith(error: err.toString()));
    }
  }
}
