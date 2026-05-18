import 'dart:async';
import 'package:flutter/material.dart';
import 'package:campus_league/team.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Class to represent a completed fixture result
class ResultFixture {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final int homeGoals;
  final int awayGoals;
  final String matchTime;

  ResultFixture({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeGoals,
    required this.awayGoals,
    required this.matchTime,
  });

  factory ResultFixture.fromMap(Map<String, dynamic> map, {required String id}) {
    return ResultFixture(
      id: id,
      homeTeam: map['homeTeam'] as String? ?? '',
      awayTeam: map['awayTeam'] as String? ?? '',
      homeGoals: map['homeGoals'] as int? ?? 0,
      awayGoals: map['awayGoals'] as int? ?? 0,
      matchTime: map['matchTime'] as String? ?? '',
    );
  }
}

class Football extends StatefulWidget {
  const Football({super.key});

  @override
  State<Football> createState() => _FootballState();
}

class _FootballState extends State<Football> {
  final CollectionReference _teamsCol = FirebaseFirestore.instance.collection(
    'teams',
  );
  final CollectionReference _fixturesCol = FirebaseFirestore.instance
      .collection('fixtures');

  List<Team> teams = [];
  List<Map<String, dynamic>> fixtures = [];
  List<ResultFixture> results = [];
  List<Map<String, dynamic>> allFixtures = [];
  late StreamSubscription<QuerySnapshot> _sub;
  late StreamSubscription<QuerySnapshot> _fixtureSub;
  bool isLoading = true;
  bool isFixturesLoading = true;

