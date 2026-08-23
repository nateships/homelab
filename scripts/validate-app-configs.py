#!/usr/bin/env python3
"""Validate kubernetes/apps/*/config.yaml against the ApplicationSet schema.

One malformed config file wedges the ApplicationSet generator for every
app, and goTemplate's missingkey=error only catches absent keys, not
misspelled ones. Fail the PR instead.
"""

import glob
import os
import sys

import yaml

ALLOWED_KEYS = {
    "name",
    "namespace",
    "sources",
    "ignoreDifferences",
    "autosync",
    "namespaceLabels",
}

errors = []


def err(path: str, msg: str) -> None:
    errors.append(f"{path}: {msg}")


files = sorted(glob.glob("kubernetes/apps/*/config.yaml"))
if not files:
    sys.exit("no kubernetes/apps/*/config.yaml files found")

for path in files:
    with open(path) as f:
        try:
            cfg = yaml.safe_load(f)
        except yaml.YAMLError as e:
            err(path, f"invalid YAML: {e}")
            continue

    if not isinstance(cfg, dict):
        err(path, "top level must be a mapping")
        continue

    for key in ("name", "namespace"):
        if not isinstance(cfg.get(key), str) or not cfg.get(key):
            err(path, f"'{key}' must be a non-empty string")

    unknown = set(cfg) - ALLOWED_KEYS
    if unknown:
        err(path, f"unknown keys {sorted(unknown)} (allowed: {sorted(ALLOWED_KEYS)})")

    sources = cfg.get("sources")
    if sources is None:
        # Default source: the app's own directory, rendered by its
        # kustomization.
        if not os.path.exists(os.path.join(os.path.dirname(path), "kustomization.yaml")):
            err(path, "no 'sources' and no kustomization.yaml beside it")
        continue

    if not isinstance(sources, list) or not sources:
        err(path, "'sources' must be a non-empty list")
        continue

    for i, src in enumerate(sources):
        if not isinstance(src, dict):
            err(path, f"sources[{i}] must be a mapping")
            continue
        # A source is a helm chart (chart + repoURL), a git path, or a
        # bare ref for valueFiles. Local-repo sources may omit repoURL
        # and targetRevision (the templatePatch defaults them).
        if "chart" in src:
            if "repoURL" not in src:
                err(path, f"sources[{i}] has 'chart' but no 'repoURL'")
        elif "path" not in src and "ref" not in src:
            err(path, f"sources[{i}] needs 'chart', 'path', or 'ref'")

    if "autosync" in cfg and not isinstance(cfg["autosync"], bool):
        err(path, "'autosync' must be a boolean")

    labels = cfg.get("namespaceLabels")
    if labels is not None and (
        not isinstance(labels, dict)
        or not all(isinstance(v, str) for v in labels.values())
    ):
        err(path, "'namespaceLabels' must be a mapping of string values")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)

print(f"{len(files)} app config(s) valid")
