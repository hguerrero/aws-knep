#!/bin/bash

# Kong Native Event Proxy ECS Deployment Script - Service-Based Structure
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists terraform; then
        print_error "Terraform is not installed. Please install Terraform >= 1.0"
        exit 1
    fi
    
    if ! command_exists aws; then
        print_error "AWS CLI is not installed. Please install AWS CLI"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS credentials not configured or SSO session expired."
        print_status "If using SSO, try: aws sso login"
        print_status "If using regular credentials, try: aws configure"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    terraform init
    print_success "Terraform initialized"
}

# Function to validate Terraform configuration
validate_terraform() {
    print_status "Validating Terraform configuration..."
    terraform validate
    print_success "Terraform configuration is valid"
}

# Function to plan deployment
plan_deployment() {
    print_status "Planning deployment..."
    terraform plan -out=tfplan
    print_success "Deployment plan created"
}

# Function to apply deployment
apply_deployment() {
    print_status "Applying deployment..."
    terraform apply tfplan
    print_success "Deployment completed successfully"
}

# Function to show outputs
show_outputs() {
    print_status "Deployment outputs:"
    echo ""
    terraform output
    echo ""
    
    # Get the Kong KNEP URL
    KONG_URL=$(terraform output -raw kong_knep_url 2>/dev/null || echo "Not available")
    if [ "$KONG_URL" != "Not available" ]; then
        print_success "Kong Native Event Proxy is accessible at: $KONG_URL"
        print_status "You can test the deployment with: curl $KONG_URL/status"
    fi
}

# Function to destroy deployment
destroy_deployment() {
    print_warning "This will destroy all resources created by this Terraform configuration."
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        print_status "Destroying deployment..."
        terraform destroy -auto-approve
        print_success "Deployment destroyed"
    else
        print_status "Destroy cancelled"
    fi
}

# Function to show help
show_help() {
    echo "Kong Native Event Proxy ECS Deployment Script - Service-Based Structure"
    echo ""
    echo "Usage: $0 [ENVIRONMENT] [COMMAND]"
    echo ""
    echo "Environments:"
    echo "  dev       - Development environment"
    echo "  staging   - Staging environment"
    echo "  prod      - Production environment"
    echo ""
    echo "Commands:"
    echo "  deploy    - Deploy Kong Native Event Proxy to ECS (default)"
    echo "  plan      - Show deployment plan without applying"
    echo "  destroy   - Destroy the deployment"
    echo "  output    - Show deployment outputs"
    echo "  help      - Show this help message"
    echo ""
    echo "Prerequisites:"
    echo "  - Terraform >= 1.0"
    echo "  - AWS CLI configured with appropriate credentials"
    echo "  - terraform.tfvars file in the environment directory"
    echo ""
    echo "Examples:"
    echo "  $0 dev deploy      # Deploy to development"
    echo "  $0 staging plan    # Plan staging deployment"
    echo "  $0 prod destroy    # Destroy production"
    echo "  $0 dev output      # Show dev outputs"
}

# Main function
main() {
    local environment=${1:-dev}
    local command=${2:-deploy}

    # Validate environment
    if [[ ! "$environment" =~ ^(dev|staging|prod)$ ]]; then
        print_error "Invalid environment: $environment"
        print_status "Valid environments: dev, staging, prod"
        show_help
        exit 1
    fi

    # Set working directory
    local work_dir="services/kong-knep/$environment"
    if [ ! -d "$work_dir" ]; then
        print_error "Environment directory not found: $work_dir"
        exit 1
    fi

    print_status "Working with environment: $environment"
    print_status "Working directory: $work_dir"
    cd "$work_dir"

    case $command in
        deploy)
            check_prerequisites
            
            # Check if terraform.tfvars exists
            if [ ! -f "terraform.tfvars" ]; then
                print_warning "terraform.tfvars not found. Creating from example..."
                if [ -f "terraform.tfvars.example" ]; then
                    cp terraform.tfvars.example terraform.tfvars
                    print_warning "Please edit terraform.tfvars with your configuration before proceeding."
                    print_status "Opening terraform.tfvars for editing..."
                    ${EDITOR:-nano} terraform.tfvars
                else
                    print_error "terraform.tfvars.example not found. Please create terraform.tfvars manually."
                    exit 1
                fi
            fi
            
            init_terraform
            validate_terraform
            plan_deployment
            
            echo ""
            print_warning "Review the plan above. Do you want to proceed with the deployment?"
            read -p "Continue? (yes/no): " confirm
            
            if [ "$confirm" = "yes" ]; then
                apply_deployment
                show_outputs
            else
                print_status "Deployment cancelled"
                rm -f tfplan
            fi
            ;;
        plan)
            check_prerequisites
            init_terraform
            validate_terraform
            terraform plan
            ;;
        destroy)
            check_prerequisites
            destroy_deployment
            ;;
        output)
            show_outputs
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
