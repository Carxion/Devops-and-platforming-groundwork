"""Allow running as `python -m healthcheck`."""

from healthcheck.cli import main

raise SystemExit(main())
