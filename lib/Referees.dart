import 'package:flutter/material.dart';

class RefereesScreen extends StatefulWidget {
  const RefereesScreen({super.key});

  @override
  State<RefereesScreen> createState() => _RefereesScreenState();
}

class _RefereesScreenState extends State<RefereesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Referees"),
      ),
      body: Center(
        child: ListView(
          children: const [
            ListTile(
              leading: Icon(Icons.sports_soccer),
              title: Text("TO BE ANNOUNCED"),
            
            ),
         
          ],
        ),
      ),
    );
  }
}