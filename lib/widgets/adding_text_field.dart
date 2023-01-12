import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

class AddingTextField extends StatefulWidget {
  const AddingTextField(
      {super.key, required this.onChange , required this.onAdd, required this.onRemove, required this.initialValue, required this.isLast});
  final Function() onAdd;
  final Function() onRemove;
  final Function(String) onChange;
   final String initialValue;
  final bool isLast;
  @override
  State<AddingTextField> createState() => _AddingTextFieldState();
}

class _AddingTextFieldState extends State<AddingTextField> {
  // late final TextEditingController _controller;
  @override
  void dispose() {
    // _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    // _controller = TextEditingController(text: widget.initialValue);
    super.initState();
  }

  void _add() {
    // if (_controller.value.text.trim().isEmpty) {
    //   setState(() {
    //     _errorText = 'مورد خالی اضافه نمیشود';
    //   });
    // }
    //  else if (widget.values.contains(_controller.text.trim())) {
    //   setState(() {
    //     _errorText = 'مورد تکراری اضافه نمیشود';
    //   });
    // }
    //  else {
    //   setState(() {
    //     _errorText = null;
    //   });
    widget.onAdd.call();
    // }
  }

  String? _errorText;
  @override
  Widget build(BuildContext context) {
    final _controller = RestorableTextEditingController(text: widget.initialValue);

    // print(widget.values);
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.isLast
                ? IconButton(onPressed: () => _add(), icon: const Icon(Icons.add))
                : IconButton(onPressed: () => widget.onRemove.call(), icon: const Icon(Icons.delete_outlined)),
            Expanded(
              child: TextField(
                onChanged: (value) => widget.onChange.call(value),
                onEditingComplete: () => _add(),
                controller: _controller.value,
                decoration: InputDecoration(errorText: _errorText, labelText: "اقلام حقوق و مزایا با ذکر نام"),
              ),
            ),
          ],
        ),
        // ...widget.values
        //     .mapIndexed((index, e) => Row(
        //               mainAxisSize: MainAxisSize.min,
        //               children: [
        //                 IconButton(onPressed: () {}, icon: const Icon(Icons.delete_outlined)),
        //                 Expanded(
        //                   child: TextField(
        //                     onEditingComplete: () => _add(),
        //                     controller: _controller,
        //                     decoration: InputDecoration(errorText: _errorText, labelText: "اقلام حقوق و مزایا با ذکر نام"),
        //                   ),
        //                 ),
        //               ],
        //             ),  )
        //     .toList()
      ],
    );
  }
}
