## Implementation Notes

- Contract submodule base revision at implementation time:
  `0324a3dcaaba9d580723a7e845b312084c6c2343`
- The point-intent contract changes are currently applied in the `contract/`
  submodule working tree. When the contract changes are committed, the parent
  repository PR should pin and document the resulting contract commit SHA as
  the adopted revision.
- No native Android or iOS Garmin send adapter was changed. The current send
  boundary remains Dart-side validation in `MethodChannelGarminSendGateway`,
  which passes normalized `message.toJson()` maps over the Platform Channel.
