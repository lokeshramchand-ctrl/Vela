# Wave 6: Finance Controller Experience

## What Changed?

Wave 6 builds the **Controller**, a dedicated operations interface for finance teams to monitor and manage transaction reconciliation. This is the first user-facing dashboard that operationalizes the confidence routing system from Wave 5.

### The Controller Dashboard

The controller provides a birds-eye view of reconciliation health:

```
VELA FINANCE CONTROLLER

Records processed       250
Matched                 221
Exceptions               21
Unresolved                8

Match rate              88.4%
Amount reconciled       ₹4,82,300

[Review Exceptions]
```

### Exception Review Workflow

When a user taps "Review Exceptions", they enter a detail view:

```
EXCEPTION

Source A                         Source B
Amazon                           Amazon Pay
₹2,499                          ₹2,599
Aug 10                          Aug 10

Issue:
Amount mismatch

Confidence:
98%

Reason:
Merchant and date align,
but amounts differ by ₹100.

[Keep Exception] [Resolve]
```

## Key Principles

### 1. Finance Operations First
- Numbers are large and scannable
- Actions are explicit (Resolve vs Keep Exception)
- Confidence scores guide decision-making
- No generic "AI dashboard" aesthetics

### 2. Human-in-the-Loop
- Exceptions are never auto-merged without review
- Confidence scores (from Wave 5) inform operator trust
- Clear reasoning for why a transaction is flagged
- Quick resolution paths (<5 taps per exception)

### 3. Observable Reconciliation
- Match rate at a glance
- Exception counts by type (amount, merchant, date)
- Amount reconciled as the north star metric
- Real-time updates as operators resolve exceptions

## Architecture

### Frontend (Flutter)

```
features/controller/
├── domain/
│   ├── reconciliation_stats.dart      # Data model
│   └── exception.dart                 # Exception model
├── presentation/
│   ├── controller_controller.dart     # State management (Riverpod)
│   ├── controller_screen.dart         # Dashboard
│   ├── exceptions_list_screen.dart    # List of all exceptions
│   ├── exception_detail_screen.dart   # Detail + action view
│   └── mock_controller_data.dart      # Dev/demo data
```

The controller uses Riverpod for state management and integrates with the existing Flutter architecture.

### Backend (FastAPI)

```
routers/controller.py
├── GET /api/controller/stats          # Reconciliation statistics
├── GET /api/controller/exceptions     # All pending exceptions
└── POST /api/controller/exceptions/{id}/resolve  # Resolve exception
```

All endpoints are secured with the standard API key + JWT authentication.

## Example Usage

### Viewing the Controller

```dart
// Navigator routes to controller screen
context.push('/shell/controller');

// Which loads reconciliation stats + exceptions
final state = ref.watch(controllerProvider);
// state.stats: ReconciliationStats
// state.exceptions: List<TransactionException>
// state.isLoading, state.error
```

### Reviewing an Exception

```dart
// User taps an exception in the list
context.push(
  '/controller/exceptions/${exception.id}',
  extra: exception,
);

// Lands on detail screen with source comparison
// User can Resolve or Keep Exception
```

### Resolving an Exception

```dart
// User taps Resolve
await ref.read(controllerProvider.notifier).resolveException(
  exceptionId: 'abc123',
  approved: true,  // merge the transaction
);

// Exception is removed from list
// Stats are updated (exceptions -1, matched +1, etc.)
```

## Development Mode

For Flutter development, mock data is used (defined in `mock_controller_data.dart`):

```dart
// Automatic when kDebugMode == true
final stats = await MockControllerRepository.fetchStats();
// Returns: 250 records, 221 matched, 21 exceptions, 88.4% match rate
```

To use real APIs in development:
1. Set `kDebugMode = false` in controller_controller.dart
2. Ensure backend is running (`python -m uvicorn app:app --reload`)
3. Set correct API base URL in app config

## Testing

### Unit Tests (Backend)

```bash
# Test controller endpoints
python -m pytest routers/test_controller.py -v
```

### Manual Testing (Frontend)

1. Run Flutter: `flutter run`
2. Navigate to Controller tab in bottom nav
3. Mock data loads automatically
4. Tap exception to view details
5. Tap Resolve or Keep Exception
6. Exception is removed from list

## Confidence Wall Integration

Wave 6 operationalizes Wave 5's confidence routing:

- **HIGH_CONFIDENCE (>90%)**: Auto-matched in backend, rarely appear in exceptions
- **MEDIUM_CONFIDENCE (65-90%)**: Appear in exceptions, typically easy to verify
- **LOW_CONFIDENCE (<65%)**: Appear in exceptions, require careful review + domain knowledge

The confidence score on each exception helps operators prioritize (high confidence = quick tap to resolve).

## Files Changed

| File | Purpose |
|------|---------|
| `frontend/lib/features/controller/` | New Flutter feature |
| `routers/controller.py` | New backend API |
| `app.py` | Mount controller router |
| `frontend/lib/core/routing/app_router.dart` | Add controller routes |
| `frontend/lib/core/routing/app_shell.dart` | Add controller nav tab |

## Git History

```
commit [wave6-latest]  Wave 6: Add controller API endpoints
commit [wave6-prev]    Wave 6: Add mock data and development mode
commit [wave6-start]   Wave 6: Add controller domain models and state
```

Branch: `wave6` (ready to PR to `master`)

## Next Steps

1. **Backend Integration**: Wire exceptions to real Wave 5 confidence router output
2. **Database Storage**: Persist resolved exceptions for audit trails
3. **Real-Time Updates**: WebSocket or Server-Sent Events for live stats
4. **Analytics**: Track operator resolution patterns and confidence calibration
5. **Wave 7**: Feedback loop that improves confidence walls based on exceptions

---

**See `docs/WAVE6.md` for complete specification and architecture decisions.**

