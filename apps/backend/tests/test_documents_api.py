from io import BytesIO

from reportlab.pdfgen import canvas


def _pdf_bytes(lines: list[str]) -> bytes:
    buffer = BytesIO()
    pdf = canvas.Canvas(buffer)
    y = 800
    for line in lines:
        pdf.drawString(72, y, line)
        y -= 20
    pdf.save()
    return buffer.getvalue()


def _png_bytes() -> bytes:
    return (
        b"\x89PNG\r\n\x1a\n"
        b"\x00\x00\x00\rIHDR"
        b"\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00"
        b"\x1f\x15\xc4\x89"
        b"\x00\x00\x00\x0cIDAT\x08\xd7c\xf8\xff\xff?\x00\x05\xfe\x02\xfeA\x0f\xa7\x1d"
        b"\x00\x00\x00\x00IEND\xaeB`\x82"
    )


def test_free_plan_keeps_cloud_archive_readable_but_locks_mutations(client, free_auth_headers):
    list_response = client.get("/api/v1/documents", headers=free_auth_headers)
    assert list_response.status_code == 200
    assert list_response.json() == []

    archive_response = client.get("/api/v1/documents/archive", headers=free_auth_headers)
    assert archive_response.status_code == 200
    assert archive_response.json()["documents"] == []

    upload_response = client.post(
        "/api/v1/documents/upload",
        headers=free_auth_headers,
        data={"title": "Documento locale"},
        files={"file": ("locale.pdf", _pdf_bytes(["Test"]), "application/pdf")},
    )
    assert upload_response.status_code == 402
    assert upload_response.json()["detail"]["code"] == "feature_locked"
    assert upload_response.json()["detail"]["feature_code"] == "cloud_document_storage"


def test_downgraded_user_can_still_read_existing_cloud_documents(client, free_auth_headers):
    activation_response = client.post(
        "/api/v1/billing/dev/activate",
        headers=free_auth_headers,
        json={"plan_code": "ai_plus_yearly"},
    )
    assert activation_response.status_code == 200

    upload_response = client.post(
        "/api/v1/documents/upload",
        headers=free_auth_headers,
        data={"title": "Documento cloud storico"},
        files={
            "file": (
                "storico.pdf",
                _pdf_bytes(["Documento cloud storico"]),
                "application/pdf",
            )
        },
    )
    assert upload_response.status_code == 201
    document_id = upload_response.json()["id"]

    cancel_response = client.post(
        "/api/v1/billing/dev/cancel",
        headers=free_auth_headers,
    )
    assert cancel_response.status_code == 200

    list_response = client.get("/api/v1/documents", headers=free_auth_headers)
    assert list_response.status_code == 200
    assert [item["id"] for item in list_response.json()] == [document_id]

    detail_response = client.get(
        f"/api/v1/documents/{document_id}",
        headers=free_auth_headers,
    )
    assert detail_response.status_code == 200
    assert detail_response.json()["id"] == document_id

    status_response = client.put(
        f"/api/v1/documents/{document_id}/status",
        headers=free_auth_headers,
        json={"context_status": "old"},
    )
    assert status_response.status_code == 402
    assert status_response.json()["detail"]["feature_code"] == "cloud_document_storage"

    process_response = client.post(
        f"/api/v1/documents/{document_id}/process",
        headers=free_auth_headers,
    )
    assert process_response.status_code == 402
    assert process_response.json()["detail"]["feature_code"] == "cloud_document_storage"


def test_document_upload_process_and_viewer_url(client, auth_headers):
    pdf_content = _pdf_bytes(
        [
            "Esami del sangue",
            "Glucosio 95 mg/dL 70-99",
            "Creatinina 1.4 mg/dL 0.7-1.2",
        ]
    )

    upload_response = client.post(
        "/api/v1/documents/upload",
        headers=auth_headers,
        data={"title": "Esami marzo", "source": "Laboratorio locale"},
        files={"file": ("esami-lab.pdf", pdf_content, "application/pdf")},
    )

    assert upload_response.status_code == 201
    upload_body = upload_response.json()
    assert upload_body["parsed_status"] == "pending"
    assert upload_body["file_signature_valid"] is True
    assert upload_body["scan_status"] == "skipped"
    assert len(upload_body["content_sha256"]) == 64
    document_id = upload_body["id"]

    process_response = client.post(
        f"/api/v1/documents/{document_id}/process",
        headers=auth_headers,
    )
    assert process_response.status_code == 200
    detail = process_response.json()["document"]
    assert detail["parsed_status"] == "parsed"
    assert detail["document_type"] == "lab_report"
    assert len(detail["lab_panels"]) == 1
    assert len(detail["lab_panels"][0]["results"]) >= 2
    assert detail["viewer_url"].startswith("/api/v1/documents/")

    viewer_response = client.get(detail["viewer_url"])
    assert viewer_response.status_code == 200
    assert viewer_response.headers["content-type"].startswith("application/pdf")

    timeline_response = client.get("/api/v1/timeline", headers=auth_headers)
    assert timeline_response.status_code == 200
    titles = [event["title"] for event in timeline_response.json()]
    assert any("Documento caricato" in title for title in titles)
    assert any("Referto laboratorio" in title for title in titles)


