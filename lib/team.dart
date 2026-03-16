class Team {
  String? id; // Firestore document id
  String name;
  int played;
  int win;
  int loss;
  int draw;

  Team({
    this.id,
    required this.name,
    required this.win,
    required this.loss,
    required this.draw,
    required int played,
  }) : played = win + draw + loss;

  int get points => win * 3 + draw * 1;

  Map<String, dynamic> toMap() => {
    'name': name,
    'played': played,
    'win': win,
    'loss': loss,
    'draw': draw,
  };

  factory Team.fromMap(Map<String, dynamic> map, {String? id}) {
    return Team(
      id: id,
      name: map['name'] as String? ?? '',
      played: map['played'] as int? ?? 0,
      win: map['win'] as int? ?? 0,
      loss: map['loss'] as int? ?? 0,
      draw: map['draw'] as int? ?? 0,
    );
  }
}