  @override
  void initState() {
    super.initState();
    _sub = _teamsCol.snapshots().listen(
      (snapshot) {
        setState(() {
          teams =
              snapshot.docs
                  .map(
                    (d) => Team.fromMap(
                      d.data() as Map<String, dynamic>,
                      id: d.id,
                    ),
                  )
                  .toList();
          // Sort by: points (desc), then goalDifference (desc), then goalsFor (desc)
          teams.sort((a, b) {
            if (b.points != a.points) {
              return b.points.compareTo(a.points);
            }
            if (b.goalDifference != a.goalDifference) {
              return b.goalDifference.compareTo(a.goalDifference);
            }
            return b.goalsFor.compareTo(a.goalsFor);
          });
          isLoading = false;
        });
      },
      onError: (error) {
        setState(() {
          isLoading = false;
        });
      },
    );

    _fixtureSub = _fixturesCol.snapshots().listen((snapshot) {
      setState(() {
        final allFixturesData = snapshot.docs.map((doc) {
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
        
        allFixtures = allFixturesData;
        
        // Filter scheduled fixtures
        fixtures = allFixturesData
            .where((f) => f['status'] == 'scheduled')
            .toList();
        
        // Filter completed fixtures for Results tab
        results = allFixturesData
            .where((f) => f['status'] == 'completed')
            .map((f) => ResultFixture.fromMap(f, id: f['id'] as String))
            .toList();
        
        isFixturesLoading = false;
      });
    }, onError: (error) {
      setState(() {
        isFixturesLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _fixtureSub.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _teamFixtures(Team team) {
    final name = team.name.toLowerCase();
    return allFixtures
        .where((fixture) {
          final home = (fixture['homeTeam'] as String? ?? '').toLowerCase();
          final away = (fixture['awayTeam'] as String? ?? '').toLowerCase();
          return home == name || away == name;
        })
        .toList()
      ..sort((a, b) {
        final aTime = a['matchTime'] as String? ?? '';
        final bTime = b['matchTime'] as String? ?? '';
        return bTime.compareTo(aTime);
      });
  }

  List<Map<String, dynamic>> _teamCompletedFixtures(Team team) {
    return _teamFixtures(team)
        .where((fixture) => (fixture['status'] as String? ?? '') == 'completed')
        .toList();
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
    if (scored > conceded) return 'W';
    if (scored == conceded) return 'D';
    return 'L';
  }

  Color _teamResultColor(String label) {
    if (label == 'W') return Colors.green;
    if (label == 'D' || label == 'vs') return Colors.grey;
    return Colors.red;
  }

  void _showTeamDetails(Team team, int position) {
    final teamFixtures = _teamCompletedFixtures(team);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              CircleAvatar(
                radius: 24,
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
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Position #$position • ${team.points} pts',
                      style: TextStyle(color: Colors.grey.shade700),
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
                const SizedBox(height: 12),
                const Text(
                  'Results',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (teamFixtures.isEmpty)
                  const Text('No results available for this team.')
                else
                  Column(
                    children: teamFixtures.map((fixture) {
                      final label = _teamResultLabel(fixture, team);
                      final homeGoals = fixture['homeGoals'] as int?;
                      final awayGoals = fixture['awayGoals'] as int?;
                      final score = homeGoals != null && awayGoals != null
                          ? '$homeGoals - $awayGoals'
                          : 'vs';
                      final status = fixture['status'] as String? ?? 'scheduled';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: _teamResultColor(label).withOpacity(0.2),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: _teamResultColor(label),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                              status.toUpperCase(),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
    final sortedTeams = List<Team>.from(teams);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Football",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Table"),
              Tab(text: "Fixtures"),
              Tab(text: "Results"),
            ],
          ),
        ),

        body: TabBarView(
          children: [
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : sortedTeams.isEmpty
                    ? const Center(child: Text("No Teams Yet"))
                    : SingleChildScrollView(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topLeft,
                          child: DataTable(
                             columnSpacing: 10,
                             horizontalMargin: 100,
                           dataRowMinHeight: 70,
                            dataRowMaxHeight: 70,
                            columns: const [
                              DataColumn(label: Text("Pos", style: TextStyle(fontWeight: FontWeight.bold,fontSize: 26))),
                              DataColumn(label: Text("Team", style: TextStyle(fontWeight: FontWeight.bold,fontSize: 26))),
                              DataColumn(label: Text("P", style: TextStyle(fontWeight: FontWeight.bold,fontSize: 26))),
                              DataColumn(label: Text("W", style: TextStyle(fontWeight: FontWeight.bold,fontSize: 26))),
                              DataColumn(label: Text("D", style: TextStyle(fontWeight: FontWeight.bold,fontSize: 26))),
                              DataColumn(label: Text("L", style: TextStyle(fontWeight: FontWeight.bold,fontSize: 26))),
                              DataColumn(label: Text("GF", style: TextStyle(fontWeight: FontWeight.bold,fontSize: 26))),
                              DataColumn(label: Text("GA", style: TextStyle(fontWeight: FontWeight.bold,fontSize: 26))),
                              DataColumn(label: Text("GD", style: TextStyle(fontWeight: FontWeight.bold,fontSize: 26))),
                              DataColumn(label: Text("Pts", style: TextStyle(fontWeight: FontWeight.bold,fontSize: 26))),
                            ],
                            rows: List.generate(sortedTeams.length, (index) {
                              final team = sortedTeams[index];
                              return DataRow(
                                cells: [
                                  DataCell(Text("${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold,fontSize:26))),
                                  DataCell(
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Colors.grey.shade200,
                                          backgroundImage: team.logoUrl != null && team.logoUrl!.isNotEmpty
                                              ? NetworkImage(team.logoUrl!) as ImageProvider
                                              : null,
                                          child: team.logoUrl == null || team.logoUrl!.isEmpty
                                              ? const Icon(Icons.image, size: 14, color: Colors.grey)
                                              : null,
                                        ),
                                        const SizedBox(width: 20),
                                        Flexible(
                                          child: Text(
                                            team.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26),
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _showTeamDetails(team, index + 1),
                                  ),
                                  DataCell(Text("${team.played}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26))),
                                  DataCell(Text("${team.win}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 26))),
                                  DataCell(Text("${team.draw}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26))),
                                  DataCell(Text("${team.loss}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 26))),
                                  DataCell(Text("${team.goalsFor}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26))),
                                  DataCell(Text("${team.goalsAgainst}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26))),
                                  DataCell(Text(
                                    "${team.goalDifference > 0 ? '+' : ''}${team.goalDifference}",
                                    style: TextStyle(
                                      color: team.goalDifference > 0
                                          ? Colors.green
                                          : team.goalDifference < 0
                                              ? Colors.red
                                              : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 26,
                                    ),
                                  )),
                                  DataCell(Text("${team.points}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26))),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),

            isFixturesLoading
                ? const Center(child: CircularProgressIndicator())
                : fixtures.isEmpty
                    ? const Center(child: Text("No scheduled fixtures", style: TextStyle(fontSize: 18)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: fixtures.length,
                        itemBuilder: (context, index) {
                          final fixture = fixtures[index];
                          final homeGoals = fixture['homeGoals'];
                          final awayGoals = fixture['awayGoals'];
                          final score = homeGoals != null && awayGoals != null
                              ? '$homeGoals - $awayGoals'
                              : 'vs';

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            elevation: 2,
                            child: ListTile(
                              title: Text(
                                '${fixture['homeTeam']} $score ${fixture['awayTeam']}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(fixture['matchTime'] as String? ?? ''),
                            ),
                          );
                        },
                      ),

            isFixturesLoading
                ? const Center(child: CircularProgressIndicator())
                : results.isEmpty
                    ? const Center(child: Text("No completed matches yet", style: TextStyle(fontSize: 18)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final result = results[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            elevation: 2,
                            child: ListTile(
                              title: Text(
                                '${result.homeTeam} ${result.homeGoals} - ${result.awayGoals} ${result.awayTeam}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(result.matchTime),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}