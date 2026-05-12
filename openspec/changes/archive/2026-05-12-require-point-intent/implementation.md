## Implementation Notes

- Adopted contract submodule revision:
  `0324a3dcaaba9d580723a7e845b312084c6c2343`
- The parent Flutter repository pins `contract/` to that revision for the
  point-intent v1 contract update.
- No native Android or iOS Garmin send adapter was changed. The current send
  boundary remains Dart-side validation in `MethodChannelGarminSendGateway`,
  which passes normalized `message.toJson()` maps over the Platform Channel.
