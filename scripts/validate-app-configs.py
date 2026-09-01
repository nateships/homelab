#!/usr/bin/env python3
"""Validate kubernetes/apps/*/config.yaml against the ApplicationSet schema.

One malformed config file stops Application generation for every app.
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
    "labels",
    "url",
}

CATEGORIES = {"infra", "network", "storage", "media"}
TIERS = {"edge", "public", "media", "utility"}

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

    # The appset builds the default source path and the Application name
    # from 'name', not from the file location. A mismatch deploys the
    # wrong directory or collides with another Application.
    dirname = os.path.basename(os.path.dirname(path))
    if isinstance(cfg.get("name"), str) and cfg["name"] and cfg["name"] != dirname:
        err(path, f"'name' is '{cfg['name']}' but the directory is '{dirname}'")

    if "url" in cfg and (
        not isinstance(cfg["url"], str) or not cfg["url"].startswith("https://")
    ):
        err(path, "'url' must be an https:// URL string")

    unknown = set(cfg) - ALLOWED_KEYS
    if unknown:
        err(path, f"unknown keys {sorted(unknown)} (allowed: {sorted(ALLOWED_KEYS)})")

    if "autosync" in cfg and not isinstance(cfg["autosync"], bool):
        err(path, "'autosync' must be a boolean")

    for key in ("labels", "namespaceLabels"):
        val = cfg.get(key)
        if val is not None and (
            not isinstance(val, dict)
            or not all(isinstance(v, str) for v in val.values())
        ):
            err(path, f"'{key}' must be a mapping of string values")

    # The taxonomy: every app declares a category (ArgoCD UI filtering),
    # and a tier, when set, names a known Cilium policy tier.
    category = (cfg.get("labels") or {}).get("category")
    if category not in CATEGORIES:
        err(path, f"labels.category is {category!r} (must be one of {sorted(CATEGORIES)})")
    tier = (cfg.get("namespaceLabels") or {}).get("homelab/tier")
    if tier is not None and tier not in TIERS:
        err(path, f"homelab/tier is {tier!r} (must be one of {sorted(TIERS)})")

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
            # The templatePatch default targetRevision is the branch
            # 'main', which is not a valid chart version.
            if "targetRevision" not in src:
                err(path, f"sources[{i}] has 'chart' but no 'targetRevision'")
        elif "path" not in src and "ref" not in src:
            err(path, f"sources[{i}] needs 'chart', 'path', or 'ref'")


if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)

print(f"{len(files)} app config(s) valid")