def test_document_can_be_marked_old_and_deleted(client, auth_headers):
    pdf_content = _pdf_bytes(
        [
            "Esami del sangue",
            "Glucosio 95 mg/dL 70-99",
        ]
    )

    upload_response = client.post(
        "/api/v1/documents/upload",
        headers=auth_headers,
        data={"title": "Esami da archiviare"},
        files={"file": ("esami-old.pdf", pdf_content, "application/pdf")},
    )
    assert upload_response.status_code == 201
    document_id = upload_response.json()["id"]
    assert upload_response.json()["context_status"] == "active"

    update_response = client.put(
        f"/api/v1/documents/{document_id}/status",
        headers=auth_headers,
        json={"context_status": "old"},
    )
    assert update_response.status_code == 200
    detail = update_response.json()["document"]
    assert detail["context_status"] == "old"

    detail_response = client.get(f"/api/v1/documents/{document_id}", headers=auth_headers)
    assert detail_response.status_code == 200
    assert detail_response.json()["context_status"] == "old"

    delete_response = client.delete(f"/api/v1/documents/{document_id}", headers=auth_headers)
    assert delete_response.status_code == 204

    deleted_detail = client.get(f"/api/v1/documents/{document_id}", headers=auth_headers)
    assert deleted_detail.status_code == 404


def test_document_upload_processes_multiline_lab_pdf(client, auth_headers):
    pdf_content = _pdf_bytes(
        [
            "Referto di laboratorio - Ematochimica e Biochimica",
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
            "Creatinina",
            "2.82",
            "mg/dL",
            "0.70 - 1.20",
            "H",
            "AST (GOT)",
            "198",
            "U/L",
            "< 40",
            "H",
        ]
    )

    upload_response = client.post(
        "/api/v1/documents/upload",
        headers=auth_headers,
        data={"title": "Esami tabellari marzo", "source": "Laboratorio locale"},
        files={"file": ("esami-tabellari.pdf", pdf_content, "application/pdf")},
    )

    assert upload_response.status_code == 201
    document_id = upload_response.json()["id"]

    process_response = client.post(
        f"/api/v1/documents/{document_id}/process",
        headers=auth_headers,
    )

    assert process_response.status_code == 200
    detail = process_response.json()["document"]
    assert detail["parsed_status"] == "parsed"
    assert detail["document_type"] == "lab_report"
    assert len(detail["lab_panels"]) == 1
    results = detail["lab_panels"][0]["results"]
    assert len(results) == 3
    results_by_name = {result["analyte_name"]: result for result in results}
    assert results_by_name["Emoglobina"]["abnormal_flag"] is True
    assert results_by_name["AST (GOT)"]["ref_max"] == 40.0


def test_image_document_falls_back_to_ocr_pending(client, auth_headers):
    upload_response = client.post(
        "/api/v1/documents/upload",
        headers=auth_headers,
        data={"title": "Referto scansione"},
        files={"file": ("scan.png", _png_bytes(), "image/png")},
    )
    assert upload_response.status_code == 201
    document_id = upload_response.json()["id"]

    process_response = client.post(
        f"/api/v1/documents/{document_id}/process",
        headers=auth_headers,
    )
    assert process_response.status_code == 200
    detail = process_response.json()["document"]
    assert detail["parsed_status"] == "ocr_pending"
    assert "OCR completo" in detail["processing_error"]


