import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:trident/features/dashboard/data/constants/dashboard_constants.dart';

@lazySingleton
class BottomNavCubit extends Cubit<List<String>> {
  BottomNavCubit() : super([BottomNavString.home]);

  void updateScreen(String key) {
    ///Ensuring that when home is selected, the stack is cleared
    if (key == BottomNavString.home) {
      emit([BottomNavString.home]);
      return;
    }

    List<String> newState = List.from(state);

    /// Always remove the key to avoid duplicates and move it to the end
    newState.remove(key);
    newState.add(key);

    emit(newState);
  }

  void goBack() {
    if (state.length > 1) {
      ///Remove last visited tab
      List<String> newState = List.from(state)..removeLast();
      emit(newState);
    }
  }
}