#!/usr/bin/env python3

"""
tg.py - Terragrunt wrapper script

Author: Mark Statkus
Description:
    Interactive or CLI-driven Terragrunt runner for managing Terraform modules
    across multiple AWS accounts and environments.

Usage (CLI):
    python tg.py -a nonprod -e dev -f rds -c plan

Usage (Wizard):
    python tg.py  # Guided prompt mode

Requirements:
    - Python 3.6+
    - terragrunt and terraform in PATH
    - questionary (auto-installed if missing)
"""

import os
import argparse
import shutil
import subprocess
import requests
import re
from pathlib import Path
import sys
from utils.aws_profile import find_profile_by_account
from utils.aws_auth import ensure_aws_profile
try:
  import questionary
  from questionary import Choice
except ImportError:
  print("📦 Installing 'questionary'...")
  subprocess.check_call([sys.executable, "-m", "pip", "install", "questionary"])
  import questionary
  from questionary import Choice

IGNORED = {"templates", "__pycache__", ".DS_Store", "README.md", "artifacts"}

def safe_version_key(v):
    numeric_part = re.match(r"^\d+(\.\d+)*", v)
    if numeric_part:
        return [int(x) for x in numeric_part.group(0).split(".")]
    return [0, 0, 0]

def get_local_version(bin_name):
    try:
        output = subprocess.check_output([bin_name, "-version"], stderr=subprocess.STDOUT).decode()
        return output.splitlines()[0].split(" ")[-1].strip("v")
    except Exception:
        return None

def get_latest_github_release(repo):
    try:
        res = requests.get(f"https://api.github.com/repos/{repo}/releases/latest", timeout=5)
        if res.status_code == 200:
            return res.json()["tag_name"].lstrip("v")
    except Exception:
        return None

def check_version_updates():
    print("🔍 Checking CLI tool versions...\n")

    for tool, repo in {
        "terraform": "hashicorp/terraform",
        "terragrunt": "gruntwork-io/terragrunt"
    }.items():
        local = get_local_version(tool)
        latest = get_latest_github_release(repo)
        if local and latest:
            if local != latest:
                print(f"⬆️  {tool} is outdated: {local} → {latest}")
            else:
                print(f"✅ {tool} is up-to-date: {local}")
        else:
            print(f"⚠️  Could not determine {tool} version.")

# Providers
def get_latest_provider_version(namespace, name):
    """Query Terraform Registry for latest stable provider version"""
    try:
        url = f"https://registry.terraform.io/v1/providers/{namespace}/{name}/versions"
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            versions = response.json().get("versions", [])
            stable_versions = [
                v["version"]
                for v in versions
                if not any(suffix in v["version"] for suffix in ["-alpha", "-beta", "-rc", "-pre"])
            ]
            if stable_versions:
                return sorted(stable_versions, key=safe_version_key)[-1]
            else:
                print(f"⚠️  No stable versions found for {namespace}/{name}")
        else:
            print(f"⚠️  Failed to fetch provider: {namespace}/{name} ({response.status_code})")
    except Exception as e:
        print(f"⚠️  Error fetching provider version for {namespace}/{name}: {e}")
    return None

def extract_required_provider_blocks(content):
    """Return a list of full required_providers blocks using brace counting"""
    blocks = []
    start = content.find("required_providers")
    while start != -1:
        brace_count = 0
        in_block = False
        end = start
        for i, c in enumerate(content[start:], start=start):
            if c == "{":
                brace_count += 1
                in_block = True
            elif c == "}":
                brace_count -= 1
                if in_block and brace_count == 0:
                    blocks.append(content[start:i+1])
                    break
        start = content.find("required_providers", i + 1)
    return blocks

def check_provider_updates(base_path="terraform/modules"):
    print("\n📦 Scanning Terraform providers with declared and latest versions...\n")
    for tf in Path(base_path).rglob("*.tf"):
        with open(tf) as f:
            content = f.read()

            if "required_providers" not in content:
                continue

            blocks = extract_required_provider_blocks(content)
            if not blocks:
                continue

            print(f"📁 {tf.relative_to(base_path)}")

            for block in blocks:
                matches = re.findall(
                    r'(\w+)\s*=\s*{[^}]*source\s*=\s*"([^"]+)"[^}]*version\s*=\s*"([^"]+)"',
                    block, re.DOTALL
                )
                for name, source, version in matches:
                    latest = None
                    try:
                        namespace, module_name = source.split("/")
                        latest = get_latest_provider_version(namespace, module_name)
                    except ValueError:
                        latest = "❌ Invalid source"
                    print(f"   {name}:")
                    print(f"     source:  {source}")
                    print(f"     current: {version}")
                    print(f"     latest:  {latest}")

