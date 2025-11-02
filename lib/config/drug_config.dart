class DrugConfig {
  final String name;
  final double tabletDoseMg;

  const DrugConfig({required this.name, required this.tabletDoseMg});

  static const List<DrugConfig> drugs = [
    DrugConfig(name: 'Diazepam', tabletDoseMg: 10.0),
    DrugConfig(name: 'Doxylamide', tabletDoseMg: 25.0),
    DrugConfig(name: 'Zolpidem', tabletDoseMg: 10.0),
  ];

  static DrugConfig? getDrugByName(String name) {
    try {
      return drugs.firstWhere((drug) => drug.name == name);
    } catch (e) {
      return null;
    }
  }

  // Convert fraction string like "1/2" or "1/4" to mg
  double? convertFractionToMg(String fraction) {
    // Check if it's a fraction format like "1/2" or "1/4"
    if (fraction.contains('/')) {
      final parts = fraction.split('/');
      if (parts.length == 2) {
        final numerator = double.tryParse(parts[0].trim());
        final denominator = double.tryParse(parts[1].trim());

        if (numerator != null && denominator != null && denominator != 0) {
          return (numerator / denominator) * tabletDoseMg;
        }
      }
      return null;
    }

    // Otherwise, try to parse as a regular number
    return double.tryParse(fraction);
  }

  // Convert mg back to fraction string if possible
  String convertMgToFraction(double mg) {
    // Check if it's exactly 1/2 tablet
    if ((mg - tabletDoseMg / 2).abs() < 0.001) {
      return '1/2';
    }
    // Check if it's exactly 1/4 tablet
    if ((mg - tabletDoseMg / 4).abs() < 0.001) {
      return '1/4';
    }
    // Check if it's exactly 3/4 tablet
    if ((mg - 3 * tabletDoseMg / 4).abs() < 0.001) {
      return '3/4';
    }
    // Otherwise return as decimal
    return mg.toStringAsFixed(2);
  }
}
