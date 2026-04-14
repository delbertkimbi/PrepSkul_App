# SkulMate Generation Error Code Contract

This contract standardizes generation/image-processing failures so client UX is deterministic and debuggable.

## 1) Goal

Replace free-text error parsing with stable machine-readable codes.

Client behavior should be driven by:

- `error_code`
- optional `retryable`
- optional `retry_after_seconds`
- optional `request_id`

## 2) API Error Shape

For non-2xx responses from generation endpoint:

```json
{
  "error": "Human readable summary",
  "details": "Optional technical detail",
  "error_code": "IMAGE_PROVIDER_UNAVAILABLE",
  "retryable": true,
  "retry_after_seconds": 120,
  "request_id": "gen_2026_04_14_abcd1234"
}
```

Accepted key aliases during migration:

- `error_code` (preferred)
- `errorCode`
- `code`

## 3) Canonical Error Codes

### Image/OCR pipeline

- `IMAGE_PROVIDER_UNAVAILABLE`
- `IMAGE_PROCESSING_UNAVAILABLE`
- `OCR_TEXT_EXTRACTION_FAILED`
- `IMAGE_TEXT_NOT_READABLE`
- `IMAGE_PROVIDER_QUOTA_EXCEEDED`

### Generation pipeline

- `GENERATION_QUOTA_EXCEEDED`
- `GENERATION_INPUT_INVALID`
- `GENERATION_PAYLOAD_TOO_LARGE`
- `GENERATION_SERVICE_UNAVAILABLE`

### Auth / permissions

- `AUTH_REQUIRED`
- `AUTH_INVALID`
- `ACCESS_DENIED`

## 4) HTTP Status Mapping

- `400`: invalid input / OCR not readable / payload issues
- `401|403`: auth/access issues
- `402`: quota/plan limits
- `429`: rate limiting
- `503`: temporary upstream provider outage
- `500`: internal server error

## 5) Client UX Mapping

### Temporary image provider outage

Codes:

- `IMAGE_PROVIDER_UNAVAILABLE`
- `IMAGE_PROCESSING_UNAVAILABLE`

UX:

- Message: *"Image processing is temporarily unavailable right now..."*
- CTA: retry later or use text/doc upload
- honor `retry_after_seconds` when present

### OCR extraction failure

Codes:

- `OCR_TEXT_EXTRACTION_FAILED`
- `IMAGE_TEXT_NOT_READABLE`

UX:

- Message: *"We couldn't read text from this file..."*
- CTA: clearer image, text manual input, DOCX/TXT/PDF fallback

### Quota/credit limit

Codes:

- `IMAGE_PROVIDER_QUOTA_EXCEEDED`
- `GENERATION_QUOTA_EXCEEDED`

UX:

- Message: temporary limited service / upgrade or retry

## 6) Logging Contract (Server)

Every failure response should include a `request_id`; server logs must include:

- `request_id`
- `user_id` (if authenticated)
- `error_code`
- upstream provider name
- upstream status/error
- latency_ms

This enables direct triage from client report to server trace.

## 7) Migration Plan

1. Backend returns both text + `error_code`.
2. Client prioritizes `error_code`; falls back to text matching.
3. After adoption, reduce text heuristic usage.

## 8) External Jobs Note

If generation workers run from external schedulers/queues, they must preserve the same `error_code` set and response envelope so mobile behavior remains consistent across execution paths.

