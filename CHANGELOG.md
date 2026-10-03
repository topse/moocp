# Changelog

## 0.9.4
- moocp can check GitHub once a day for a new version and install it for you. It asks on the first start and contacts GitHub only after a yes; the installer runs visibly and the app restarts itself.
- New settings dialog behind the gear icon: the update setting and the Claude Code setup, which moved there from the puzzle icon.

## 0.9.2
- Asking for a question bank now creates one (a `qbank` activity) instead of quietly adding a category to the shared bank; a new category is confirmed with the bank it went into.
- Creating a question bank no longer reports a spurious failure, and a question bank can now be deleted like any other activity.
- STACK: a test input that is not one of the options of a dropdown or radio input is refused before the import, and a test run now names the input STACK did not accept instead of showing an empty result.
- Approvals are re-checked against Moodle before the app acts on them: if the item was renamed or moved while the dialog was waiting, nothing happens.

## 0.9.0
- initial release
