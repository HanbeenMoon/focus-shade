# Contributing

For a bug report, include the app and macOS versions and the shortest steps you know to reproduce it. If the issue depends on more than one display, describe how the displays are arranged. Use sample windows when attaching an image or recording, and remove personal information from logs and attachments.

For a proposed change, explain what a user will be able to do and how you verified it. Window placement, click handling, and AppKit controls should be checked on macOS.

## Run the checks

```sh
check_dir=$(mktemp -d)
swiftc ShadeGeometry.swift tests/GeometryChecks.swift -o "$check_dir/geometry-checks"
"$check_dir/geometry-checks"
```

Use the [build instructions](README.md#build) to verify the app bundle. Keep local preferences, credentials, backups, and build output outside Git.
