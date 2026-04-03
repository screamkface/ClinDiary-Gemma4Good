from app.services.document_parser import DocumentParser


def test_document_parser_extracts_lab_results():
    parser = DocumentParser()

    panel = parser.parse_lab_text(
        "Esami del sangue",
        "\n".join(
            [
                "Esami del sangue",
                "Glucosio 95 mg/dL 70-99",
                "Creatinina 1.4 mg/dL 0.7-1.2",
                "AST (GOT) 198 U/L < 40 H",
            ]
        ),
    )

    assert panel is not None
    assert len(panel.results) == 3
    results_by_name = {result.analyte_name: result for result in panel.results}
    assert results_by_name["Glucosio"].abnormal_flag is False
    assert results_by_name["Creatinina"].abnormal_flag is True
    assert results_by_name["AST (GOT)"].ref_max == 40.0


def test_document_parser_extracts_multiline_lab_table():
    parser = DocumentParser()

    panel = parser.parse_lab_text(
        "Esami del sangue",
        "\n".join(
            [
                "FACSIMILE - DATI FITTIZI - NON VALIDO",
                "Documento dimostrativo per test OCR/app ClinDiary - non usare per finalita cliniche.",
                "Risultati principali",
                "Esame",
                "Risultato",
                "Unita",
                "Valori di riferimento",
                "Flag",
                "Emoglobina",
                "7.9",
                "g/dL",
                "13.5 - 17.5",
                "L",
                "Globuli bianchi",
                "19.8",
                "x10^3/uL",
                "4.0 - 10.5",
                "H",
                "AST (GOT)",
                "198",
                "U/L",
                "< 40",
                "H",
                "Commenti automatici del laboratorio (facsimile)",
            ]
        ),
    )

    assert panel is not None
    assert panel.panel_name == "Esami del sangue"
    assert len(panel.results) == 3
    results_by_name = {result.analyte_name: result for result in panel.results}
    assert results_by_name["Emoglobina"].abnormal_flag is True
    assert results_by_name["AST (GOT)"].ref_max == 40.0
    assert results_by_name["AST (GOT)"].abnormal_flag is True


def test_document_parser_extracts_imaging_summary():
    parser = DocumentParser()

    report = parser.parse_imaging_text(
        "RX torace",
        "\n".join(
            [
                "RX torace",
                "Descrizione: non si osservano addensamenti focali.",
                "Impression: quadro radiografico senza lesioni acute.",
            ]
        ),
    )

    assert report is not None
    assert report.exam_type == "RX"
    assert report.body_part == "Torace"
    assert "senza lesioni acute" in (report.impression or "")
