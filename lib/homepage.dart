import 'package:flutter/material.dart';
import 'package:campus_league/football.dart';
import 'package:campus_league/rugby.dart';

class Homescreen extends StatelessWidget {
  const Homescreen({super.key});
  @override
  Widget build(BuildContext context) {
      return Scaffold(
        appBar:AppBar(leading: Icon(Icons.sports_soccer_outlined),
          title: Center(
            child: const Text("Welcome",style: TextStyle(fontSize:26,fontWeight: FontWeight.bold,color: Color.fromARGB(255, 3, 3, 3)),)),backgroundColor: const Color.fromARGB(255, 250, 248, 248),),
          body: ListView(
            children: [
              SizedBox(height: 20,),
     Padding(
  padding: const EdgeInsets.only(left: 8, right: 8),
  child: GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) =>  Football()),
      );
    },
    child: Container(
      height: 150,
      width: 150,
      decoration: BoxDecoration(
        border: Border.all(color: const Color.fromARGB(255, 3, 185, 240)),
        image: DecorationImage(
          image: AssetImage("assets/CUTFS.png"),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        title: Text(
          "SRC CAMPUS LEAGUE",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color.fromARGB(255, 0, 0, 0),
          ),
        ),
      ),
    ),
  
    ),
      ),
   SizedBox(height: 20,),
             Padding(
  padding: const EdgeInsets.only(left: 8, right: 8),
  child: GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) =>  Rugby()),
      );
    },
    child: Container(
      height: 150,
      width: 150,
      decoration: BoxDecoration(
        border: Border.all(color: const Color.fromARGB(255, 7, 171, 241)),
        image: DecorationImage(
          image: AssetImage("assets/silver.png"),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        title: Text(
          "Players Stats",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color.fromARGB(255, 0, 0, 0),
          ),
        ),
      ),
    ),
  
        ),
       ),
       ]
      ),
    );
      
      
    
  }
}