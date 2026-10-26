# Security policy

## Supported versions

Only the latest release receives security fixes.

| Version | Supported |
| --- | --- |
| Latest release (see [Releases](../../releases)) | Yes |
| Older releases | No |

## Reporting a vulnerability

Please do **not** open a public issue for a security problem.

Report it privately through GitHub: go to the repository's **Security** tab and choose **Report a vulnerability**. Include:

- what you found and which version or commit it affects,
- steps or a sample file that reproduce it,
- what you think the impact is.

You can expect an acknowledgement within a few days. Shapeshift is maintained by one person in their spare time, so a fix may take longer, but I will keep you updated and credit you in the release notes if you wish.

## What is in scope

Shapeshift processes files you give it, so the areas that matter most are:

- **File handling:** a crafted file that makes the app overwrite or modify an original, write outside the intended folder, or crash.
- **Helper processes:** unsafe use of `ffmpeg` or other external tools, including argument or path injection through file names.
- **Redaction:** the PDF Redact tool is meant to remove the covered text from the output. A case where the text can still be recovered is a security bug.
- **Permissions:** the app asks for Input Monitoring so it can show the menu while you drag. Any use of that permission beyond detecting the trigger key and drag is a bug.

Shapeshift does not upload files, collect telemetry or make network requests of its own.

## Out of scope

- Vulnerabilities in ffmpeg or macOS itself (report those upstream).
- The app being ad-hoc signed and not notarized. This is documented in the README.
