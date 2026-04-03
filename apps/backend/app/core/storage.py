from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import shutil

from minio import Minio
from minio.error import S3Error

from app.core.config import get_settings


settings = get_settings()


@dataclass(slots=True)
class StoredFile:
    object_key: str
    content_type: str
    size_bytes: int


class StorageService:
    def save_bytes(self, *, object_key: str, data: bytes, content_type: str) -> StoredFile:
        raise NotImplementedError

    def read_bytes(self, object_key: str) -> bytes:
        raise NotImplementedError

    def delete_bytes(self, object_key: str) -> None:
        raise NotImplementedError


class MinioStorageService(StorageService):
    def __init__(self) -> None:
        self._client = Minio(
            endpoint=settings.minio_endpoint,
            access_key=settings.minio_access_key,
            secret_key=settings.minio_secret_key,
            secure=settings.minio_secure,
        )

    def save_bytes(self, *, object_key: str, data: bytes, content_type: str) -> StoredFile:
        self._ensure_bucket()
        self._client.put_object(
            bucket_name=settings.minio_bucket,
            object_name=object_key,
            data=_BytesReader(data),
            length=len(data),
            content_type=content_type,
        )
        return StoredFile(object_key=object_key, content_type=content_type, size_bytes=len(data))

    def read_bytes(self, object_key: str) -> bytes:
        response = self._client.get_object(settings.minio_bucket, object_key)
        try:
            return response.read()
        finally:
            response.close()
            response.release_conn()

    def delete_bytes(self, object_key: str) -> None:
        self._ensure_bucket()
        try:
            self._client.remove_object(settings.minio_bucket, object_key)
        except S3Error as exc:
            if exc.code != "NoSuchKey":
                raise RuntimeError(f"MinIO delete failed: {exc}") from exc

    def _ensure_bucket(self) -> None:
        try:
            if not self._client.bucket_exists(settings.minio_bucket):
                self._client.make_bucket(settings.minio_bucket)
        except S3Error as exc:
            raise RuntimeError(f"MinIO bucket unavailable: {exc}") from exc


class LocalStorageService(StorageService):
    def __init__(self) -> None:
        self._base_path = Path(settings.local_storage_path)
        self._base_path.mkdir(parents=True, exist_ok=True)

    def save_bytes(self, *, object_key: str, data: bytes, content_type: str) -> StoredFile:
        destination = self._base_path / object_key
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        return StoredFile(object_key=object_key, content_type=content_type, size_bytes=len(data))

    def read_bytes(self, object_key: str) -> bytes:
        return (self._base_path / object_key).read_bytes()

    def delete_bytes(self, object_key: str) -> None:
        (self._base_path / object_key).unlink(missing_ok=True)


def get_storage_service() -> StorageService:
    if settings.storage_backend == "local":
        return LocalStorageService()
    return MinioStorageService()


class _BytesReader:
    def __init__(self, data: bytes) -> None:
        self._data = data
        self._offset = 0

    def read(self, size: int = -1) -> bytes:
        if size == -1:
            size = len(self._data) - self._offset
        chunk = self._data[self._offset : self._offset + size]
        self._offset += len(chunk)
        return chunk

