import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';

import 'emote.dart';

class ImageRow extends StatefulWidget {
  final List<Emote> emotes;

  const ImageRow({super.key, required this.emotes});

  @override
  _ImageRowState createState() => _ImageRowState();
}

class _ImageRowState extends State<ImageRow> {
  late Future<List<Uint8List>> _imagesFuture;

  @override
  void initState() {
    super.initState();
    _imagesFuture = _fetchImages();
  }

  Future<List<Uint8List>> _fetchImages() async {
    return Future.wait(widget.emotes.map((emote) => emote.fetchEmoteImage()));
  }

  List<Widget> dataToList(List<Uint8List> data, int imageCount, double imageSize) {
    List<Widget> list = data.map((imageData) {
      return Flexible(
          child: Image.memory(
            imageData,
            width: imageSize,
            height: imageSize + 5,
          )
      );
    }).toList();
    if (list.length > imageCount) {
      return list.sublist(0, imageCount);
    } else {
      return list;
    }
  }

  @override
  Widget build(BuildContext context) {
    int imageSize = 50;

    return FutureBuilder<List<Uint8List>>(
      future: _imagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LinearProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Text('No emotes added yet');
        } else {
          return LayoutBuilder(
              builder: (context, constraints){
                final rowWidth = constraints.maxWidth;
                final imageCount = (rowWidth / imageSize).round();
                return Row(children: dataToList(snapshot.data!, imageCount, imageSize.toDouble()));
              }
          );

        }
      },
    );
  }
}