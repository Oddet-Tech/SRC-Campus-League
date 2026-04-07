import 'dart:async';
import 'package:flutter/material.dart';
import 'package:campus_league/football.dart';
import 'package:campus_league/team.dart';
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

  final matchTimeController = TextEditingController();
  final homeGoalsController = TextEditingController();
  final awayGoalsController = TextEditingController();

  String? selectedHomeTeam;
  String? selectedAwayTeam;
  String? editingFixtureId;
  List<Map<String, dynamic>> fixtures = [];
  bool isLoading = true;

  final CollectionReference _teamsCol = FirebaseFirestore.instance.collection(
    'teams',
  );
  final CollectionReference _fixturesCol = FirebaseFirestore.instance
      .collection('fixtures');

  List<Team> teams = [];
  int? editingIndex;
  late StreamSubscription<QuerySnapshot> _subscription;
  late StreamSubscription<QuerySnapshot> _fixturesSubscription;

  @override
  void initState() {
    super.initState();
    _loadTeamsFromPrefs();

    try {
      _subscription = _teamsCol.snapshots().listen((snapshot) {
        setState(() {
          teams =
              snapshot.docs
                  .map(
                    (doc) => Team.fromMap(
                      doc.data() as Map<String, dynamic>,
                      id: doc.id,
                    ),
                  )
                  .toList()
                ..sort((a, b) => b.points.compareTo(a.points));
          isLoading = false;
        });
        _saveTeamsToPrefs();
      }, onError: (error) {
        setState(() {
          isLoading = false;
        });
      });

      _fixturesSubscription = _fixturesCol.snapshots().listen((snapshot) {
        setState(() {
          fixtures = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'homeTeam': data['homeTeam'] as String? ?? '',
              'awayTeam': data['awayTeam'] as String? ?? '',
              'matchTime': data['matchTime'] as String? ?? '',
              'homeGoals': data['homeGoals'],
              'awayGoals': data['awayGoals'],
              'status': data['status'] as String? ?? 'scheduled',
            };
          }).toList();
        });
      }, onError: (error) {
        setState(() {
          isLoading = false;
        });
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription.cancel();
    _fixturesSubscription.cancel();
    nameController.dispose();
    winController.dispose();
    lossController.dispose();
    drawController.dispose();
    matchTimeController.dispose();
    homeGoalsController.dispose();
    awayGoalsController.dispose();
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
        final loaded = list
            .map((e) => Team.fromMap(e as Map<String, dynamic>))
            .toList();
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

    final win = int.tryParse(winController.text);
    final loss = int.tryParse(lossController.text);
    final draw = drawController.text.isEmpty
        ? 0
        : int.tryParse(drawController.text);

    if (win == null || loss == null || draw == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Wins, Draws, and Losses must be numbers only',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
      return;
    }

    final team = Team(
      name: nameController.text,
      win: win,
      loss: loss,
      draw: draw,
      goalsFor: editingIndex != null ? teams[editingIndex!].goalsFor : 0,
      goalsAgainst: editingIndex != null
          ? teams[editingIndex!].goalsAgainst
          : 0,
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

      nameController.clear();
      winController.clear();
      lossController.clear();
      drawController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save team: $e')));
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
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete team: $e')));
      }
    }
  }

  Team? _findTeamByName(String name) {
    try {
      return teams.firstWhere(
        (team) => team.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _applyFixtureResult(
    Map<String, dynamic> fixture, {
    bool revert = false,
  }) async {
    final homeName = fixture['homeTeam'] as String?;
    final awayName = fixture['awayTeam'] as String?;
    final homeGoals = fixture['homeGoals'] is int
        ? fixture['homeGoals'] as int
        : int.tryParse('${fixture['homeGoals']}');
    final awayGoals = fixture['awayGoals'] is int
        ? fixture['awayGoals'] as int
        : int.tryParse('${fixture['awayGoals']}');

    if (homeName == null || awayName == null) return;
    if (homeGoals == null || awayGoals == null) return;

    final homeTeam = _findTeamByName(homeName);
    final awayTeam = _findTeamByName(awayName);
    if (homeTeam == null || awayTeam == null) return;

    final homeWin = homeGoals > awayGoals ? 1 : 0;
    final homeLoss = homeGoals < awayGoals ? 1 : 0;
    final homeDraw = homeGoals == awayGoals ? 1 : 0;
    final awayWin = awayGoals > homeGoals ? 1 : 0;
    final awayLoss = awayGoals < homeGoals ? 1 : 0;
    final awayDraw = awayGoals == homeGoals ? 1 : 0;
    final factor = revert ? -1 : 1;

    final updatedHome = Team(
      id: homeTeam.id,
      name: homeTeam.name,
      win: homeTeam.win + (homeWin * factor),
      loss: homeTeam.loss + (homeLoss * factor),
      draw: homeTeam.draw + (homeDraw * factor),
      goalsFor: homeTeam.goalsFor + (homeGoals * factor),
      goalsAgainst: homeTeam.goalsAgainst + (awayGoals * factor),
      played: homeTeam.played + (1 * factor),
    );
    final updatedAway = Team(
      id: awayTeam.id,
      name: awayTeam.name,
      win: awayTeam.win + (awayWin * factor),
      loss: awayTeam.loss + (awayLoss * factor),
      draw: awayTeam.draw + (awayDraw * factor),
      goalsFor: awayTeam.goalsFor + (awayGoals * factor),
      goalsAgainst: awayTeam.goalsAgainst + (homeGoals * factor),
      played: awayTeam.played + (1 * factor),
    );

    if (homeTeam.id != null) {
      await _teamsCol.doc(homeTeam.id).set(updatedHome.toMap());
    }
    if (awayTeam.id != null) {
      await _teamsCol.doc(awayTeam.id).set(updatedAway.toMap());
    }
  }

  Future<void> _saveFixture() async {
    if (selectedHomeTeam == null || selectedAwayTeam == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both teams.')),
      );
      return;
    }
    if (selectedHomeTeam == selectedAwayTeam) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Home and away teams must differ.')),
      );
      return;
    }

    final homeGoals = homeGoalsController.text.isEmpty
        ? null
        : int.tryParse(homeGoalsController.text);
    final awayGoals = awayGoalsController.text.isEmpty
        ? null
        : int.tryParse(awayGoalsController.text);

    if ((homeGoalsController.text.isNotEmpty && homeGoals == null) ||
        (awayGoalsController.text.isNotEmpty && awayGoals == null)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Goals must be numbers.')));
      return;
    }

    final status = homeGoals != null && awayGoals != null
        ? 'completed'
        : 'scheduled';

    final fixture = {
      'homeTeam': selectedHomeTeam,
      'awayTeam': selectedAwayTeam,
      'matchTime': matchTimeController.text.trim(),
      'homeGoals': homeGoals,
      'awayGoals': awayGoals,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      if (editingFixtureId == null) {
        await _fixturesCol.add(fixture);
        if (status == 'completed') {
          await _applyFixtureResult({
            'homeTeam': selectedHomeTeam,
            'awayTeam': selectedAwayTeam,
            'homeGoals': homeGoals,
            'awayGoals': awayGoals,
          });
        }
      } else {
        final existing = fixtures.firstWhere(
          (item) => item['id'] == editingFixtureId,
          orElse: () => <String, dynamic>{},
        );
        if (existing.isNotEmpty && existing['status'] == 'completed') {
          await _applyFixtureResult(existing, revert: true);
        }
        await _fixturesCol.doc(editingFixtureId).set(fixture);
        if (status == 'completed') {
          await _applyFixtureResult({
            'homeTeam': selectedHomeTeam,
            'awayTeam': selectedAwayTeam,
            'homeGoals': homeGoals,
            'awayGoals': awayGoals,
          });
        }
      }
      _clearFixtureForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save fixture: $e')));
    }
  }

  void _editFixture(int index) {
    final fixture = fixtures[index];
    setState(() {
      editingFixtureId = fixture['id'] as String?;
      selectedHomeTeam = fixture['homeTeam'] as String?;
      selectedAwayTeam = fixture['awayTeam'] as String?;
      matchTimeController.text = fixture['matchTime'] as String? ?? '';
      homeGoalsController.text = fixture['homeGoals']?.toString() ?? '';
      awayGoalsController.text = fixture['awayGoals']?.toString() ?? '';
    });
  }

  Future<void> _deleteFixture(int index) async {
    final fixture = fixtures[index];
    try {
      if (fixture['status'] == 'completed') {
        await _applyFixtureResult(fixture, revert: true);
      }
      await _fixturesCol.doc(fixture['id'] as String).delete();
      _clearFixtureForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete fixture: $e')));
    }
  }

  void _clearFixtureForm() {
    setState(() {
      editingFixtureId = null;
      selectedHomeTeam = null;
      selectedAwayTeam = null;
      matchTimeController.clear();
      homeGoalsController.clear();
      awayGoalsController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Admin Page"),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
              onPressed: () {
                Navigator.pop(context);
                FirebaseAuth.instance.signOut();
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Set Log"),
              Tab(text: "Set Fixture"),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // 🔹 SET LOG TAB
            SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
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
                    child: Text(
                      editingIndex == null ? "Add Team" : "Update Team",
                    ),
                  ),
                  const SizedBox(height: 20),
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          title: Text(
                            team.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "P: ${team.played}, W: ${team.win}, D: ${team.draw}, L: ${team.loss}, Pts: ${team.points}",
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () => editTeam(index),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
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
                        MaterialPageRoute(builder: (_) => const Football()),
                      );
                    },
                    child: const Text("View Football Table"),
                  ),
                ],
              ),
            ),

            // 🔹 SET FIXTURE TAB
            SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    'Create or update a fixture',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedHomeTeam,
                    items: teams
                        .map(
                          (team) => DropdownMenuItem(
                            value: team.name,
                            child: Text(team.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      selectedHomeTeam = value;
                    }),
                    decoration: const InputDecoration(labelText: 'Home Team'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedAwayTeam,
                    items: teams
                        .map(
                          (team) => DropdownMenuItem(
                            value: team.name,
                            child: Text(team.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      selectedAwayTeam = value;
                    }),
                    decoration: const InputDecoration(labelText: 'Away Team'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: matchTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Match Time',
                      hintText: 'e.g. 20 April 18:00',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: homeGoalsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Home Goals',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: awayGoalsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Away Goals',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _saveFixture,
                        child: Text(
                          editingFixtureId == null
                              ? 'Save Fixture'
                              : 'Update Fixture',
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (editingFixtureId != null)
                        OutlinedButton(
                          onPressed: _clearFixtureForm,
                          child: const Text('Cancel'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Fixtures Log',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (fixtures.isEmpty)
                    const Text('No fixtures have been set yet.')
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: fixtures.length,
                      itemBuilder: (context, index) {
                        final fixture = fixtures[index];
                        final homeGoals = fixture['homeGoals'];
                        final awayGoals = fixture['awayGoals'];
                        final score = homeGoals != null && awayGoals != null
                            ? '$homeGoals - $awayGoals'
                            : 'vs';
                        final status =
                            fixture['status'] as String? ?? 'scheduled';
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 2,
                          child: ListTile(
                            title: Text(
                              '${fixture['homeTeam']} $score ${fixture['awayTeam']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(fixture['matchTime'] as String? ?? ''),
                                const SizedBox(height: 4),
                                Text(
                                  'Status: ${status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : status}',
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _editFixture(index),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteFixture(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
