import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/wishlist_usecases.dart';
import 'wishlist_event.dart';
import 'wishlist_state.dart';

class WishlistBloc extends Bloc<WishlistEvent, WishlistState> {
  WishlistBloc({
    required this._getMyItems,
    required this._addItem,
    required this._updateItem,
    required this._deleteItem,
    required this._setHidden,
  }) : super(const WishlistState()) {
    on<WishlistLoad>(_onLoad);
    on<WishlistAdd>(_onAdd);
    on<WishlistUpdate>(_onUpdate);
    on<WishlistDelete>(_onDelete);
    on<WishlistToggleHide>(_onToggle);
  }

  final GetMyItemsUseCase _getMyItems;
  final AddItemUseCase _addItem;
  final UpdateItemUseCase _updateItem;
  final DeleteItemUseCase _deleteItem;
  final SetHiddenUseCase _setHidden;

  Future<void> _onLoad(WishlistLoad e, Emitter<WishlistState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final items = await _getMyItems(e.ownerId);
      emit(state.copyWith(items: items, isLoading: false));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, error: f.message));
    } catch (err) {
      emit(state.copyWith(isLoading: false, error: err.toString()));
    }
  }

  Future<void> _onAdd(WishlistAdd e, Emitter<WishlistState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final saved = await _addItem(e.item);
      emit(state.copyWith(items: [...state.items, saved], isLoading: false));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, error: f.message));
    } catch (err) {
      emit(state.copyWith(isLoading: false, error: err.toString()));
    }
  }

  Future<void> _onUpdate(WishlistUpdate e, Emitter<WishlistState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final saved = await _updateItem(e.item);
      emit(
        state.copyWith(
          items: state.items.map((i) => i.id == saved.id ? saved : i).toList(),
          isLoading: false,
        ),
      );
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, error: f.message));
    } catch (err) {
      emit(state.copyWith(isLoading: false, error: err.toString()));
    }
  }

  Future<void> _onDelete(WishlistDelete e, Emitter<WishlistState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      await _deleteItem(e.itemId);
      emit(
        state.copyWith(
          items: state.items.where((i) => i.id != e.itemId).toList(),
          isLoading: false,
        ),
      );
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, error: f.message));
    } catch (err) {
      emit(state.copyWith(isLoading: false, error: err.toString()));
    }
  }

  Future<void> _onToggle(
    WishlistToggleHide e,
    Emitter<WishlistState> emit,
  ) async {
    // Optimistic patch + rollback: no full reload, no scroll loss, and no
    // ownerId needs to travel on the event.
    final previous = state.items;
    emit(
      state.copyWith(
        items: previous
            .map((i) => i.id == e.itemId ? i.copyWith(isHidden: e.hidden) : i)
            .toList(),
      ),
    );
    try {
      await _setHidden(SetHiddenParams(itemId: e.itemId, hidden: e.hidden));
    } on Failure catch (f) {
      emit(state.copyWith(items: previous, error: f.message));
    } catch (err) {
      emit(state.copyWith(items: previous, error: err.toString()));
    }
  }
}
