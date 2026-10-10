#!/usr/bin/env bash
# Installs the Terraform toolchain on Ubuntu 22.04 / 24.04 (amd64).
# Usage: chmod +x scripts/install-tools-ubuntu.sh && ./scripts/install-tools-ubuntu.sh
set -euo pipefail

TFDOCS_VERSION="v0.19.0"
CONFTEST_VERSION="0.56.0"

# Fail early on unsupported architecture (download URLs below are amd64-only)
if [ "$(dpkg --print-architecture)" != "amd64" ]; then
  echo "ERROR: this script supports amd64 only." >&2
  exit 1
fi

# Private temp dir, cleaned up on exit
TMPDIR_INSTALL="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_INSTALL"' EXIT

echo "==> Base packages"
sudo apt-get update
sudo apt-get install -y curl wget unzip gnupg lsb-release \
  software-properties-common git make jq python3 pipx

echo "==> Terraform (official HashiCorp apt repo)"
wget -qO- https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor --yes \
      -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
sudo apt-get update
sudo apt-get install -y terraform

echo "==> TFLint"
# The old install_linux.sh script was removed from the TFLint repo (404),
# so download the release zip and verify its checksum instead.
TFLINT_BASE="https://github.com/terraform-linters/tflint/releases/latest/download"
curl -fsSLo "${TMPDIR_INSTALL}/tflint_linux_amd64.zip" "${TFLINT_BASE}/tflint_linux_amd64.zip"
curl -fsSLo "${TMPDIR_INSTALL}/tflint-checksums.txt" "${TFLINT_BASE}/checksums.txt"
(cd "${TMPDIR_INSTALL}" && sha256sum --ignore-missing -c tflint-checksums.txt)
unzip -q -o "${TMPDIR_INSTALL}/tflint_linux_amd64.zip" -d "${TMPDIR_INSTALL}/tflint-bin"
sudo install -c -m 0755 "${TMPDIR_INSTALL}/tflint-bin/tflint" /usr/local/bin/tflint

echo "==> Trivy (security scanner)"
wget -qO- https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | sudo gpg --dearmor --yes -o /usr/share/keyrings/trivy.gpg
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
  | sudo tee /etc/apt/sources.list.d/trivy.list >/dev/null
sudo apt-get update
sudo apt-get install -y trivy

echo "==> Checkov + pre-commit (via pipx)"
pipx ensurepath
export PATH="$HOME/.local/bin:$PATH"   # make pipx tools usable in this script run
pipx install checkov
pipx install pre-commit

echo "==> terraform-docs"
TFDOCS_URL="https://terraform-docs.io/dl/${TFDOCS_VERSION}"
TFDOCS_FILE="terraform-docs-${TFDOCS_VERSION}-linux-amd64.tar.gz"
curl -fsSLo "${TMPDIR_INSTALL}/terraform-docs.tar.gz" "${TFDOCS_URL}/${TFDOCS_FILE}"
tar -xzf "${TMPDIR_INSTALL}/terraform-docs.tar.gz" -C "${TMPDIR_INSTALL}" terraform-docs
sudo install -m 0755 "${TMPDIR_INSTALL}/terraform-docs" /usr/local/bin/terraform-docs

echo "==> Conftest (OPA policy checks)"
CONFTEST_URL="https://github.com/open-policy-agent/conftest/releases/download"
CONFTEST_FILE="conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz"
curl -fsSL "${CONFTEST_URL}/v${CONFTEST_VERSION}/${CONFTEST_FILE}" \
  | tar -xz -C "${TMPDIR_INSTALL}" conftest
sudo install -m 0755 "${TMPDIR_INSTALL}/conftest" /usr/local/bin/conftest

echo "==> AWS CLI v2"
if ! command -v aws >/dev/null 2>&1; then
  curl -fsSLo "${TMPDIR_INSTALL}/awscliv2.zip" \
    "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
  unzip -q -o "${TMPDIR_INSTALL}/awscliv2.zip" -d "${TMPDIR_INSTALL}"
  sudo "${TMPDIR_INSTALL}/aws/install"
fi

echo "==> Versions"
terraform -version
tflint --version
# sed instead of head: head closes the pipe early and, with pipefail, can kill the script (SIGPIPE)
trivy --version 2>&1 | sed -n '1p'
terraform-docs --version
conftest --version
aws --version
checkov --version
pre-commit --version
echo "Open a new shell (or run: source ~/.bashrc) so pipx tools are on PATH."
