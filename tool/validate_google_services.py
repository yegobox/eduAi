#!/usr/bin/env python3
"""Check that android/app/google-services.json is the config for this app.

CI writes this file from a repo secret, and the usual failure is the wrong file
being pasted into the secret (firebase.json, a service-account key, a web app
config). Those parse as JSON but leave Firebase silently dead at runtime, so
fail loudly here instead.
"""
import json
import sys

PACKAGE = "rw.akili.app"
PATH = "android/app/google-services.json"

HINT = f"""
The secret must contain the *Android app* config downloaded from
Firebase console -> Project settings -> Your apps -> {PACKAGE} -> google-services.json
It is the file with a top-level "client" array. It is NOT firebase.json,
NOT a service-account key, and NOT the web/iOS config.
"""


def fail(message):
    sys.exit(f"::error::{message}\n{HINT}")


def main():
    try:
        with open(PATH) as handle:
            config = json.load(handle)
    except FileNotFoundError:
        fail(f"{PATH} was not written.")
    except json.JSONDecodeError as error:
        fail(f"{PATH} is not valid JSON: {error}")

    if "client" not in config:
        keys = ", ".join(sorted(config)) or "(none)"
        fail(f"{PATH} has no 'client' array. Top-level keys are: {keys}.")

    packages = [
        client.get("client_info", {}).get("android_client_info", {}).get("package_name")
        for client in config["client"]
    ]
    if PACKAGE not in packages:
        fail(f"{PATH} has no client for {PACKAGE}. It declares: {packages}.")

    project = config.get("project_info", {}).get("project_id", "?")
    print(f"google-services.json OK - {PACKAGE} in Firebase project {project}")


if __name__ == "__main__":
    main()
