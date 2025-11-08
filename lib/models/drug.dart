class Drug {
  final int? id;
  final String name;
  final double tabletDoseMg;

  const Drug({this.id, required this.name, required this.tabletDoseMg});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'tablet_dose': tabletDoseMg};
  }

  Map<String, dynamic> toInsertMap() {
    return {'name': name, 'tablet_dose': tabletDoseMg};
  }

  factory Drug.fromMap(Map<String, dynamic> map) {
    return Drug(
      id: map['id'] as int?,
      name: map['name'] as String,
      tabletDoseMg: (map['tablet_dose'] as num).toDouble(),
    );
  }

  Drug copyWith({int? id, String? name, double? tabletDoseMg}) {
    return Drug(
      id: id ?? this.id,
      name: name ?? this.name,
      tabletDoseMg: tabletDoseMg ?? this.tabletDoseMg,
    );
  }

  double? convertFractionToMg(String fraction) {
    final trimmed = fraction.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed.contains('/')) {
      final parts = trimmed.split('/');
      if (parts.length == 2) {
        final numerator = double.tryParse(parts[0].trim());
        final denominator = double.tryParse(parts[1].trim());
        if (numerator != null && denominator != null && denominator != 0) {
          return (numerator / denominator) * tabletDoseMg;
        }
      }
      return null;
    }

    return double.tryParse(trimmed);
  }

  String convertMgToFraction(double mg) {
    if (tabletDoseMg <= 0) {
      return mg.toStringAsFixed(2);
    }

    final halfTablet = tabletDoseMg / 2;
    final quarterTablet = tabletDoseMg / 4;
    final threeQuarterTablet = 3 * tabletDoseMg / 4;

    if ((mg - halfTablet).abs() < 0.001) {
      return '1/2';
    }
    if ((mg - quarterTablet).abs() < 0.001) {
      return '1/4';
    }
    if ((mg - threeQuarterTablet).abs() < 0.001) {
      return '3/4';
    }

    if ((mg - tabletDoseMg).abs() < 0.001) {
      return tabletDoseMg.toStringAsFixed(2);
    }

    return mg.toStringAsFixed(2);
  }
}