# Modules
def extract_module_sources(base_path="terraform/modules"):
    modules = []
    for tf in Path(base_path).rglob("*.tf"):
        with open(tf) as f:
            content = f.read()
            matches = re.findall(
                r'source\s*=\s*"([^"]+)"\s*[\n\s]*version\s*=\s*"([^"]+)"',
                content,
                re.MULTILINE
            )
            modules.extend(matches)
    return modules

def get_latest_module_version(source):
    try:
        namespace, name, provider = source.split("/")
        url = f"https://registry.terraform.io/v1/modules/{namespace}/{name}/{provider}/versions"
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            versions = response.json().get("modules", [{}])[0].get("versions", [])
            stable_versions = [
                v["version"]
                for v in versions
                if not any(suffix in v["version"] for suffix in ["-beta", "-alpha", "-rc"])
            ]
            return sorted(stable_versions, key=lambda s: list(map(int, s.split("."))))[-1] if stable_versions else None
    except Exception as e:
        print(f"⚠️  Error fetching version for {source}: {e}")
    return None

def check_module_updates():
    print("\n📦 Checking Terraform module versions...")
    modules = extract_module_sources()
    seen = set()
    
    for source, current_version in modules:
        if source in seen:
            continue
        seen.add(source)
        
        parts = source.split("/")
        if len(parts) != 3:
            # Skip non-module sources like hashicorp/aws (providers)
            continue

        latest_version = get_latest_module_version(source)
        if latest_version:
            if latest_version != current_version:
                print(f"⬆️  {source}\n   Current: {current_version}\n   Latest:  {latest_version}")
            else:
                print(f"✅ {source} is up-to-date ({current_version})")
        else:
            print(f"⚠️  Could not fetch latest version for {source}")

def run_terragrunt(path, command, run_all, non_interactive, parallelism, dry_run=False, log_level="info", extra_args=None):
  cmd = ["terragrunt"]
  if non_interactive:
    cmd.append("--terragrunt-non-interactive")
  if parallelism:
    cmd.append(f"--terragrunt-parallelism={parallelism}")

  if run_all:
    cmd += ["run-all", command]
  else:
    cmd += [command]

  if log_level:
    cmd.append(f"--log-level={log_level}")

  if extra_args:
    cmd.extend([arg for arg in extra_args if arg.strip()])

  print(f"\n👉 Running: {' '.join(cmd)} in {path}")

  if dry_run:
    print(f"🧪 Dry run: Would execute '{' '.join(cmd)}' in {path}")
    return

  try:
    subprocess.run(cmd, cwd=path, check=True)
  except subprocess.CalledProcessError as e:
    print(f"❌ Terragrunt command failed with exit code {e.returncode}")
    sys.exit(e.returncode)

def check_tools_installed():
  errors = []
  if not shutil.which("terragrunt"):
    errors.append("❌ Error: 'terragrunt' is not installed or not found in PATH.")
  if not shutil.which("terraform"):
    errors.append("❌ Error: 'terraform' is not installed or not found in PATH.")

  if errors:
    for error in errors:
      print(error)
    print("Please install the missing tools and ensure they are available in your PATH.")
    sys.exit(1)

def choose_stack():
    base_path = Path(__file__).resolve().parent.parent / "accounts"

    # Step 1: Choose account
    accounts = sorted([f.name for f in base_path.iterdir() if f.is_dir() and f.name not in IGNORED])
    account = questionary.select("Select an account:", choices=accounts).ask()
    if not account:
        return None

    # Step 2: Choose environment under that account
    account_path = base_path / account
    envs = sorted([f.name for f in account_path.iterdir() if f.is_dir() and f.name not in IGNORED])
    env = questionary.select("Select an environment:", choices=envs).ask()
    if not env:
        return None

    # Step 3: Choose stack/module under that env
    env_path = account_path / env
    stacks = sorted([
      f.name for f in env_path.iterdir()
      if (
        f.is_dir()
        and f.name not in IGNORED
        and ((f / "common.hcl").exists() or (f / "terragrunt.hcl").exists())
      )
    ])
    if not stacks:
      print(f"❌ No valid stacks found in {account}/{env}")
      return None

    stack = questionary.select("Select a stack/module:", choices=stacks).ask()
    if not stack:
        return None

    return env_path / stack

