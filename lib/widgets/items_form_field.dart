import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

import 'adding_text_field.dart';

class ItemsFormField extends FormField<List<String>> {
  final InputDecoration decoration;
  final BoxConstraints constraints;
   ItemsFormField({
    super.key,
    List<String> initialValue = const [],
    super.onSaved,
    super.validator,
    super.autovalidateMode,
    this.decoration = const InputDecoration(),
    this.constraints = const BoxConstraints(),
  })  : 
        super(
             initialValue: initialValue,
            builder: (FormFieldState<List<String>> state) {
              int length = (state.value?.length ?? initialValue.length);
              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children:
                    // //[
                    //   for (int i = 0; i < length; i++)
                    //     i == length - 1
                    //         ? Row(
                    //             mainAxisSize: MainAxisSize.min,
                    //             children: [
                    //               IconButton(
                    //                   onPressed: () {
                    //                     state.didChange([...(state.value ?? initialValue), '']);
                    //                   },
                    //                   icon: const Icon(Icons.add)),
                    //               Expanded(
                    //                 child: TextFormField(
                    //                   onChanged: (v) {
                    //                     state.didChange(state.value?.mapIndexed((index, e) => i != index ? e : v).toList());
                    //                   },
                    //                   onEditingComplete: () {
                    //                     state.didChange([...(state.value ?? initialValue), '']);
                    //                   },
                    //                   // controller: _controller,
                    //                   decoration: InputDecoration(errorText: state.errorText, labelText: "اقلام حقوق و مزایا با ذکر نام"),
                    //                 ),
                    //               ),
                    //             ],
                    //           )
                    //         : TextFormField(
                    //             initialValue: initialValue[i],
                    //             onChanged: (v) {
                    //               state.didChange(state.value?.mapIndexed((index, e) => i != index ? e : v).toList());
                    //             },
                    //           )
                    // ]

                    [
                  for (int i = 0; i < length; i++)
                    AddingTextField(
                      onChange: (value) {
                        var currentState = (state.value ?? initialValue);
                        state.didChange(currentState.mapIndexed((index, element) => i == index ? value : element).toList());
                      },
                      isLast: i == length - 1,
                      onRemove: () {
                        var currentState = (state.value ?? initialValue);
                        state.didChange(currentState.whereNotIndexed((index, element) => i == index).toList());
                      },
                      initialValue: (state.value ?? initialValue)[i],
                      onAdd: () {
                        var currentState = (state.value ?? initialValue);
                        state.didChange([...currentState, '']);
                        // state.validate();
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
  FormFieldSetter<List<String>>? get onSaved {
    return super.onSaved;
  }
}
