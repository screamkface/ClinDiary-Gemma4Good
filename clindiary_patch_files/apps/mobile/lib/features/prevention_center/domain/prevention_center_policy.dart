class RegionalPreventionPolicy {
  const RegionalPreventionPolicy({
    required this.regionCode,
    this.mammographyCoreStartAge = 50,
    this.mammographyCoreEndAge = 69,
    this.mammographyExtended45To49 = false,
    this.mammographyExtended70To74 = false,
    this.cervicalPapStartAge = 25,
    this.cervicalHpvStartAge = 30,
    this.cervicalEndAge = 64,
    this.colorectalStartAge = 50,
    this.colorectalEndAge = 69,
    this.colorectalExtended70To74 = false,
    this.lungLdctStartAge = 50,
    this.lungLdctEndAge = 80,
    this.aaaStartAge = 65,
    this.aaaEndAge = 75,
  });

  final String regionCode;

  final int mammographyCoreStartAge;
  final int mammographyCoreEndAge;
  final bool mammographyExtended45To49;
  final bool mammographyExtended70To74;

  final int cervicalPapStartAge;
  final int cervicalHpvStartAge;
  final int cervicalEndAge;

  final int colorectalStartAge;
  final int colorectalEndAge;
  final bool colorectalExtended70To74;

  final int lungLdctStartAge;
  final int lungLdctEndAge;

  final int aaaStartAge;
  final int aaaEndAge;

  factory RegionalPreventionPolicy.forRegion(String regionCode) {
    final code = regionCode.toUpperCase();

    if (code == 'IT') {
      return const RegionalPreventionPolicy(
        regionCode: 'IT',
        mammographyCoreStartAge: 50,
        mammographyCoreEndAge: 69,
        mammographyExtended45To49: true,
        mammographyExtended70To74: true,
        cervicalPapStartAge: 25,
        cervicalHpvStartAge: 30,
        cervicalEndAge: 64,
        colorectalStartAge: 50,
        colorectalEndAge: 69,
        colorectalExtended70To74: true,
        lungLdctStartAge: 50,
        lungLdctEndAge: 80,
        aaaStartAge: 65,
        aaaEndAge: 75,
      );
    }

    return RegionalPreventionPolicy(regionCode: code);
  }
}
