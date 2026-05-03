class Team {
  String? id; // Firestore document id
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

  Map<String, dynamic> toMap() => {
    'name': name,
    'played': played,
    'win': win,
    'loss': loss,
    'draw': draw,
    'goalsFor': goalsFor,
    'goalsAgainst': goalsAgainst,
    if (logoUrl != null) 'logoUrl': logoUrl,
  };

  factory Team.fromMap(Map<String, dynamic> map, {String? id}) {
    return Team(
      id: id,
      name: map['name'] as String? ?? '',
      played: map['played'] as int? ?? 0,
      win: map['win'] as int? ?? 0,
      loss: map['loss'] as int? ?? 0,
      draw: map['draw'] as int? ?? 0,
      goalsFor: map['goalsFor'] as int? ?? 0,
      goalsAgainst: map['goalsAgainst'] as int? ?? 0,
      logoUrl: map['logoUrl'] as String?,
    );
  }
}
