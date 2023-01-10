import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

import 'adding_text_field.dart';

class ItemsFormField extends FormField<List<String>> {
  final InputDecoration decoration;
  final BoxConstraints constraints;
  ItemsFormField({
    Key? key,
    List<String> initialValue = const [],
    onSaved,
    autovalidateMode,
    validator,
    this.decoration = const InputDecoration(),
    this.constraints = const BoxConstraints(),
  }) : super(
            key: key,
            onSaved: onSaved,
            validator: validator,
            initialValue: initialValue,
            autovalidateMode: autovalidateMode,
            builder: (FormFieldState<List<String>> state) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  AddingTextField(
                    onRemove: (index) {
                      var currentState = state.value ?? [];
                      state.didChange(currentState
                          .whereNotIndexed((i, element) => i == index)
                          .toList());
                    },
                    values: state.value ?? initialValue,
                    onAdd: (value) {
                      var currentState = state.value ?? [];
                      state.didChange([value, ...currentState]);
                      state.validate();
                    },
                  ),
                  if (state.hasError)
                    Text(
                      state.errorText!,
                      style: TextStyle(color: Color(0xffc5032b)),
                    ),
                ],
              );
            });
            @override
  // TODO: implement onSaved
  FormFieldSetter<List<String>>? get onSaved => super.onSaved;
}
