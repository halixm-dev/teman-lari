/// Domain logic for calculating demographic physiological baselines.
class DemographicsCalculator {
  const DemographicsCalculator._();

  /// Calculates estimated Maximum Heart Rate using the Fox formula:
  /// HR_max = 220 - age
  static int calculateFoxMaxHr(int age) {
    return 220 - age;
  }

  /// Calculates estimated Maximum Heart Rate using the clinically validated Tanaka formula:
  /// HR_max = round(208 - 0.7 * age)
  static int calculateTanakaMaxHr(int age) {
    return (208 - 0.7 * age).round();
  }

  /// Calculates elapsed age in years from birth date given an optional reference date.
  static int calculateAge(DateTime birthDate, [DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}
