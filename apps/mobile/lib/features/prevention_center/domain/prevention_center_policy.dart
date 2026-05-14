class RegionalPreventionPolicy {
  final String regionCode;

  final int mammographyCoreStartAge;
  final int mammographyCoreEndAge;
  final bool mammographyExtended45To49;
  final bool mammographyExtended70To74;

  final int colorectalStartAge;
  final int colorectalEndAge;
  final bool colorectalExtended70To74;

  final int cervicalStartAge;
  final int cervicalEndAge;
  final int cervicalPapStartAge;
  final int cervicalHpvStartAge;

  final int lungLdctStartAge;
  final int lungLdctEndAge;

  final int aaaStartAge;
  final int aaaEndAge;

  const RegionalPreventionPolicy({
    required this.regionCode,
    this.mammographyCoreStartAge = 50,
    this.mammographyCoreEndAge = 69,
    this.mammographyExtended45To49 = false,
    this.mammographyExtended70To74 = false,
    this.colorectalStartAge = 50,
    this.colorectalEndAge = 69,
    this.colorectalExtended70To74 = false,
    this.cervicalStartAge = 25,
    this.cervicalEndAge = 64,
    this.cervicalPapStartAge = 25,
    this.cervicalHpvStartAge = 30,
    this.lungLdctStartAge = 50,
    this.lungLdctEndAge = 80,
    this.aaaStartAge = 65,
    this.aaaEndAge = 75,
  });

  factory RegionalPreventionPolicy.forRegion(String regionCode) {
    final code = regionCode.toUpperCase();

    if (code == 'IT') {
      return const RegionalPreventionPolicy(
        regionCode: 'IT',
        mammographyCoreStartAge: 50,
        mammographyCoreEndAge: 69,
        mammographyExtended45To49: true,
        mammographyExtended70To74: true,
        colorectalStartAge: 50,
        colorectalEndAge: 69,
        colorectalExtended70To74: true,
        cervicalStartAge: 25,
        cervicalEndAge: 64,
        cervicalPapStartAge: 25,
        cervicalHpvStartAge: 30,
        lungLdctStartAge: 50,
        lungLdctEndAge: 80,
        aaaStartAge: 65,
        aaaEndAge: 75,
      );
    }

    // US — USPSTF guidelines (2024-2026)
    if (code == 'US') {
      return const RegionalPreventionPolicy(
        regionCode: 'US',
        mammographyCoreStartAge: 50,
        mammographyCoreEndAge: 74,
        mammographyExtended45To49: true,
        mammographyExtended70To74: true,
        colorectalStartAge: 50,
        colorectalEndAge: 75,
        colorectalExtended70To74: false,
        cervicalStartAge: 21,
        cervicalEndAge: 65,
        cervicalPapStartAge: 21,
        cervicalHpvStartAge: 30,
        lungLdctStartAge: 50,
        lungLdctEndAge: 80,
        aaaStartAge: 65,
        aaaEndAge: 75,
      );
    }

    // UK — NHS screening programmes
    if (code == 'UK' || code == 'GB') {
      return const RegionalPreventionPolicy(
        regionCode: 'UK',
        mammographyCoreStartAge: 50,
        mammographyCoreEndAge: 71,
        mammographyExtended45To49: true,
        mammographyExtended70To74: true,
        colorectalStartAge: 60,
        colorectalEndAge: 74,
        colorectalExtended70To74: false,
        cervicalStartAge: 25,
        cervicalEndAge: 64,
        cervicalPapStartAge: 25,
        cervicalHpvStartAge: 25,
        lungLdctStartAge: 55,
        lungLdctEndAge: 74,
        aaaStartAge: 65,
        aaaEndAge: 75,
      );
    }

    return RegionalPreventionPolicy(regionCode: code);
  }
}
