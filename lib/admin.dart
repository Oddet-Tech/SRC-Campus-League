import 'dart:async';
import 'package:flutter/material.dart';
import 'package:src_project/football.dart';
import 'package:src_project/team.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Admin extends StatefulWidget {
  const Admin({super.key});

  @override
  State<Admin> createState() => _AdminState();
}

class _AdminState extends State<Admin> {
  final nameController = TextEditingController();
  final winController = TextEditingController();
  final lossController = TextEditingController();
  final drawController = TextEditingController();

  final CollectionReference _teamsCol =
      FirebaseFirestore.instance.collection('teams');

  List<Team> teams = [];
  int? editingIndex;
  late StreamSubscription<QuerySnapshot> _subscription;

  @override
  void initState() {
    super.initState();
    _loadTeamsFromPrefs();

    try {
      _subscription = _teamsCol.snapshots().listen((snapshot) {
        setState(() {
          teams = snapshot.docs
              .map(
                (doc) => Team.fromMap(
                  doc.data() as Map<String, dynamic>,
                  id: doc.id,
                ),
              )
              .toList()
            ..sort((a, b) => b.points.compareTo(a.points));
        });
        _saveTeamsToPrefs();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _saveTeamsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(teams.map((t) => t.toMap()).toList());
    await prefs.setString('teams', encoded);
  }

  Future<void> _loadTeamsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('teams');
    if (data != null) {
      try {
        final list = jsonDecode(data) as List<dynamic>;
        final loaded =
            list.map((e) => Team.fromMap(e as Map<String, dynamic>)).toList();
        setState(() {
          if (teams.isEmpty) {
            teams = loaded;
          }
        });
      } catch (_) {}
    }
  }

  Future<void> addOrUpdateTeam() async {
    if (nameController.text.isEmpty ||
        winController.text.isEmpty ||
        lossController.text.isEmpty) {
      return;
    }

    // Validate that win, draw, and loss are numbers
    final win = int.tryParse(winController.text);
    final loss = int.tryParse(lossController.text);
    final draw = drawController.text.isEmpty ? 0 : int.tryParse(drawController.text);

    if (win == null || loss == null || draw == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wins, Draws, and Losses must be numbers only',style:TextStyle(color:Colors.red))),
      );
      return;
    }

    final team = Team(
      name: nameController.text,
      win: win,
      loss: loss,
      draw: draw,
      played: win + loss + draw,
    );

    try {
      if (editingIndex == null) {
        await _teamsCol.add(team.toMap());
      } else {
        final existing = teams[editingIndex!];
        if (existing.id != null) {
          await _teamsCol.doc(existing.id).set(team.toMap());
        }
        editingIndex = null;
      }

      // Clear input fields
      nameController.clear();
      winController.clear();
      lossController.clear();
      drawController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save team: $e')),
      );
    }
  }

  void editTeam(int index) {
    final team = teams[index];
    setState(() {
      nameController.text = team.name;
      winController.text = team.win.toString();
      lossController.text = team.loss.toString();
      drawController.text = team.draw.toString();
      editingIndex = index;
    });
  }

  void deleteTeam(int index) async {
    final existing = teams[index];
    if (existing.id != null) {
      try {
        await _teamsCol.doc(existing.id).delete();
        setState(() {
          teams.removeAt(index);
          if (editingIndex != null && editingIndex == index) {
            editingIndex = null;
            nameController.clear();
            winController.clear();
            lossController.clear();
            drawController.clear();
          }
        });
        _saveTeamsToPrefs();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete team: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Page"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // Input fields
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Team Name"),
            ),
            TextField(
              controller: winController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Wins"),
            ),
            TextField(
              controller: drawController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Draws"),
            ),
            TextField(
              controller: lossController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Losses"),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: addOrUpdateTeam,
              child: Text(editingIndex == null ? "Add Team" : "Update Team"),
            ),

            const SizedBox(height: 20),

            // Teams list in Cards
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: teams.length,
              itemBuilder: (context, index) {
                final team = teams[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  elevation: 3,
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    title: Text(team.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      "P: ${team.played}, W: ${team.win}, D: ${team.draw}, L: ${team.loss}, Pts: ${team.points}",
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => editTeam(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => deleteTeam(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) =>  Football()),
                );
              },
              child: const Text("View Football Table"),
            ),
          ],
        ),
      ),
    );
  }
}