import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

class AddingTextField extends StatefulWidget {
  const AddingTextField(
      {super.key,
      required this.onAdd,
      required this.onRemove,
      required this.values});
  final Function(String) onAdd;
  final Function(int) onRemove;
  final List<String> values;
  @override
  State<AddingTextField> createState() => _AddingTextFieldState();
}

class _AddingTextFieldState extends State<AddingTextField> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    if (_controller.value.text.trim().isEmpty) {
      setState(() {
        _errorText = 'مورد خالی اضافه نمیشود';
      });
    } else if (widget.values.contains(_controller.text.trim())) {
      setState(() {
        _errorText = 'مورد تکراری اضافه نمیشود';
      });
    } else {
      setState(() {
        _errorText = null;
      });
      widget.onAdd.call(_controller.text.trim());
    }
  }

  String? _errorText;
  @override
  Widget build(BuildContext context) {
    print(widget.values);
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(onPressed: () => _add(), icon: const Icon(Icons.add)),
            Expanded(
              child: TextField(
                onEditingComplete: () => _add(),
                controller: _controller,
                decoration: InputDecoration(
                    errorText: _errorText,
                    labelText: "اقلام حقوق و مزایا با ذکر نام"),
              ),
            ),
          ],
        ),
        ...widget.values
            .mapIndexed((index, e) => ListTile(
                  leading: IconButton(
                      onPressed: () {
                        widget.onRemove.call(index);
                      },
                      icon: const Icon(Icons.delete_outlined)),
                  title: Text(e),
                ))
            .toList()
      ],
    );
  }
}
