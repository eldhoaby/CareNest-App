# Security Policy

## Supported Versions

The following versions of CareNest are currently being supported with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take the security of CareNest very seriously. If you discover a vulnerability in CareNest, please help us by disclosing it responsibly.

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them by sending an email to the project maintainers.
You should receive a response within 48 hours. If the issue is confirmed, we will release a patch as soon as possible.

### What to include in your report
- A description of the vulnerability.
- Steps to reproduce the issue.
- Potential impact and any suggested mitigations.

### Best Practices Enforced
- CareNest utilizes Firebase Security Rules to restrict database access.
- API keys must not be hardcoded in the repository (use `.env`).
- All traffic is strictly enforced over HTTPS/WSS.
- User passwords are encrypted via Firebase Authentication.
