import 'package:flutter/material.dart';

//accessed via key
class LoadingDialog extends StatefulWidget {
  const LoadingDialog({super.key});

  @override
  LoadingDialogState createState() => LoadingDialogState();
}

class LoadingDialogState extends State<LoadingDialog>{
  double value = 0;

  final GlobalKey<NavigatorState> _dialogKey = GlobalKey<NavigatorState>();

  void setValue(double valueNew){
    setState(() {
      value = valueNew;
    });
  }

  double getValue(){
    return value;
  }

  void closeDialog(){
    Navigator.of(_dialogKey.currentContext!).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: _dialogKey,
      title: Text('Loading'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Please wait... Progress: ${(value * 100).toStringAsFixed(2)}%\n'
              '(animated emotes take longer)'),
          SizedBox(height: 20),
          CircularProgressIndicator(),
        ],
      ),
      actions: [
        // TextButton(
        //   onPressed: () => (),
        //   child: Text('Cancel'),
        // ),
      ],
    );
  }
}