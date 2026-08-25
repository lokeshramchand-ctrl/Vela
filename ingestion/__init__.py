"""Ingestion module for multi-source financial data.

This module handles ingestion of financial data from multiple sources:
- GPay (Google Pay statement exports)
- Bank statements (PDFs, CSVs)
- Synthetic data (for testing and evaluation)

All sources are normalized to CanonicalFinancialRecords for reconciliation."""

from .bank_statement_service import BankStatementRecord, BankStatementService
from .synthetic_data_generator import SyntheticDataConfig, SyntheticDataGenerator

__all__ = [
    "BankStatementRecord",
    "BankStatementService",
    "SyntheticDataConfig",
    "SyntheticDataGenerator",
]
