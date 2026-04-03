class ItalianRegionOption {
  const ItalianRegionOption({required this.code, required this.label});

  final String code;
  final String label;
}

const italianRegionOptions = <ItalianRegionOption>[
  ItalianRegionOption(code: 'IT', label: 'Italia (generale)'),
  ItalianRegionOption(code: 'IT-ABR', label: 'Abruzzo'),
  ItalianRegionOption(code: 'IT-BAS', label: 'Basilicata'),
  ItalianRegionOption(code: 'IT-CAL', label: 'Calabria'),
  ItalianRegionOption(code: 'IT-CAM', label: 'Campania'),
  ItalianRegionOption(code: 'IT-EMR', label: 'Emilia-Romagna'),
  ItalianRegionOption(code: 'IT-FVG', label: 'Friuli Venezia Giulia'),
  ItalianRegionOption(code: 'IT-LAZ', label: 'Lazio'),
  ItalianRegionOption(code: 'IT-LIG', label: 'Liguria'),
  ItalianRegionOption(code: 'IT-LOM', label: 'Lombardia'),
  ItalianRegionOption(code: 'IT-MAR', label: 'Marche'),
  ItalianRegionOption(code: 'IT-MOL', label: 'Molise'),
  ItalianRegionOption(code: 'IT-PIE', label: 'Piemonte'),
  ItalianRegionOption(code: 'IT-PUG', label: 'Puglia'),
  ItalianRegionOption(code: 'IT-SAR', label: 'Sardegna'),
  ItalianRegionOption(code: 'IT-SIC', label: 'Sicilia'),
  ItalianRegionOption(code: 'IT-TOS', label: 'Toscana'),
  ItalianRegionOption(code: 'IT-TAA', label: 'Trentino-Alto Adige/Südtirol'),
  ItalianRegionOption(code: 'IT-UMB', label: 'Umbria'),
  ItalianRegionOption(code: 'IT-VDA', label: "Valle d'Aosta"),
  ItalianRegionOption(code: 'IT-VEN', label: 'Veneto'),
];

String italianRegionLabel(String? code) {
  if (code == null || code.trim().isEmpty) {
    return 'Italia (generale)';
  }

  final normalized = code.trim().toUpperCase();
  for (final option in italianRegionOptions) {
    if (option.code.toUpperCase() == normalized) {
      return option.label;
    }
  }
  return code;
}
