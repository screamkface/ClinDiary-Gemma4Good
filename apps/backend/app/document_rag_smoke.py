from __future__ import annotations

import argparse
import math
import sys

from app.ai.document_rag_provider import (
    build_document_answer_provider,
    build_document_embedding_provider,
)
from app.core.config import get_settings


def _sample_texts(profile: str) -> tuple[str, list[str]]:
    if profile == "embeddinggemma":
        question = "Cosa emerge sugli esami renali recenti?"
        passages = [
            "Referto laboratorio marzo: Creatinina 1.4 mg/dL, azotemia 52 mg/dL.",
            "Referto laboratorio febbraio: Emoglobina 12.8 g/dL, ferritina 35 ng/mL.",
            "Ecografia addome: reni nei limiti, nessuna dilatazione pielocaliceale.",
        ]
        return question, passages

    question = "Com e andata la pressione negli ultimi giorni?"
    passages = [
        "Pressione domiciliare: 128/80 mmHg con FC 68 bpm.",
        "Peso corporeo: 69.4 kg, variazione +0.8 kg nel mese.",
        "Saturazione periferica: 97%, minima 95% nel periodo.",
    ]
    return question, passages


def _cosine_similarity(left: list[float] | None, right: list[float] | None) -> float:
    if not left or not right or len(left) != len(right):
        return 0.0
    numerator = sum(a * b for a, b in zip(left, right, strict=False))
    left_norm = math.sqrt(sum(value * value for value in left))
    right_norm = math.sqrt(sum(value * value for value in right))
    if left_norm == 0 or right_norm == 0:
        return 0.0
    return numerator / (left_norm * right_norm)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="ClinDiary document retrieval smoke check")
    parser.add_argument(
        "--mode",
        choices=("embedding", "answer"),
        default="embedding",
        help="Modalita smoke: retrieval embeddings o answer generation documentale",
    )
    parser.add_argument(
        "--profile",
        choices=("default", "embeddinggemma"),
        default="default",
        help="Profilo smoke predefinito per il retrieval embeddings",
    )
    parser.add_argument(
        "--require-local-runtime",
        action="store_true",
        help="Fallisce se il runtime locale documentale ricade sul fallback rule_based",
    )
    args = parser.parse_args(argv)

    question, passages = _sample_texts(args.profile)
    if args.mode == "answer":
        provider = build_document_answer_provider(get_settings())
        context_blocks = [
            f"[{index}] Documento: Smoke | Tipo: note\n{passage}"
            for index, passage in enumerate(passages, start=1)
        ]
        try:
            answer = provider.answer_question(
                question=question,
                context_blocks=context_blocks,
            )
        except Exception as exc:
            print(f"answer_error={exc}")
            return 3

        print(f"provider={provider.provider_name}")
        print(f"model={provider.model_name}")
        print(f"answer_preview={answer.answer[:160]}")
        if args.require_local_runtime and provider.provider_name == "rule_based":
            print("local_runtime_required=true")
            return 4
        if not answer.answer.strip():
            print("answer_missing=true")
            return 5
        return 0

    provider = build_document_embedding_provider(get_settings())
    payload = [question, *passages]

    try:
        embeddings = provider.embed_texts(payload)
    except Exception as exc:
        print(f"embedding_error={exc}")
        return 3

    print(f"provider={provider.provider_name}")
    print(f"model={provider.model_name}")
    print(f"items={len(embeddings)}")

    if args.require_local_runtime and provider.provider_name == "rule_based":
        print("local_runtime_required=true")
        return 4

    if not embeddings or embeddings[0] is None:
        print("query_embedding_missing=true")
        return 5

    query_embedding = embeddings[0]
    dimensions = len(query_embedding)
    print(f"embedding_dimensions={dimensions}")

    ranked = sorted(
        (
            (index, _cosine_similarity(query_embedding, embedding), passage)
            for index, (embedding, passage) in enumerate(zip(embeddings[1:], passages, strict=False), start=1)
            if embedding is not None
        ),
        key=lambda item: item[1],
        reverse=True,
    )
    for index, score, passage in ranked:
        print(f"candidate_{index}_score={score:.4f}")
        print(f"candidate_{index}_preview={passage[:120]}")

    if not ranked:
        print("retrieval_candidates_missing=true")
        return 6

    return 0


if __name__ == "__main__":
    sys.exit(main())
