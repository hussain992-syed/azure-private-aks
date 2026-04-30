#!/bin/bash
#==============================================================================
# Deployment Script: Blue-Green Deployment Helper
#==============================================================================
# This script helps manage blue-green deployments by:
# 1. Switching traffic between blue and green deployments
# 2. Monitoring deployment health
# 3. Rolling back if needed
#
# Usage:
#   ./scripts/deploy.sh switch-color <namespace> <release> <color>
#   ./scripts/deploy.sh status <namespace> <release>
#   ./scripts/deploy.sh rollback <namespace> <release>
#==============================================================================

set -e

NAMESPACE="${2:-production}"
RELEASE="${3:-sample-app}"
COLOR="${4:-}"
HELM_CHART_PATH="./helm-charts/sample-app"

#------------------------------------------------------------------------------
# Colors for output
#------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#------------------------------------------------------------------------------
# Helper functions
#------------------------------------------------------------------------------
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

#------------------------------------------------------------------------------
# Function: Get current active color
#------------------------------------------------------------------------------
get_active_color() {
    kubectl get service "$RELEASE" -n "$NAMESPACE" -o jsonpath='{.spec.selector.color}' 2>/dev/null || echo "unknown"
}

#------------------------------------------------------------------------------
# Function: Get deployment status
#------------------------------------------------------------------------------
get_deployment_status() {
    local color=$1
    kubectl get deployment "$RELEASE-$color" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}/{.status.replicas}' 2>/dev/null || echo "0/0"
}

#------------------------------------------------------------------------------
# Function: Switch traffic color
#------------------------------------------------------------------------------
switch_color() {
    local new_color=$1
    local current_color=$(get_active_color)
    
    if [ "$current_color" = "$new_color" ]; then
        log_warning "Color is already $new_color. No action needed."
        return 0
    fi
    
    log_info "Current active color: $current_color"
    log_info "Switching to: $new_color"
    
    # Update Helm values
    log_info "Updating Helm values..."
    helm upgrade "$RELEASE" "$HELM_CHART_PATH" \
        --namespace "$NAMESPACE" \
        --reuse-values \
        --set deployment.activeColor="$new_color" \
        --set deployment.$new_color.enabled=true \
        --set deployment.$current_color.enabled=false
    
    # Wait for service update
    log_info "Waiting for service selector update..."
    kubectl wait --for=condition=ready pod -l "app=$RELEASE,color=$new_color" -n "$NAMESPACE" --timeout=300s
    
    log_success "Traffic switched to $new_color"
}

#------------------------------------------------------------------------------
# Function: Show deployment status
#------------------------------------------------------------------------------
show_status() {
    log_info "Deployment Status for $RELEASE in $NAMESPACE"
    echo "========================================"
    
    local current_color=$(get_active_color)
    echo "Active Color: $current_color"
    echo ""
    
    echo "Blue Deployment:"
    local blue_status=$(get_deployment_status "blue")
    echo "  Replicas: $blue_status"
    kubectl get pods -l "app=$RELEASE,color=blue" -n "$NAMESPACE" --no-headers 2>/dev/null | while read line; do
        echo "  Pod: $line"
    done
    echo ""
    
    echo "Green Deployment:"
    local green_status=$(get_deployment_status "green")
    echo "  Replicas: $green_status"
    kubectl get pods -l "app=$RELEASE,color=green" -n "$NAMESPACE" --no-headers 2>/dev/null | while read line; do
        echo "  Pod: $line"
    done
    echo ""
    
    echo "Service Endpoints:"
    kubectl get endpoints "$RELEASE" -n "$NAMESPACE" -o custom-columns=ADDRESS:.subsets[*].addresses[*].ip,PORT:.subsets[*].ports[*].port
}

#------------------------------------------------------------------------------
# Function: Rollback to previous color
#------------------------------------------------------------------------------
rollback() {
    local current_color=$(get_active_color)
    local rollback_color=""
    
    if [ "$current_color" = "blue" ]; then
        rollback_color="green"
    elif [ "$current_color" = "green" ]; then
        rollback_color="blue"
    else
        log_error "Unknown current color: $current_color"
        exit 1
    fi
    
    log_warning "Rolling back from $current_color to $rollback_color"
    
    # Check if rollback color is available
    local rollback_status=$(get_deployment_status "$rollback_color")
    if [ "$rollback_status" = "0/0" ]; then
        log_error "Rollback color $rollback_color has no replicas. Cannot rollback."
        exit 1
    fi
    
    switch_color "$rollback_color"
    log_success "Rollback completed"
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------
case "${1:-}" in
    switch-color)
        if [ -z "$COLOR" ]; then
            log_error "Color argument required (blue or green)"
            echo "Usage: $0 switch-color <namespace> <release> <color>"
            exit 1
        fi
        switch_color "$COLOR"
        ;;
    status)
        show_status
        ;;
    rollback)
        rollback
        ;;
    *)
        echo "Usage: $0 {switch-color|status|rollback} [namespace] [release] [color]"
        echo ""
        echo "Commands:"
        echo "  switch-color  Switch traffic to specified color (blue or green)"
        echo "  status        Show current deployment status"
        echo "  rollback      Rollback to previous color"
        echo ""
        echo "Examples:"
        echo "  $0 switch-color production sample-app green"
        echo "  $0 status production sample-app"
        echo "  $0 rollback production sample-app"
        exit 1
        ;;
esac
