import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
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
      debugShowCheckedModeBanner: false,
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
  static const Map<String, List<String>> bloodCauses = {
    'WBCs': ["Possible causes: "
        "An increased production of white blood cells to fight an infection. "
        "A reaction to a drug that increases white blood cell production. "
        "A disease of bone marrow, causing abnormally high production of white blood cells. "
        "An immune system disorder that increases white blood cell production.",
        "Possible causes: "
        "Viral infections that temporarily disrupt the work of bone marrow. "
        "Certain disorders present at birth (congenital) that involve diminished bone marrow function. "
        "Autoimmune disorders that destroy white blood cells or bone marrow cells. "
        "Severe infections that use up white blood cells faster than they can be produced. "
        "Medications, such as antibiotics, that destroy white blood cells."],
    'Neutophils': ['High', 'Low'],
    'Lymphocyles': ['High', 'Low'],
    'Monocytes': ['High', 'Low'],
    'Eosinophils': ['High', 'Low'],
    'Basophils': ['High', 'Low'],
    'RBCs': ['High', 'Low'],
    'Hb': ['High', 'Low'],
    'Hematocrit': ['High', 'Low'],
    'Platelets': ['High', 'Low'],
  };
  late List<String> finalResults;

  int getItemIndex(medItems, item) {
    int index = -1;
    for(var medItem in medItems) {
      if (item.contains(medItem)) {
        return medItems.indexOf(medItem);
      }
    }
    return index;
  }

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

        var medItems = ["WBCs", "Neutophils", "Lymphocyles", "Monocytes", "Eosinophils", "Basophils", "RBCs", "Hb", "Hematocrit", "Platelets"];

        List<String> newResultList = [];

        for(var item in textLinesList) {
          if (getItemIndex(medItems, item) >= 0) {
            print("Found an important item: " + item);
            try {
              var pos = textLinesList.indexOf(item);
              var result = double.parse(textLinesList[pos + 1]);
              var reference = textLinesList[pos + 2];
              var ranges = reference.split("to");
              var min = double.parse(ranges[0]);
              var max = double.parse(ranges[1]);
              var decision = "Abnormal";
              if (result >= min && result <= max) {
                decision = "Normal";
              }else if (result < min) {
                decision = "Abnormally Low";
              }else if (result > max) {
                decision = "Abnormally High";
              }
              var newResultStr = item + ": " + decision;
              print(newResultStr);
              newResultList.add(newResultStr);
            } catch (e) {
              print("Failed to parse the item");
            }
          }
        }

        print(newResultList);
        finalResults = newResultList;
        return newResultList;
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

  String returnFirstWord(String sentence) {
    return sentence.split(" ")[0];
  }

  String returnLastWord(String sentence) {
    final List<String> words = sentence.split(" ");
    return words[words.length-1];
  }

  String returnCause(String result) {
    final String firstWord = returnFirstWord(result);
    final String lastWord = returnLastWord(result);
    if (lastWord == "High") {
      return bloodCauses[firstWord]![0];
    } else if (lastWord == "Low") {
      return bloodCauses[firstWord]![1];
    } else {
      return "Healthy result. Nothing to report.";
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
                  subtitle: Text(returnCause(foundLines[index])),
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
                  return WriteToFile(information: finalResults);
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

class WriteToFile extends StatefulWidget {
  const WriteToFile({Key? key, required this.information}) : super(key: key);

  final List<String> information;

  @override
  _WriteToFileState createState() => _WriteToFileState();
}

class _WriteToFileState extends State<WriteToFile> {
  void write() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}/information.txt');
    String stringFromList = widget.information.join('');
    file.writeAsString(stringFromList);
    print('confirmed');
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      child: Text("Confirm Write"),
      onPressed: () => write(),
    );
  }
}
