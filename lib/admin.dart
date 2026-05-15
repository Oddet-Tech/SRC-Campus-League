import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:campus_league/football.dart';
import 'package:campus_league/team.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

// TopScorer Model
// TopScorer Model
class TopScorer {
  String id;
  String name;
  String teamname; // ✅ FIXED: String not int
  int goals;
  int assists;

  TopScorer({
    required this.id,
    required this.name,
    required this.teamname,
    required this.goals,
    required this.assists,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'Team': teamname,
      'goals': goals,
      'assists': assists,
    };
  }

  factory TopScorer.fromMap(Map<String, dynamic> map, {String? id}) {
    return TopScorer(
      id: id ?? (map['id'] as String? ?? ''),
      name: map['name'] as String? ?? '',
      teamname: map['Team'] as String? ?? '', // ✅ FIXED
      goals: map['goals'] as int? ?? 0,
      assists: map['assists'] as int? ?? 0,
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

  final matchTimeController = TextEditingController();
  final homeGoalsController = TextEditingController();
  final awayGoalsController = TextEditingController();

  // TopScorer controllers
  final playerNameController = TextEditingController();
  final playerAgeController = TextEditingController();
  final playerGoalsController = TextEditingController();
  final playerAssistsController = TextEditingController();

  String? selectedHomeTeam;
  String? selectedAwayTeam;
  String? editingFixtureId;
  List<Map<String, dynamic>> fixtures = [];
  bool isLoading = true;

  // TopScorer state
  List<TopScorer> topScorers = [];
  String? editingTopScorerId;

  final CollectionReference _teamsCol = FirebaseFirestore.instance.collection(
    'teams',
  );
  final CollectionReference _fixturesCol = FirebaseFirestore.instance
      .collection('fixtures');
  final CollectionReference _topScorersCol = FirebaseFirestore.instance
      .collection('topScorers');

  List<Team> teams = [];
  int? editingIndex;
  late StreamSubscription<QuerySnapshot> _subscription;
  late StreamSubscription<QuerySnapshot> _fixturesSubscription;
  late StreamSubscription<QuerySnapshot> _topScorersSubscription;
  

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

      _topScorersSubscription = _topScorersCol.orderBy('goals', descending: true).snapshots().listen((snapshot) {
        setState(() {
          topScorers = snapshot.docs.map((doc) {
            return TopScorer.fromMap(
              doc.data() as Map<String, dynamic>,
              id: doc.id,
            );
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
    _topScorersSubscription.cancel();
    nameController.dispose();
    winController.dispose();
    lossController.dispose();
    drawController.dispose();
    goalsForController.dispose();
    goalsAgainstController.dispose();
    matchTimeController.dispose();
    homeGoalsController.dispose();
    awayGoalsController.dispose();
    playerNameController.dispose();
    playerAgeController.dispose();
    playerGoalsController.dispose();
    playerAssistsController.dispose();
    super.dispose();
  }

  Future<void> _saveTeamsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(teams.map((t) => t.toMap()).toList());
    await prefs.setString('teams', encoded);
  }

  Future<String?> _uploadLogo(XFile logoFile) async {
    try {
      final bytes = await logoFile.readAsBytes();
      final extension = logoFile.name.contains('.')
          ? logoFile.name.split('.').last
          : 'jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('team_logos/${DateTime.now().millisecondsSinceEpoch}.$extension');
      final task = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/$extension'),
      );
      final snapshot = await task;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      return null;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo picker failed. Please try again.')),
      );
    }
  }

  void _clearLogoSelection() {
    setState(() {
      _pickedLogoFile = null;
      _logoPreviewBytes = null;
    });
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
    final goalsFor = goalsForController.text.isEmpty
        ? 0
        : int.tryParse(goalsForController.text);
    final goalsAgainst = goalsAgainstController.text.isEmpty
        ? 0
        : int.tryParse(goalsAgainstController.text);

    if (win == null || loss == null || draw == null || goalsFor == null || goalsAgainst == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'All fields must be numbers only',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
      return;
    }

    String? logoUrl = _existingLogoUrl;
    if (_pickedLogoFile != null) {
      final uploadedUrl = await _uploadLogo(_pickedLogoFile!);
      if (uploadedUrl != null) {
        logoUrl = uploadedUrl;
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo upload failed. The existing logo will remain.'),
          ),
        );
      }
    }

    final team = Team(
      name: nameController.text,
      win: win,
      loss: loss,
      draw: draw,
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
      logoUrl: logoUrl,
      played: win + loss + draw,
    );

    try {
      if (editingIndex == null) {
        final docRef = await _teamsCol.add(team.toMap());
        team.id = docRef.id;
        setState(() {
          teams.add(team);
          teams.sort((a, b) => b.points.compareTo(a.points));
        });
      } else {
        final existing = teams[editingIndex!];
        if (existing.id != null) {
          await _teamsCol.doc(existing.id).set(team.toMap());
        }
        setState(() {
          teams[editingIndex!] = Team(
            id: existing.id,
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
      goalsForController.text = team.goalsFor.toString();
      goalsAgainstController.text = team.goalsAgainst.toString();
      _pickedLogoFile = null;
      _logoPreviewBytes = null;
      _existingLogoUrl = team.logoUrl;
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
            goalsForController.clear();
            goalsAgainstController.clear();
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

  // TopScorer Methods
 Future<void> _addOrUpdateTopScorer() async {
  final name = playerNameController.text.trim();

  // ✅ TEAM NAME AS TEXT
  final teamname = playerAgeController.text.trim();

  final goals = int.tryParse(playerGoalsController.text) ?? 0;
  final assists = int.tryParse(playerAssistsController.text) ?? 0;

  if (name.isEmpty || teamname.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Player name and team name cannot be empty'),
      ),
    );
    return;
  }

  try {
    if (editingTopScorerId != null) {
      // UPDATE PLAYER
      await _topScorersCol.doc(editingTopScorerId).update({
        'name': name,
        'Team': teamname,
        'goals': goals,
        'assists': assists,
      });
    } else {
      // ADD PLAYER
      if (topScorers.length >= 30) {
        final lastPlayer = topScorers.last;
        await _topScorersCol.doc(lastPlayer.id).delete();
      }

      final docRef = _topScorersCol.doc();

      await docRef.set({
        'id': docRef.id,
        'name': name,
        'Team': teamname,
        'goals': goals,
        'assists': assists,
      });
    }

    _clearTopScorerForm();
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}

 void _editTopScorer(int index) {
  final player = topScorers[index];

  setState(() {
    editingTopScorerId = player.id;

    playerNameController.text = player.name;

    // ✅ TEAM NAME AS TEXT
    playerAgeController.text = player.teamname;

    playerGoalsController.text = player.goals.toString();
    playerAssistsController.text = player.assists.toString();
  });
}

  Future<void> _deleteTopScorer(int index) async {
    final player = topScorers[index];
    try {
      await _topScorersCol.doc(player.id).delete();
      _clearTopScorerForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _clearTopScorerForm() {
    setState(() {
      editingTopScorerId = null;
      playerNameController.clear();
      playerAgeController.clear();
      playerGoalsController.clear();
      playerAssistsController.clear();
    });
  }

  List<Map<String, dynamic>> _teamFixtures(Team team) {
    final name = team.name.toLowerCase();
    return fixtures
        .where((fixture) {
          final home = (fixture['homeTeam'] as String? ?? '').toLowerCase();
          final away = (fixture['awayTeam'] as String? ?? '').toLowerCase();
          return (home == name || away == name);
        })
        .toList()
      ..sort((a, b) {
        final aTime = a['matchTime'] as String? ?? '';
        final bTime = b['matchTime'] as String? ?? '';
        return bTime.compareTo(aTime);
      });
  }

  String _teamResultLabel(Map<String, dynamic> fixture, Team team) {
    final status = fixture['status'] as String? ?? '';
    if (status != 'completed') {
      return 'vs';
    }
    final homeGoals = fixture['homeGoals'] as int? ?? 0;
    final awayGoals = fixture['awayGoals'] as int? ?? 0;
    final isHome = (fixture['homeTeam'] as String? ?? '').toLowerCase() == team.name.toLowerCase();
    final scored = isHome ? homeGoals : awayGoals;
    final conceded = isHome ? awayGoals : homeGoals;
    if (scored > conceded) {
      return 'W';
    }
    if (scored == conceded) {
      return 'D';
    }
    return 'L';
  }

  Color _teamResultColor(String label) {
    if (label == 'W') return Colors.green;
    if (label == 'D' || label == 'vs') return Colors.grey;
    return Colors.red;
  }

  void _showTeamDetails(Team team, int position) {
    final history = _teamFixtures(team);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: team.logoUrl != null && team.logoUrl!.isNotEmpty
                    ? NetworkImage(team.logoUrl!) as ImageProvider
                    : null,
                child: team.logoUrl == null || team.logoUrl!.isEmpty
                    ? Text(
                        team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Position #$position • ${team.points} pts',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record: ${team.win}-${team.draw}-${team.loss} • P: ${team.played} • GF: ${team.goalsFor} GA: ${team.goalsAgainst}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Match Results',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (history.isEmpty)
                  const Text('No completed matches found for this team.')
                else
                  Column(
                    children: history.map((fixture) {
                      final label = _teamResultLabel(fixture, team);
                      final homeGoals = fixture['homeGoals'] as int?;
                      final awayGoals = fixture['awayGoals'] as int?;
                      final score = homeGoals != null && awayGoals != null
                          ? '$homeGoals - $awayGoals'
                          : 'vs';
                      final status = fixture['status'] as String? ?? '';
                      final opponentName = fixture['homeTeam'] == team.name ? fixture['awayTeam'] : fixture['homeTeam'];
                      Team? opponentTeam;
                      try {
                        opponentTeam = teams.firstWhere((t) => t.name.trim().toLowerCase() == opponentName.trim().toLowerCase());
                      } catch (e) {
                        opponentTeam = null;
                      }
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: opponentTeam?.logoUrl != null && opponentTeam!.logoUrl!.isNotEmpty
                              ? NetworkImage(opponentTeam.logoUrl!) as ImageProvider
                              : null,
                          child: opponentTeam?.logoUrl == null || opponentTeam!.logoUrl!.isEmpty
                              ? Text(
                                  opponentName.isNotEmpty ? opponentName[0].toUpperCase() : '?',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        title: Text(
                          '${fixture['homeTeam']} $score ${fixture['awayTeam']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fixture['matchTime'] as String? ?? ''),
                            const SizedBox(height: 2),
                            Text(
                              status.isNotEmpty ? status.toUpperCase() : 'UNKNOWN',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
              Tab(text: "Top Scorers"),
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
                  TextField(
                    controller: goalsForController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Goals For"),
                  ),
                  TextField(
                    controller: goalsAgainstController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Goals Against"),
                  ),
                  const SizedBox(height: 12),
                  if (editingIndex != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickLogo,
                              icon: const Icon(Icons.image),
                              label: const Text('Upload/Change Logo'),
                            ),
                            const SizedBox(width: 12),
                            if (_pickedLogoFile != null)
                              TextButton(
                                onPressed: _clearLogoSelection,
                                child: const Text('Clear selection'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _pickedLogoFile != null
                              ? 'New logo: ${_pickedLogoFile!.name}'
                              : _existingLogoUrl != null
                                  ? 'Current logo will be kept unless changed'
                                  : 'No logo selected',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        if (_logoPreviewBytes != null)
                          Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                              image: DecorationImage(
                                image: MemoryImage(_logoPreviewBytes!),
                                fit: BoxFit.contain,
                              ),
                            ),
                          )
                        else if (_existingLogoUrl != null)
                          Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _existingLogoUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                      ],
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showTeamDetails(team, index + 1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              leading: CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: team.logoUrl != null && team.logoUrl!.isNotEmpty
                                    ? NetworkImage(team.logoUrl!) as ImageProvider
                                    : null,
                                child: team.logoUrl == null || team.logoUrl!.isEmpty
                                    ? Icon(
                                        Icons.image,
                                        color: Colors.grey.shade700,
                                        size: 28,
                                      )
                                    : null,
                              ),
                              title: Text(
                                team.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Position #${index + 1} • P: ${team.played}, W: ${team.win}, D: ${team.draw}, L: ${team.loss}, Pts: ${team.points}',
                                style: TextStyle(color: Colors.grey.shade700),
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
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
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
            // 🔹 TOP SCORERS TAB
            SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    'Add Player to Top Scorers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: playerNameController,
                    decoration: const InputDecoration(labelText: 'Player Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: playerAgeController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(labelText: 'Team'),
                   ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: playerGoalsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Goals'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: playerAssistsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Assists'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _addOrUpdateTopScorer,
                        child: Text(
                          editingTopScorerId == null
                              ? 'Add Player'
                              : 'Update Player',
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (editingTopScorerId != null)
                        OutlinedButton(
                          onPressed: _clearTopScorerForm,
                          child: const Text('Cancel'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Top Scorers List (Max 30)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (topScorers.isEmpty)
                    const Text('No players added yet.')
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: topScorers.length,
                      itemBuilder: (context, index) {
                        final player = topScorers[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 2,
                          child: ListTile(
                            title: Text(
                              '${index + 1}. ${player.name}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                             'Team: ${player.teamname}, Goals: ${player.goals}, Assists: ${player.assists}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _editTopScorer(index),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteTopScorer(index),
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

