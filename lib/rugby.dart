import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class TopScorer {
  String id;
  String name;
  String teamname;
  int goals;
  int assists;

  TopScorer({
    required this.id,
    required this.name,
    required this.teamname,
    required this.goals,
    required this.assists,
  });

  factory TopScorer.fromMap(Map<String, dynamic> map, {String? id}) {
    return TopScorer(
      id: id ?? (map['id'] as String? ?? ''),
      name: map['name'] as String? ?? '',
      teamname: map['Team'] as String? ?? '',
      goals: map['goals'] as int? ?? 0,
      assists: map['assists'] as int? ?? 0,
    );
  }
  
  bool isBestPlayer() {
    // Best player: is in top 10 goal scorers AND has assists
    return true; // Will filter in _loadTopScorers
  }
}

class Rugby extends StatefulWidget {
  const Rugby({super.key});

  @override
  State<Rugby> createState() => _RugbyState();
}

class _RugbyState extends State<Rugby> {
  List<TopScorer> allPlayers = [];
  List<TopScorer> bestPlayers = [];
  bool isLoading = true;
  String searchQuery = '';
  late StreamSubscription<QuerySnapshot> _topScorersSubscription;

  final CollectionReference _topScorersCol = FirebaseFirestore.instance
      .collection('topScorers');

  @override
  void initState() {
    super.initState();
    _loadTopScorers();
  }

  void _loadTopScorers() {
    try {
      _topScorersSubscription = _topScorersCol
          .orderBy('goals', descending: true)
          .snapshots()
          .listen((snapshot) {
        setState(() {
          allPlayers = snapshot.docs.map((doc) {
            return TopScorer.fromMap(
              doc.data() as Map<String, dynamic>,
              id: doc.id,
            );
          }).toList();

          // Filter best players: Top 10 goal scorers with assists, then take top 5
          final topWithAssists = allPlayers
              .take(10) // Get top 10 by goals
              .where((p) => p.assists > 0) // Must have assists
              .toList();
          topWithAssists.sort((a, b) => b.assists.compareTo(a.assists)); // Sort by most assists
          bestPlayers = topWithAssists.take(5).toList(); // Keep only top 5

          isLoading = false;
        });
      }, onError: (error) {
        setState(() {
          isLoading = false;
        });
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _topScorersSubscription.cancel();
    super.dispose();
  }

  List<TopScorer> get filteredPlayers {
    if (searchQuery.isEmpty) {
      return allPlayers;
    }
    return allPlayers
        .where((p) => p.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: const Center(
            child: Text(
              "Top Scorers",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'All Players'),
              Tab(text: 'Best Players ⭐'),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // 🔹 ALL PLAYERS TAB
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: TextField(
                          onChanged: (value) {
                            setState(() {
                              searchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Search players',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: filteredPlayers.isEmpty
                            ? const Center(
                                child: Text('No players found'),
                              )
                            : ListView.builder(
                                itemCount: filteredPlayers.length,
                                itemBuilder: (context, index) {
                                  final player = filteredPlayers[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    elevation: 2,
                                    child: ListTile(
                                      title: Text(
                                        '${index + 1}. ${player.name}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                       'Team: ${player.teamname}, Goals: ${player.goals}, Assists: ${player.assists}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                  // 🔹 BEST PLAYERS TAB
                  bestPlayers.isEmpty
                      ? const Center(
                          child: Text(
                            'No best players yet\n(Need top 10 goals + assists)',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(10),
                          itemCount: bestPlayers.length,
                          itemBuilder: (context, index) {
                            final player = bestPlayers[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              elevation: 3,
                              color: Colors.amber.shade50,
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade200,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  '${player.name} ⭐',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  'Team: ${player.teamname} | Goals: ${player.goals} | Assists: ${player.assists}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
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