def can_use_default_aws_profile():
  try:
    subprocess.run(
      ["aws", "sts", "get-caller-identity"],
      stdout=subprocess.DEVNULL,
      stderr=subprocess.DEVNULL,
      check=True
    )
    return True
  except subprocess.CalledProcessError:
    return False

def main():
  used_wizard = False
  check_tools_installed()

  parser = argparse.ArgumentParser()
  parser.add_argument("-a", "--account", required=False, help="Account (e.g., nonprod, prod)")
  parser.add_argument("-e", "--env", required=False, help="Environment (e.g., dev, staging)")
  parser.add_argument("-f", "--folder", required=False, help="Specific folder/module")
  parser.add_argument("-c", "--command", help="Terraform command (init, plan, apply, destroy, etc)")
  parser.add_argument("--run-all", action="store_true", help="Use terragrunt run-all")
  parser.add_argument("--non-interactive", action="store_true", help="Run in non-interactive mode")
  parser.add_argument("--parallelism", type=int, help="Max number of parallel operations")
  parser.add_argument("--dry-run", action="store_true", help="Only show the command, don't run it")
  parser.add_argument("--log-level", default="info", choices=["trace", "debug", "info", "warn", "error"], help="Terragrunt log level (default: info)")
  parser.add_argument("--extra-args", nargs="*", help="Additional arguments to pass to terragrunt")
  parser.add_argument("--check-updates", action="store_true", help="Check if Terraform/Terragrunt and provider versions are outdated")
  args = parser.parse_args()
  
  # Check if args missing, go into wizard mode
  if not args.account or not args.env:
    print("🔍 Launching interactive stack selector...\n")
    selected_path = choose_stack()
    if not selected_path:
      sys.exit(1)

    # Extract account/env/folder from selected path
    args.account = selected_path.parents[2].name
    args.env = selected_path.parents[1].name
    args.folder = selected_path.name

    path = selected_path
    used_wizard = True
  else:
    base_path = Path(__file__).resolve().parent.parent
    path = base_path / "accounts" / args.account / args.env
    if args.folder:
      path = path / args.folder
      
  if args.check_updates:
    check_version_updates()
    check_provider_updates()
    check_module_updates()
    sys.exit(0)

  # Check if path exists
  if not path.exists():
    print(f"❌ Error: Path does not exist: {path}")
    sys.exit(1)

  # Command selection
  if not args.command:
    args.command = questionary.select(
      "Choose a Terraform command to run:",
      choices=["init", "validate", "plan", "apply", "destroy"]
    ).ask()

  if not args.command:
    print("❌ Error: No command selected.")
    sys.exit(1)

  if args.parallelism is not None and args.parallelism <= 0:
    print("❌ Error: Parallelism must be a positive integer.")
    sys.exit(1)
    
  # Auto-enable --run-all if wrapper module (no terragrunt.hcl, but submodules exist)
  if not (path / "terragrunt.hcl").exists():
    has_child_modules = any(
      (path / child).is_dir() and (path / child / "terragrunt.hcl").exists()
      for child in os.listdir(path)
    )
    if has_child_modules:
      print("ℹ️  Auto-detected wrapper module. Enabling --run-all.")
      args.run_all = True

  # Check if CI=true, then set non-interactive mode
  if os.getenv("CI", "").lower() == "true":
    args.non_interactive = True
  else:
    if used_wizard and not args.dry_run:
      args.non_interactive = questionary.select(
        "Terragrunt interaction mode?",
        choices=[
          Choice(title="Interactive (allow prompts like create S3 bucket)", value=False),
          Choice(title="Non-interactive (recommended for CI)", value=True)
        ]
      ).ask()
    else:
      args.non_interactive = False

  # Check if AWS_PROFILE is set, if not, try to find it, if CI=true, skip
  ensure_aws_profile(args.account)

  # Run the command with args
  run_terragrunt(
    path,
    args.command,
    args.run_all,
    args.non_interactive,
    args.parallelism,
    dry_run=args.dry_run,
    log_level=args.log_level,
    extra_args=args.extra_args
  )

if __name__ == "__main__":
  main()