#!/bin/bash
# Kong Event Gateway — Deploy Script
# Deploys infrastructure/ then gateway/ in order.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status()  { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

check_prerequisites() {
    print_status "Checking prerequisites..."
    for cmd in terraform aws; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            print_error "$cmd is not installed."
            exit 1
        fi
    done
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS credentials not configured. Run 'aws configure' or set environment variables."
        exit 1
    fi
    print_success "Prerequisites OK"
}

tf_apply() {
    local dir="$1"
    local label="$2"
    print_status "=== $label ==="
    cd "$REPO_ROOT/$dir"
    if [ ! -f terraform.tfvars ]; then
        print_warning "No terraform.tfvars found in $dir — copy terraform.tfvars.example and fill in values."
        exit 1
    fi
    terraform init -upgrade
    terraform apply -auto-approve
    print_success "$label deployed"
    cd "$REPO_ROOT"
}

tf_destroy() {
    local dir="$1"
    local label="$2"
    print_status "=== Destroying $label ==="
    cd "$REPO_ROOT/$dir"
    terraform destroy -auto-approve
    print_success "$label destroyed"
    cd "$REPO_ROOT"
}

usage() {
    cat <<EOF
Usage: $0 <command>

Commands:
  deploy      Deploy infrastructure/ then gateway/
  destroy     Destroy gateway/ then infrastructure/ (reverse order)
  infra       Deploy infrastructure/ only
  gateway     Deploy gateway/ only
  outputs     Show gateway/ outputs

EOF
}

case "${1:-}" in
  deploy)
    check_prerequisites
    tf_apply "infrastructure" "Infrastructure (VPC + MSK + Security Groups)"
    tf_apply "gateway"        "Gateway (Konnect + ECS + NLB)"
    echo ""
    print_success "Kong Event Gateway deployed!"
    cd "$REPO_ROOT/gateway" && terraform output kafka_bootstrap_endpoint
    ;;
  destroy)
    check_prerequisites
    print_warning "This will destroy ALL resources. Type 'yes' to confirm:"
    read -r confirm
    [ "$confirm" = "yes" ] || { print_status "Cancelled."; exit 0; }
    tf_destroy "gateway"        "Gateway"
    tf_destroy "infrastructure" "Infrastructure"
    ;;
  infra)
    check_prerequisites
    tf_apply "infrastructure" "Infrastructure (VPC + MSK + Security Groups)"
    ;;
  gateway)
    check_prerequisites
    tf_apply "gateway" "Gateway (Konnect + ECS + NLB)"
    ;;
  outputs)
    cd "$REPO_ROOT/gateway" && terraform output
    ;;
  *)
    usage
    exit 1
    ;;
esac
