class ClinDiaryError(Exception):
    """Base application error."""


class AuthenticationError(ClinDiaryError):
    """Raised when authentication fails."""


class AuthorizationError(ClinDiaryError):
    """Raised when a user attempts to access another patient's resources."""


class ResourceNotFoundError(ClinDiaryError):
    """Raised when an expected resource does not exist."""

