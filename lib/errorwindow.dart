import 'package:flutter/material.dart';

class CustomDialog extends StatelessWidget {
  final String message;

  const CustomDialog({super.key, this.message = "This is a customizable message"});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Text(message),
      actions: <Widget>[
        TextButton(
          child: Text("OK"),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
