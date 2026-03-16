import 'dart:async';
import 'package:flutter/material.dart';
import 'package:src_project/team.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// football view listens to the same Firestore collection

class Football extends StatefulWidget {
  const Football({super.key});

  @override
  State<Football> createState() => _FootballState();
}

class _FootballState extends State<Football> {
  final CollectionReference _teamsCol = FirebaseFirestore.instance.collection(
    'teams',
  );
  List<Team> teams = [];
  late StreamSubscription<QuerySnapshot> _sub;
  bool isLoading = true; // <-- loading flag

  @override
  void initState() {
    super.initState();
    _sub = _teamsCol.snapshots().listen((snapshot) {
      setState(() {
        teams =
            snapshot.docs
                .map(
                  (d) =>
                      Team.fromMap(d.data() as Map<String, dynamic>, id: d.id),
                )
                .toList()
              ..sort((a, b) => b.points.compareTo(a.points));
        isLoading = false; // data loaded
      });
    }, onError: (error) {
      setState(() {
        isLoading = false; // stop loading even if error
      });
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sortedTeams = List<Team>.from(teams);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Football Table",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(), // <-- loading circle
            )
          : sortedTeams.isEmpty
              ? const Center(
                  child: Text("No Teams Yet"),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topLeft,
                        child: DataTable(
                          columns: const [
                            DataColumn(
                              label: Text(
                                "Pos",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                "Team",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                "P",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                "W",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                "D",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                "L",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                "Pts",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          rows: List.generate(sortedTeams.length, (index) {
                            final team = sortedTeams[index];
                            return DataRow(
                              cells: [
                                DataCell(Text("${index + 1}")),
                                DataCell(Text(team.name)),
                                DataCell(
                                  Text(
                                    "${team.played}",
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    "${team.win}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                                DataCell(Text("${team.draw}")),
                                DataCell(
                                  Text(
                                    "${team.loss}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                                DataCell(Text("${team.points}",style: const TextStyle(fontWeight: FontWeight.bold),)),
                              ],
                            );
                          }),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}