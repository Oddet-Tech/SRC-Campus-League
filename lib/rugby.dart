import 'package:flutter/material.dart';

class Rugby extends StatelessWidget {
  const Rugby({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Scaffold(
      appBar: AppBar(leading: IconButton(
    icon: Icon(Icons.arrow_back),
    onPressed: () {
      Navigator.pop(context);
    },
        ),
        title: Center(child: Text("Rugby",style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold,color: Colors.green)),),
      ),

    ),
    );
  }
}