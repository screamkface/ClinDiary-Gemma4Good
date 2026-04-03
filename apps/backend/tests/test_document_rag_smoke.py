from app import document_rag_smoke


def test_document_rag_smoke_runs_embedding_profile(monkeypatch, capsys):
    class _FakeEmbeddingProvider:
        provider_name = "gemma"
        model_name = "embeddinggemma"

        def embed_texts(self, texts):
            return [
                [1.0, 0.0, 0.0],
                [0.9, 0.0, 0.0],
                [0.1, 0.2, 0.0],
                [0.0, 0.0, 1.0],
            ]

    monkeypatch.setattr(
        document_rag_smoke,
        "build_document_embedding_provider",
        lambda settings: _FakeEmbeddingProvider(),
    )

    exit_code = document_rag_smoke.main(["--profile", "embeddinggemma"])

    assert exit_code == 0
    output = capsys.readouterr().out
    assert "provider=gemma" in output
    assert "model=embeddinggemma" in output
    assert "embedding_dimensions=3" in output


def test_document_rag_smoke_requires_external_provider(monkeypatch, capsys):
    class _FakeEmbeddingProvider:
        provider_name = "rule_based"
        model_name = None

        def embed_texts(self, texts):
            return [None for _ in texts]

    monkeypatch.setattr(
        document_rag_smoke,
        "build_document_embedding_provider",
        lambda settings: _FakeEmbeddingProvider(),
    )

    exit_code = document_rag_smoke.main(["--require-external-provider"])

    assert exit_code == 4
    output = capsys.readouterr().out
    assert "external_provider_required=true" in output


def test_document_rag_smoke_runs_answer_profile(monkeypatch, capsys):
    class _FakeAnswerProvider:
        provider_name = "gemma"
        model_name = "gemma-local"

        def answer_question(self, *, question, context_blocks):
            class _Result:
                answer = "Sintesi prudente [1]. Non sostituisce il medico."

            return _Result()

    monkeypatch.setattr(
        document_rag_smoke,
        "build_document_answer_provider",
        lambda settings: _FakeAnswerProvider(),
    )

    exit_code = document_rag_smoke.main(["--mode", "answer", "--profile", "default"])

    assert exit_code == 0
    output = capsys.readouterr().out
    assert "provider=gemma" in output
    assert "model=gemma-local" in output
    assert "answer_preview=" in output
