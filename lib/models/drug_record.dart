class DrugRecord {
  final int? id;
  final String drugName;
  final DateTime dateTime;
  final double dose;

  DrugRecord({
    this.id,
    required this.drugName,
    required this.dateTime,
    required this.dose,
  });

  // Convert DrugRecord to a Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'drug_name': drugName,
      'date_time': dateTime.toIso8601String(),
      'dose': dose,
    };
  }

  // Create DrugRecord from a Map (from database)
  factory DrugRecord.fromMap(Map<String, dynamic> map) {
    return DrugRecord(
      id: map['id'] as int?,
      drugName: map['drug_name'] as String,
      dateTime: DateTime.parse(map['date_time'] as String),
      dose: (map['dose'] as num).toDouble(),
    );
  }

  // Create a copy of the record with optional updated fields
  DrugRecord copyWith({
    int? id,
    String? drugName,
    DateTime? dateTime,
    double? dose,
  }) {
    return DrugRecord(
      id: id ?? this.id,
      drugName: drugName ?? this.drugName,
      dateTime: dateTime ?? this.dateTime,
      dose: dose ?? this.dose,
    );
  }
}