def test_document_manual_review_builds_structured_lab_data(client, auth_headers):
    upload_response = client.post(
        "/api/v1/documents/upload",
        headers=auth_headers,
        data={"title": "Referto da revisionare"},
        files={"file": ("scan.png", _png_bytes(), "image/png")},
    )
    assert upload_response.status_code == 201
    document_id = upload_response.json()["id"]

    process_response = client.post(
        f"/api/v1/documents/{document_id}/process",
        headers=auth_headers,
    )
    assert process_response.status_code == 200
    assert process_response.json()["document"]["parsed_status"] == "ocr_pending"

    review_response = client.post(
        f"/api/v1/documents/{document_id}/review",
        headers=auth_headers,
        json={
            "title": "Esami corretti marzo",
            "document_type": "lab_report",
            "ocr_text": "Esami del sangue\nGlucosio 102 mg/dL 70-99",
            "lab_panel": {
                "panel_name": "Esami del sangue",
                "results": [
                    {
                        "analyte_name": "Glucosio",
                        "value": "102",
                        "unit": "mg/dL",
                        "ref_min": 70,
                        "ref_max": 99,
                    }
                ],
            },
        },
    )

    assert review_response.status_code == 200
    detail = review_response.json()["document"]
    assert detail["title"] == "Esami corretti marzo"
    assert detail["document_type"] == "lab_report"
    assert detail["parsed_status"] == "reviewed"
    assert detail["classification_confidence"] == 1.0
    assert detail["parsing_confidence"] == 1.0
    assert detail["processing_error"] is None
    assert detail["lab_panels"][0]["results"][0]["analyte_name"] == "Glucosio"
    assert detail["lab_panels"][0]["results"][0]["abnormal_flag"] is True

    timeline_response = client.get("/api/v1/timeline", headers=auth_headers)
    titles = [event["title"] for event in timeline_response.json()]
    assert any("Referto laboratorio revisionato" in title for title in titles)


def test_document_manual_review_rejects_incomplete_lab_payload(client, auth_headers):
    upload_response = client.post(
        "/api/v1/documents/upload",
        headers=auth_headers,
        data={"title": "Referto incompleto"},
        files={"file": ("scan.png", _png_bytes(), "image/png")},
    )
    assert upload_response.status_code == 201
    document_id = upload_response.json()["id"]

    process_response = client.post(
        f"/api/v1/documents/{document_id}/process",
        headers=auth_headers,
    )
    assert process_response.status_code == 200

    review_response = client.post(
        f"/api/v1/documents/{document_id}/review",
        headers=auth_headers,
        json={"document_type": "lab_report"},
    )

    assert review_response.status_code == 422
    assert "structured results" in review_response.json()["detail"]


def test_document_upload_rejects_unsupported_type(client, auth_headers):
    upload_response = client.post(
        "/api/v1/documents/upload",
        headers=auth_headers,
        data={"title": "File non valido"},
        files={"file": ("note.txt", b"hello", "text/plain")},
    )
    assert upload_response.status_code == 415


def test_document_upload_rejects_mime_signature_mismatch(client, auth_headers):
    upload_response = client.post(
        "/api/v1/documents/upload",
        headers=auth_headers,
        data={"title": "PNG finto"},
        files={"file": ("fake.png", b"plain-text", "image/png")},
    )

    assert upload_response.status_code == 415
    assert "signature" in upload_response.json()["detail"].lower()


def test_document_archive_supports_folders_and_move(client, auth_headers):
    folder_response = client.post(
        "/api/v1/documents/folders",
        headers=auth_headers,
        json={"name": "Esami 2026"},
    )
    assert folder_response.status_code == 201
    folder = folder_response.json()

    upload_response = client.post(
        "/api/v1/documents/upload",
        headers=auth_headers,
        data={"title": "Esami aprile", "folder_id": folder["id"]},
        files={
            "file": (
                "esami-aprile.pdf",
                _pdf_bytes(["Esami del sangue", "Glucosio 92 mg/dL 70-99"]),
                "application/pdf",
            )
        },
    )
    assert upload_response.status_code == 201
    document = upload_response.json()
    assert document["folder_id"] == folder["id"]
    assert document["folder_name"] == "Esami 2026"

    archive_root = client.get("/api/v1/documents/archive", headers=auth_headers)
    assert archive_root.status_code == 200
    assert archive_root.json()["folders"][0]["name"] == "Esami 2026"
    assert archive_root.json()["documents"] == []

    archive_folder = client.get(
        f"/api/v1/documents/archive?folder_id={folder['id']}",
        headers=auth_headers,
    )
    assert archive_folder.status_code == 200
    assert archive_folder.json()["current_folder"]["name"] == "Esami 2026"
    assert archive_folder.json()["documents"][0]["title"] == "Esami aprile"

    move_response = client.post(
        f"/api/v1/documents/{document['id']}/move",
        headers=auth_headers,
        json={"folder_id": None},
    )
    assert move_response.status_code == 200
    assert move_response.json()["document"]["folder_id"] is None

    archive_root_after_move = client.get("/api/v1/documents/archive", headers=auth_headers)
    assert archive_root_after_move.status_code == 200
    assert archive_root_after_move.json()["documents"][0]["title"] == "Esami aprile"


