import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';   // Access to the phone's orientation

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
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
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
  // static const Map<String, List<String>> bloodCauses = {
  //   'WBCs': ["Possible causes: "
  //       "An increased production of white blood cells to fight an infection. "
  //       "A reaction to a drug that increases white blood cell production. "
  //       "A disease of bone marrow, causing abnormally high production of white blood cells. "
  //       "An immune system disorder that increases white blood cell production.",
  //       "Possible causes: "
  //       "Viral infections that temporarily disrupt the work of bone marrow. "
  //       "Certain disorders present at birth (congenital) that involve diminished bone marrow function. "
  //       "Autoimmune disorders that destroy white blood cells or bone marrow cells. "
  //       "Severe infections that use up white blood cells faster than they can be produced. "
  //       "Medications, such as antibiotics, that destroy white blood cells."],
  //   'Neutophils': ['High', 'Low'],
  //   'Lymphocyles': ['High', 'Low'],
  //   'Monocytes': ['High', 'Low'],
  //   'Eosinophils': ['High', 'Low'],
  //   'Basophils': ['High', 'Low'],
  //   'RBCs': ['High', 'Low'],
  //   'Hb': ['High', 'Low'],
  //   'Hematocrit': ['High', 'Low'],
  //   'Platelets': ['High', 'Low'],
  // };
  String textResults = '';

  var medItems = {
    "White Blood Count": ['WBC', 'WBCs', 'White Blood Cells', 'White Blood Count', 'White Cell Count', 'White Blood Cell Count'],
    "Neutrophils": ['Neutrophils'],
    "Lymphocytes": ['Lymphocytes', 'Lymphs'],
    "Monocytes": ['Monocytes'],
    "Eosinophils": ['Eosinophils', 'Eos'],
    "Basophils": ['Basophils', 'Basos'],
    "Red Blood Count": ['RBC', 'RBCs', 'Red Blood Cells', 'Red Blood Count', 'Red Cell Count', 'Red Blood Cell Count'],
    "Hemoglobin": ['Hemoglobin', 'Hb'],
    "Hematocrit": ['Hematocrit'],
    "Platelets": ['Platelets']
  };

  List<String> itemsNotFound = ["White Blood Count", "Neutrophils", "Lymphocytes", "Monocytes", "Eosinophils",
    "Basophils", "Red Blood Count", "Hemoglobin", "Hematocrit", "Platelets"];

  bool medItemFound(String item) {
    for (String itemNotFound in itemsNotFound) {
      for (String medItem in medItems[itemNotFound]!) {
        if (item.contains(medItem)) {
          itemsNotFound.remove(medItem);
          return true;
        }
      }
    }
    return false;
  }

  String returnValue(String item) {
    RegExp valuePattern = RegExp(r"\d+(\.\d+)?");
    RegExpMatch? foundPattern = valuePattern.firstMatch(item);
    if (foundPattern == null) {
      return "No result value found.";
    }
    int startPattern = foundPattern.start;
    int endPattern = foundPattern.end;
    return item.substring(startPattern, endPattern);
  }

  String returnRange(String item) {
    RegExp valuePattern = RegExp(r"\d+(\.\d+)?(\sto\s|\s-\s|-)\d+(\.\d+)?");
    RegExpMatch? foundPattern = valuePattern.firstMatch(item);
    if (foundPattern == null) {
      return "No range found.";
    }
    int startPattern = foundPattern.start;
    int endPattern = foundPattern.end;
    return item.substring(startPattern, endPattern);
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
        print(textLinesList);

        // var medItems = ["WBCs", "Neutrophils", "Lymphocytes", "Monocytes", "Eosinophils", "Basophils", "RBCs", "Hb", "Hematocrit", "Platelets"];
        //               WBC                    Lymphs                      Eos            Basos        RBC     Hemoglobin


        List<String> newResultList = [];

        for(String item in textLinesList) {
          if (medItemFound(item)) {
            print("Found an important item: " + item);
            try {
              int pos = textLinesList.indexOf(item);
              // CONSTRAINT: The next item after the medical item found is
              // always going to be the result.
              // Additionally the next item after result is the range.
              double result = double.parse(textLinesList[pos + 1]);
              String reference = returnRange(textLinesList[pos + 2]);
              if (reference != 'No range found.') {
                double lower;
                double upper;
                if (reference.contains('-')) {
                  List<String> ranges = reference.split('-');
                  lower = double.parse(ranges[0]);
                  upper = double.parse(ranges[1]);
                } else {
                  List<String> ranges = reference.split('to');
                  lower = double.parse(ranges[0]);
                  upper = double.parse(ranges[1]);
                }
                String decision = "Abnormal";
                if (result >= lower && result <= upper) {
                  decision = "Normal";
                } else if (result < lower) {
                  decision = "Abnormally Low";
                } else if (result > upper) {
                  decision = "Abnormally High";
                }
                String newResultStr = item + ": " + decision;
                print(newResultStr);
                newResultList.add(newResultStr);
              }
            } catch (e) {
              print("Failed to parse the item");
            }
          }
        }
        print(newResultList);
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
        child: Icon(Icons.save),
        onPressed: () async {
          final Directory? dir = await getExternalStorageDirectory();
          final File file = File('${dir!.path}/information.txt');
          String stringFromList = foundLines.join('\n ');
          file.writeAsString(stringFromList);
          Share.shareFiles(['${dir.path}/information.txt']);
        }
      ),
    );
  }
}
