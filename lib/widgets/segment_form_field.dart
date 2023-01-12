import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../pages/home_page.dart';
import 'adding_text_field.dart';

class SegmentFormField extends FormField<TaskType?> {
  final double? height;
  final Color backgroundColor;
  final Color selectedForegroundColor;
  final double borderRadius;
  SegmentFormField({
    this.borderRadius = 15,
    this.height = 45,
    Key? key,
    TaskType? initialValue,
    onSaved,
    autovalidateMode,
    validator,
    this.backgroundColor = Colors.blue,
    this.selectedForegroundColor = Colors.white,
  }) : super(
          key: key,
          onSaved: onSaved,
          validator: validator,
          initialValue: initialValue,
          autovalidateMode: autovalidateMode,
          builder: (FormFieldState<TaskType?> state) {
            return Column(
              children: [
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    height: height,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minHeight: 40),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(borderRadius)), border: Border.all(color: backgroundColor, width: 1)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: TaskType.values
                          .mapIndexed(
                            (index, e) => Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    state.didChange(e);
                                  },
                                  child: Container(
                                    constraints: BoxConstraints(minWidth: 100),
                                    padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
                                    alignment: Alignment.center,
                                    color: e == state.value ? backgroundColor : Colors.transparent,
                                    child: Text(
                                      e.label,
                                      style: TextStyle(color: e == state.value ? selectedForegroundColor : backgroundColor, fontSize: 18),
                                    ),
                                  ),
                                ),
                                if (index != TaskType.values.length - 1)
                                  VerticalDivider(
                                    color: backgroundColor,
                                    indent: 0,
                                    endIndent: 0,
                                    thickness: 1,
                                    width: 1,
                                  )
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                if (state.hasError)
                  Text(
                    state.errorText!,
                    style: TextStyle(color: Color(0xffc5032b)),
                  )
              ],
            );
          },
        );
}
