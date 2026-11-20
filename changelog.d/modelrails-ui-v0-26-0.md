### Security

- modelrails_ui is pinned to v0.26.0, which requires ViewComponent 4.14 or later (GHSA-8qw7-6phv-7q6p); this app already runs 4.24, so no component changes.
- markdowndocs moves to 0.12.0, which requires rails-html-sanitizer 1.7.2 and loofah 2.25.3 for their XSS fixes; this app already runs both.
