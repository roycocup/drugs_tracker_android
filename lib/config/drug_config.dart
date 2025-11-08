import '../models/drug.dart';

class DrugConfig {
  const DrugConfig._();

  static const List<Drug> defaultDrugs = [
    Drug(name: 'Diazepam', tabletDoseMg: 10.0),
    Drug(name: 'Doxylamide', tabletDoseMg: 25.0),
    Drug(name: 'Zolpidem', tabletDoseMg: 10.0),
  ];
}
