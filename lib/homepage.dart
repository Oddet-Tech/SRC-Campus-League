import 'package:campus_league/Referees.dart';
import 'package:campus_league/developer.dart';
import 'package:campus_league/leader.dart';
import 'package:campus_league/news.dart';
import 'package:flutter/material.dart';
import 'package:campus_league/football.dart';
import 'package:campus_league/rugby.dart';

class Homescreen extends StatelessWidget {
  const Homescreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 3, 185, 240),
              ),
              child: Text(
                "Campus League Menu",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // News
            ListTile(
              leading: const Icon(Icons.newspaper),
              title: const Text("Tournaments"),
              onTap: () {
                Navigator.push(context,  MaterialPageRoute(builder: (context) => const NewsScreen()));
              },
            ),

            // Developer
            ListTile(
              leading: const Icon(Icons.developer_mode),
              title: const Text("Developer"),
              onTap: () {
                Navigator.push(context,  MaterialPageRoute(builder: (context) => const DeveloperScreen()));
              },
            ),

            // Referees
            ListTile(
              leading: const Icon(Icons.sports),
              title: const Text("Referees"),
              onTap: () {
                Navigator.push(context,  MaterialPageRoute(builder: (context) => const RefereesScreen()));
              },
            ),

            // Leader
            ListTile(
              leading: const Icon(Icons.leaderboard),
              title: const Text("Leader"),
              onTap: () {
                Navigator.push(context,  MaterialPageRoute(builder: (context) => const LeaderScreen()));
              },
            ),
          ],
        ),
      ),

      appBar: AppBar(
        title: const Center(
          child: Text(
            "Welcome",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 3, 3, 3),
            ),
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 250, 248, 248),
      ),

      body: ListView(
        children: [
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Football(),
                  ),
                );
              },
              child: Container(
                height: 150,
                width: 150,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color.fromARGB(255, 3, 185, 240),
                  ),
                  image: const DecorationImage(
                    image: AssetImage("assets/CUTFS.png"),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const ListTile(
                  title: Text(
                    "SRC CAMPUS LEAGUE",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Rugby(),
                  ),
                );
              },
              child: Container(
                height: 150,
                width: 150,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color.fromARGB(255, 7, 171, 241),
                  ),
                  image: const DecorationImage(
                    image: AssetImage("assets/silver.png"),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const ListTile(
                  title: Text(
                    "Players Stats",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}