def test_document_archive_search_returns_matches_across_folders(client, auth_headers):
    lab_folder_response = client.post(
        "/api/v1/documents/folders",
        headers=auth_headers,
        json={"name": "Laboratorio"},
    )
    imaging_folder_response = client.post(
        "/api/v1/documents/folders",
        headers=auth_headers,
        json={"name": "Imaging"},
    )
    assert lab_folder_response.status_code == 201
    assert imaging_folder_response.status_code == 201

    upload_lab = client.post(
        "/api/v1/documents/upload",
        headers=auth_headers,
        data={
            "title": "Creatinina aprile",
            "folder_id": lab_folder_response.json()["id"],
        },
        files={
            "file": (
                "creatinina.pdf",
                _pdf_bytes(["Creatinina 1.4 mg/dL 0.7-1.2"]),
                "application/pdf",
            )
        },
    )
    upload_imaging = client.post(
        "/api/v1/documents/upload",
        headers=auth_headers,
        data={
            "title": "RM addome",
            "folder_id": imaging_folder_response.json()["id"],
        },
        files={
            "file": (
                "rm-addome.pdf",
                _pdf_bytes(["Referto RM addome"]),
                "application/pdf",
            )
        },
    )
    assert upload_lab.status_code == 201
    assert upload_imaging.status_code == 201

    process_response = client.post(
        f"/api/v1/documents/{upload_lab.json()['id']}/process",
        headers=auth_headers,
    )
    assert process_response.status_code == 200

    search_response = client.get(
        "/api/v1/documents/archive?query=creatinina",
        headers=auth_headers,
    )
    assert search_response.status_code == 200
    body = search_response.json()
    assert body["is_search"] is True
    assert len(body["documents"]) == 1
    assert body["documents"][0]["title"] == "Creatinina aprile"


def test_document_query_returns_answer_with_citations(client, auth_headers, monkeypatch):
    from app.ai.document_rag_provider import (
        DocumentAnswerResult,
        DocumentRerankItem,
    )
    from app.services import document_rag_service

    class _FakeAnswerProvider:
        provider_name = "regolo_ai"
        model_name = "qwen3-8b"

        def answer_question(self, *, question, context_blocks):
            return DocumentAnswerResult(
                answer="Nei documenti caricati risulta una creatinina elevata [1]. Questa risposta non sostituisce il medico.",
                provider_name=self.provider_name,
                model_name=self.model_name,
                embedding_model_name="qwen3-embedding-8b",
                reranker_model_name="qwen3-reranker-4b",
            )

    class _FakeEmbeddingProvider:
        provider_name = "regolo_ai"
        model_name = "qwen3-embedding-8b"

        def embed_texts(self, texts):
            return [[1.0, 0.0] for _ in texts]

    class _FakeRerankProvider:
        provider_name = "regolo_ai"
        model_name = "qwen3-reranker-4b"

        def rerank(self, *, query, documents, top_n):
            return [
                DocumentRerankItem(index=index, score=1.0 - (index * 0.1))
                for index in range(min(len(documents), top_n))
            ]

    monkeypatch.setattr(
        document_rag_service,
        "build_document_answer_provider",
        lambda settings: _FakeAnswerProvider(),
    )
    monkeypatch.setattr(
        document_rag_service,
        "build_document_embedding_provider",
        lambda settings: _FakeEmbeddingProvider(),
    )
    monkeypatch.setattr(
        document_rag_service,
        "build_document_rerank_provider",
        lambda settings: _FakeRerankProvider(),
    )

    upload_response = client.post(
        "/api/v1/documents/upload",
        headers=auth_headers,
        data={"title": "Esami renali"},
        files={
            "file": (
                "esami-renali.pdf",
                _pdf_bytes(
                    [
                        "Esami del sangue",
                        "Creatinina 1.4 mg/dL 0.7-1.2",
                        "Azotemia 52 mg/dL 18-55",
                    ]
                ),
                "application/pdf",
            )
        },
    )
    assert upload_response.status_code == 201
    document_id = upload_response.json()["id"]

    process_response = client.post(
        f"/api/v1/documents/{document_id}/process",
        headers=auth_headers,
    )
    assert process_response.status_code == 200

    reindex_response = client.post("/api/v1/documents/reindex", headers=auth_headers)
    assert reindex_response.status_code == 200
    assert reindex_response.json()["queued_documents"] >= 1

    query_response = client.post(
        "/api/v1/documents/query",
        headers=auth_headers,
        json={"question": "Cosa mostrano gli esami renali recenti?"},
    )
    assert query_response.status_code == 200
    body = query_response.json()
    assert "creatinina" in body["answer"].lower()
    assert body["provider_name"] == "regolo_ai"
    assert body["model_name"] == "qwen3-8b"
    assert body["embedding_model_name"] == "qwen3-embedding-8b"
    assert body["reranker_model_name"] == "qwen3-reranker-4b"
    assert body["citations"]
    assert body["citations"][0]["document_id"] == document_id
    assert body["citations"][0]["viewer_url"].startswith("/api/v1/documents/")
