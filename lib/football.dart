import 'dart:async';
import 'package:flutter/material.dart';
import 'package:campus_league/team.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
                  .toList()
                ..sort((a, b) => b.points.compareTo(a.points));
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

  @override
  Widget build(BuildContext context) {
    final sortedTeams = List<Team>.from(teams);

    return DefaultTabController(
      length: 2,
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
            ],
          ),
        ),

        body: TabBarView(
          children: [
            // 🔹 TAB 1: FOOTBALL TABLE
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : sortedTeams.isEmpty
                ? const Center(child: Text("No Teams Yet"))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topLeft,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text("Pos")),
                              DataColumn(label: Text("Team")),
                              DataColumn(label: Text("P")),
                              DataColumn(label: Text("W")),
                              DataColumn(label: Text("D")),
                              DataColumn(label: Text("L")),
                              DataColumn(label: Text("Pts")),
                            ],
                            rows: List.generate(sortedTeams.length, (index) {
                              final team = sortedTeams[index];
                              return DataRow(
                                cells: [
                                  DataCell(Text("${index + 1}")),
                                  DataCell(Text(team.name)),
                                  DataCell(Text("${team.played}")),
                                  DataCell(
                                    Text(
                                      "${team.win}",
                                      style: const TextStyle(
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text("${team.draw}")),
                                  DataCell(
                                    Text(
                                      "${team.loss}",
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      "${team.points}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      );
                    },
                  ),

            // 🔹 TAB 2: FIXTURES
            isFixturesLoading
                ? const Center(child: CircularProgressIndicator())
                : fixtures.isEmpty
                    ? const Center(
                        child: Text(
                          "No fixtures set yet",
                          style: TextStyle(fontSize: 18),
                        ),
                      )
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
                      final status =
                          fixture['status'] as String? ?? 'scheduled';
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 2,
                        child: ListTile(
                          title: Text(
                            '${fixture['homeTeam']} $score ${fixture['awayTeam']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
