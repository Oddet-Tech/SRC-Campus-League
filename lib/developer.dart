import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as images;

class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({super.key});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Developer"),backgroundColor: const Color.fromARGB(255, 216, 217, 218),
      ),backgroundColor: const Color.fromARGB(255, 228, 229, 224),
      body:SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Image(image: images.AssetImage("assets/my logog.png"), width: 150, height: 150),
            SizedBox(height: 20),
            Text(
              "Developed by CUT IT student:Shilenge Oddet",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Contact 1:shilengeoddet@gmail.com",
              style: TextStyle(fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
             SizedBox(height: 10),
            Text(
              "Contact 2:oddetshilenge@gmail.com",
              style: TextStyle(fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
              SizedBox(height: 10),
            Text(
              "Contact 3:0686857556",
              style: TextStyle(fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
             SizedBox(height: 10),
            Text(
              "Campus League App Version: 1.0.1",
              style: TextStyle(fontWeight: FontWeight.bold,
                fontSize: 16,color:Color.fromARGB(255, 57, 58, 58),
              ),
            ),
          ],
        ),
      ),
    );
  }
}