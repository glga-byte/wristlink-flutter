## Implementation Notes

- Adopted contract submodule revision:
  `d9c696bb85384fa82b8e9a4dfee361ad4be1c05a`.
- The parent Flutter repository pins `contract/` to that revision for the v1
  phone-to-watch message envelope, acknowledgement schema, metadata, and
  fixtures, plus shared agent guidance for Flutter and Connect IQ consuming
  repositories.
- The v1 Dart implementation mirrors `contract/protocol/v1/metadata.json` for
  the 1024 UTF-8 JSON byte envelope budget and acknowledgement requirements.
