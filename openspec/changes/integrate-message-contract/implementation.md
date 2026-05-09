## Implementation Notes

- Adopted contract submodule revision:
  `679dcccd3468066beef46823791577c38536caa5`.
- The parent Flutter repository pins `contract/` to that revision for the v1
  phone-to-watch message envelope, acknowledgement schema, metadata, and
  fixtures, plus shared agent guidance for Flutter and Connect IQ consuming
  repositories.
- The v1 Dart implementation mirrors `contract/protocol/v1/metadata.json` for
  the 1024 UTF-8 JSON byte envelope budget and acknowledgement requirements.
