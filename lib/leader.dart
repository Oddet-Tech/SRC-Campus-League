import 'package:flutter/material.dart';

class LeaderScreen extends StatefulWidget {
  const LeaderScreen({super.key});

  @override
  State<LeaderScreen> createState() => _LeaderScreenState();
}

class _LeaderScreenState extends State<LeaderScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Leader"),
      ),
      body: Center(
        child: ListView(
          children: const [
            ListTile(
              leading: Icon(Icons.sports_soccer),
              title: Text("The Application is under development and will operate Under the SRC Sports Leader"),
              subtitle: Text("Mr Majenge Scelo- srcfnspor@cutfs.onmicrosoft.com"),
            ),
         
          ],
        ),
      ),
    );
  }
}