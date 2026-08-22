from fastapi import Query


class PaginationParams:
    """Shared page/page_size query params - one convention, defined once,
    for every list endpoint (GET /statements, GET /statements/{id}/transactions)
    instead of duplicating page-math per router."""

    def __init__(
        self,
        page: int = Query(1, ge=1, description="1-indexed page number"),
        page_size: int = Query(20, ge=1, le=100, description="Items per page (max 100)"),
    ):
        self.page = page
        self.page_size = page_size

    @property
    def skip(self) -> int:
        return (self.page - 1) * self.page_size


def resolve_sort_order(sort_order: str) -> int:
    """'asc' -> 1, anything else (including the default 'desc') -> -1."""
    return 1 if sort_order.lower() == "asc" else -1


def total_pages(total: int, page_size: int) -> int:
    if page_size <= 0:
        return 0
    return (total + page_size - 1) // page_size
