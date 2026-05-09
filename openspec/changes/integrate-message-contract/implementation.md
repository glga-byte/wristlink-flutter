## Implementation Notes

- Adopted contract submodule revision:
  `2fa431fdc31f665f41e389adca708ddf89eade47`.
- The parent Flutter repository pins `contract/` to that revision for the v1
  phone-to-watch message envelope, acknowledgement schema, metadata, and
  fixtures.
- The v1 Dart implementation mirrors `contract/protocol/v1/metadata.json` for
  the 1024 UTF-8 JSON byte envelope budget and acknowledgement requirements.
