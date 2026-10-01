# Security Policy

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

Email **support@thinkany.ai** with:

- a description of the issue and its impact,
- steps to reproduce (proof-of-concept if possible),
- any suggested fix.

We aim to acknowledge reports within a few business days and will keep you updated as we
investigate and ship a fix. Responsible disclosure is appreciated — please give us a reasonable
window to release a patch before any public disclosure.

## Scope notes

- An input method sees everything typed while it's active. TypeAny processes keystrokes locally;
  text leaves the machine only for features the user turns on — translate mode and LLM clean-up
  (sent to the user's configured provider) and Apple's speech recognition. Reports of text being
  sent elsewhere, or while those features are off, are in scope.
- Voice input records only while the voice key is held. Recording without that, or keeping audio
  afterwards, is in scope.
- Model API keys are entered by the user and stored locally in TypeAny's preferences. They are
  never committed to this repository or sent anywhere other than the provider the user configured.
- Release builds are signed with a Developer ID and notarized; signing material lives only in
  the maintainers' keychains and GitHub Actions secrets.
