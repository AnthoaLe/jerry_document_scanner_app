import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import 'package:google_ml_kit/google_ml_kit.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jerry Document Scanner',
      theme: ThemeData.dark(),
      home: const TakePicture(),
    );
  }
}

class TakePicture extends StatefulWidget {
  const TakePicture({Key? key}) : super(key: key);

  @override
  _TakePictureState createState() => _TakePictureState();
}

class _TakePictureState extends State<TakePicture> {
  late CameraController controller;
  late Future<void> initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    controller = CameraController(cameras.first, ResolutionPreset.max);
    initializeControllerFuture = controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take a Picture Screen'),
      ),
      body: FutureBuilder<void>(
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Center(
              child: CameraPreview(controller),
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
        future: initializeControllerFuture,
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.camera_alt),
        onPressed: () async {
          try {
            await initializeControllerFuture;
            final image = await controller.takePicture();
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) {
                  return DisplayPicture(
                    imagePath: image.path,
                  );
                },
              )
            );
          } catch (e) {
            print(e);
          }
        }
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class DisplayPicture extends StatefulWidget {
  const DisplayPicture({Key? key, required this.imagePath}) : super(key: key);

  final String imagePath;

  @override
  _DisplayPictureState createState() => _DisplayPictureState();
}

class _DisplayPictureState extends State<DisplayPicture> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Display the Picture'),
      ),
      body: Center(
        child: Image.file(File(widget.imagePath)),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.upload),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) {
                return RecognizeText(imagePath: widget.imagePath);
              }
            )
          );
        }
      ),
    );
  }
}

class RecognizeText extends StatefulWidget {
  const RecognizeText({Key? key, required this.imagePath}) : super(key: key);

  final String imagePath;

  @override
  _RecognizeTextState createState() => _RecognizeTextState();
}

class _RecognizeTextState extends State<RecognizeText> {
  late List<String> foundLines;

  Future<List<String>> processImage() async {
    try {
      final InputImage inputImage = InputImage.fromFilePath(widget.imagePath);
      final TextDetector textDetector = GoogleMlKit.vision.textDetector();

      try {
        final RecognisedText recognisedText = await textDetector.processImage(
            inputImage);
        List<String> textLinesList = [];
        for (TextBlock block in recognisedText.blocks) {
          for (TextLine line in block.lines) {
            textLinesList.add(line.text);
          }
        }
        return textLinesList;
      } catch (e) {
        rethrow;
      } finally {
        textDetector.close();
      }

    } catch (e) {
      print(e);
      return ["Error"];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Processed Image Text'),
      ),
      body: FutureBuilder(
        future: processImage(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            foundLines = snapshot.data as List<String>;
            return ListView.builder(
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(foundLines[index]),
                );
              },
              itemCount: foundLines.length,
            );
          } else {
            return const CircularProgressIndicator();
          }
        }
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.arrow_forward),
        onPressed: () {
          Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) {
                  return RegexScreen(foundLines: foundText);
                  },
              )
          );
        }
      ),
    );
  }
}

class RegexScreen extends StatefulWidget {
  const RegexScreen({Key? key, required this.foundLines}) : super(key: key);

  final List<String> foundLines;

  @override
  _RegexScreenState createState() => _RegexScreenState();
}

class _RegexScreenState extends State<RegexScreen> {
  RegExp hemoglobinRe = RegExp(r"Hemoglobin");

  bool foundMatch() {
    for (String line in widget.foundLines) {
      if (hemoglobinRe.hasMatch(line)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: foundMatch() ? Text("Found") : Text("Not Found"),
    );
  }
}