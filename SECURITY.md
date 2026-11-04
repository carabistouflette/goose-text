# Security

This is an experimental UTF-8 library with no stable release yet. Only the
latest published commit is maintained. Validation and decoding are strict and
allocation-free; encoding grows caller-owned storage. Applications must bound
input reads, output growth and total work, and handle decode failures before
advancing offsets. Invalid UTF-8 is never replaced silently.

Please report suspected vulnerabilities privately using GitHub's **Report a
vulnerability** option in this repository's Security tab when available. If that
option is unavailable, contact the repository owner privately through their
GitHub profile before sharing sensitive details. Do not include credentials or
private data in a report, and avoid public exploit details before a fix exists.
Include the full source/compiler revisions, platform, minimal reproducer and
expected versus actual behavior. No response-time guarantee is offered.
