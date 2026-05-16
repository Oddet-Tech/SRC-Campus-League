import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'football.dart';

class Team {
  String? id;
  String name;
  int played;
  int win;
  int loss;
  int draw;
  int goalsFor;
  int goalsAgainst;
  String? logoUrl;

  Team({
    this.id,
    required this.name,
    required this.win,
    required this.loss,
    required this.draw,
    required this.goalsFor,
    required this.goalsAgainst,
    this.logoUrl,
    required int played,
  }) : played = win + draw + loss;

  int get points => win * 3 + draw;

  int get goalDifference => goalsFor - goalsAgainst;

 Map<String, dynamic> toMap() {
  return {
    'name': name,
    'win': win,
    'loss': loss,
    'draw': draw,
    'goalsFor': goalsFor,
    'goalsAgainst': goalsAgainst,
    'played': played,
    'logoUrl': logoUrl,
  };
}
  factory Team.fromMap(Map<String, dynamic> map, {String? id}) {
  return Team(
    id: id,
    name: map['name'] ?? '',
    win: map['win'] ?? 0,
    loss: map['loss'] ?? 0,
    draw: map['draw'] ?? 0,
    goalsFor: map['goalsFor'] ?? 0,
    goalsAgainst: map['goalsAgainst'] ?? 0,
    played: map['played'] ?? 0,
    logoUrl: map['logoUrl'],
  );
}
}

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
  final goalsForController = TextEditingController();
  final goalsAgainstController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  XFile? _pickedLogoFile;
  Uint8List? _logoPreviewBytes;
  String? _existingLogoUrl;

  final CollectionReference _teamsCol =
      FirebaseFirestore.instance.collection('teams');

  List<Team> teams = [];

  int? editingIndex;

  bool isLoading = false;

  late StreamSubscription<QuerySnapshot> _subscription;

  @override
  void initState() {
    super.initState();

    _loadTeamsFromPrefs();

    _subscription = _teamsCol.snapshots().listen((snapshot) {
      setState(() {
        teams = snapshot.docs
            .map(
              (doc) => Team.fromMap(
                doc.data() as Map<String, dynamic>,
                id: doc.id,
              ),
            )
            .toList();

        teams.sort((a, b) => b.points.compareTo(a.points));
      });

      _saveTeamsToPrefs();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();

    nameController.dispose();
    winController.dispose();
    lossController.dispose();
    drawController.dispose();
    goalsForController.dispose();
    goalsAgainstController.dispose();

    super.dispose();
  }

  Future<void> _saveTeamsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = jsonEncode(
      teams.map((t) => t.toMap()).toList(),
    );

    await prefs.setString('teams', encoded);
  }

  Future<void> _loadTeamsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString('teams');

    if (data != null) {
      final list = jsonDecode(data) as List<dynamic>;

      setState(() {
        teams = list
            .map((e) => Team.fromMap(e as Map<String, dynamic>))
            .toList();
      });
    }
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();

        setState(() {
          _pickedLogoFile = picked;
          _logoPreviewBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<String?> _uploadLogo(XFile logoFile) async {
    try {
      final bytes = await logoFile.readAsBytes();

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${logoFile.name}';

      final ref = FirebaseStorage.instance
          .ref()
          .child('team_logos')
          .child(fileName);

      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
        ),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint("UPLOAD ERROR: $e");
      return null;
    }
  }

  void _clearLogoSelection() {
    setState(() {
      _pickedLogoFile = null;
      _logoPreviewBytes = null;
    });
  }

  Future<void> addOrUpdateTeam() async {
    if (nameController.text.isEmpty ||
        winController.text.isEmpty ||
        lossController.text.isEmpty) {
      return;
    }

    final win = int.tryParse(winController.text);
    final loss = int.tryParse(lossController.text);

    final draw = drawController.text.isEmpty
        ? 0
        : int.tryParse(drawController.text);

    final goalsFor = goalsForController.text.isEmpty
        ? 0
        : int.tryParse(goalsForController.text);

    final goalsAgainst = goalsAgainstController.text.isEmpty
        ? 0
        : int.tryParse(goalsAgainstController.text);

    if (win == null ||
        loss == null ||
        draw == null ||
        goalsFor == null ||
        goalsAgainst == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter valid numbers"),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      String? logoUrl = _existingLogoUrl;

      if (_pickedLogoFile != null) {
        final uploadedUrl = await _uploadLogo(_pickedLogoFile!);

        if (uploadedUrl != null) {
          logoUrl = uploadedUrl;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Logo upload failed"),
            ),
          );
        }
      }

      final team = Team(
        id: editingIndex != null ? teams[editingIndex!].id : null,
        name: nameController.text.trim(),
        win: win,
        loss: loss,
        draw: draw,
        goalsFor: goalsFor,
        goalsAgainst: goalsAgainst,
        logoUrl: logoUrl,
        played: win + draw + loss,
      );

      if (editingIndex == null) {
        final docRef = await _teamsCol.add(team.toMap());

        await _teamsCol.doc(docRef.id).update({
          'id': docRef.id,
        });

        setState(() {
          teams.add(
            Team(
              id: docRef.id,
              name: team.name,
              win: team.win,
              loss: team.loss,
              draw: team.draw,
              goalsFor: team.goalsFor,
              goalsAgainst: team.goalsAgainst,
              logoUrl: logoUrl,
              played: team.played,
            ),
          );

          teams.sort((a, b) => b.points.compareTo(a.points));
        });
      } else {
        final existingTeam = teams[editingIndex!];

        await _teamsCol.doc(existingTeam.id).update({
          'name': team.name,
          'played': team.played,
          'win': team.win,
          'loss': team.loss,
          'draw': team.draw,
          'goalsFor': team.goalsFor,
          'goalsAgainst': team.goalsAgainst,
          'logoUrl': logoUrl,
        });

        setState(() {
          teams[editingIndex!] = Team(
            id: existingTeam.id,
            name: team.name,
            win: team.win,
            loss: team.loss,
            draw: team.draw,
            goalsFor: team.goalsFor,
            goalsAgainst: team.goalsAgainst,
            logoUrl: logoUrl,
            played: team.played,
          );

          teams.sort((a, b) => b.points.compareTo(a.points));

          editingIndex = null;
        });
      }

      nameController.clear();
      winController.clear();
      lossController.clear();
      drawController.clear();
      goalsForController.clear();
      goalsAgainstController.clear();

      _pickedLogoFile = null;
      _logoPreviewBytes = null;
      _existingLogoUrl = null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Team saved successfully"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
        ),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  void editTeam(int index) {
    final team = teams[index];

    setState(() {
      nameController.text = team.name;
      winController.text = team.win.toString();
      lossController.text = team.loss.toString();
      drawController.text = team.draw.toString();
      goalsForController.text = team.goalsFor.toString();
      goalsAgainstController.text = team.goalsAgainst.toString();

      _existingLogoUrl = team.logoUrl;

      editingIndex = index;
    });
  }

  Future<void> deleteTeam(int index) async {
    final team = teams[index];

    try {
      await _teamsCol.doc(team.id).delete();

      setState(() {
        teams.removeAt(index);
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin"),
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              if (!mounted) return;

              Navigator.pop(context);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Team Name",
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: winController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Wins",
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: drawController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Draws",
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: lossController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Losses",
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: goalsForController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Goals For",
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: goalsAgainstController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Goals Against",
                    ),
                  ),

                  const SizedBox(height: 22),

                  ElevatedButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(
                      Icons.image,
                      size: 32,
                    ),
                    label: const Text("Upload Team Logo"),
                  ),

                  const SizedBox(height: 20),

                  if (_logoPreviewBytes != null)
                    Container(
                      height: 140,
                      width: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(
                          _logoPreviewBytes!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else if (_existingLogoUrl != null)
                    Container(
                      height: 140,
                      width: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          _existingLogoUrl!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: addOrUpdateTeam,
                    child: Text(
                      editingIndex == null
                          ? "Add Team"
                          : "Update Team",
                    ),
                  ),

                  const SizedBox(height: 30),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: teams.length,
                    itemBuilder: (context, index) {
                      final team = teams[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 34,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: team.logoUrl != null &&
                                          team.logoUrl!.isNotEmpty
                                      ? NetworkImage(team.logoUrl!)
                                      : null,
                                  child: team.logoUrl == null ||
                                          team.logoUrl!.isEmpty
                                      ? const Icon(
                                          Icons.image,
                                          size: 42,
                                          color: Colors.grey,
                                        )
                                      : null,
                                ),

                                const SizedBox(width: 20),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        team.name,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      Text(
                                        "P: ${team.played}  W: ${team.win}  D: ${team.draw}  L: ${team.loss}",
                                      ),

                                      const SizedBox(height: 6),

                                      Text(
                                        "GF: ${team.goalsFor}  GA: ${team.goalsAgainst}",
                                      ),

                                      const SizedBox(height: 6),

                                      Text(
                                        "Points: ${team.points}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Column(
                                  children: [
                                    IconButton(
                                      onPressed: () => editTeam(index),
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                        size: 30,
                                      ),
                                    ),

                                    const SizedBox(height: 10),

                                    IconButton(
                                      onPressed: () => deleteTeam(index),
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 30,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
                        MaterialPageRoute(
                          builder: (_) => const Football(),
                        ),
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