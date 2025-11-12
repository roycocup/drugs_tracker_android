import '../models/drug.dart';

class DrugConfig {
  const DrugConfig._();

  static const List<Drug> defaultDrugs = [
    Drug(name: 'Diazepam', tabletDoseMg: 10.0),
    Drug(name: 'Doxylamine', tabletDoseMg: 25.0),
    Drug(name: 'Zolpidem', tabletDoseMg: 10.0),
    Drug(name: 'Coffee', tabletDoseMg: 100.0),
    Drug(name: 'Tea', tabletDoseMg: 100.0),
  ];
}
