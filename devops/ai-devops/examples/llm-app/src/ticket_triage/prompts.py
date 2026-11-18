"""Prompts as code: publish the prompt file to Langfuse, and move labels.

  python -m ticket_triage.prompts publish --label staging
  python -m ticket_triage.prompts promote --from staging --to production
  python -m ticket_triage.prompts promote --version 7 --to production

The file in Git is the source of truth and is reviewed like code. A pipeline
publishes it as a new version labelled "staging", the evaluation runs against
that version, and only then does "production" move to it. Rolling back is
moving the label back.
"""

from __future__ import annotations

import argparse
import os

from langfuse import get_client

from ticket_triage.app import PROMPT_NAME, local_prompt


def publish(label: str) -> int:
    commit = os.environ.get("CI_COMMIT_SHORT_SHA", "local")
    created = get_client().create_prompt(
        name=PROMPT_NAME,
        prompt=local_prompt(),
        labels=[label],
        type="text",
        commit_message=f"published from {commit}",
    )
    return int(created.version)


def promote(from_label: str, to_label: str, version: int | None = None) -> int:
    """Point `to_label` at `version`, or at the version `from_label` points to."""
    lf = get_client()
    if version is None:
        version = int(lf.get_prompt(PROMPT_NAME, label=from_label, cache_ttl_seconds=0).version)
    lf.api.prompt_version.update(name=PROMPT_NAME, version=version, new_labels=[to_label])
    return version


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    p_pub = sub.add_parser("publish")
    p_pub.add_argument("--label", default="staging")
    p_pub.add_argument("--dotenv", help="also write PROMPT_VERSION=<n> to this file")
    p_pro = sub.add_parser("promote")
    p_pro.add_argument("--from", dest="from_label", default="staging")
    p_pro.add_argument("--to", dest="to_label", default="production")
    p_pro.add_argument("--version", type=int, help="promote this exact version instead")
    args = parser.parse_args()
    if args.command == "publish":
        version = publish(args.label)
        print(f"{PROMPT_NAME} version {version} is {args.label}")
        if args.dotenv:
            with open(args.dotenv, "w", encoding="utf-8") as out:
                out.write(f"PROMPT_VERSION={version}\n")
    else:
        version = promote(args.from_label, args.to_label, args.version)
        print(f"{PROMPT_NAME} {args.to_label} -> version {version}")
    get_client().flush()


if __name__ == "__main__":
    main()
