# =============================================================================
# Environment: test
# Purpose: Root module for test environment
# Test mirrors prod configuration but with cost optimisations (single NAT, Spot).
# =============================================================================
# Follows same structure as dev/main.tf and prod/main.tf.
# Key differences from dev: On-Demand instances, multi-cluster add-ons enabled
# Key differences from prod: Single NAT, public API endpoint, shorter log retention
# =============================================================================

# TODO: Implement test environment following same pattern as dev/main.tf
# VPC CIDR: 10.1.0.0/16
# Kubernetes version: same as prod
# Capacity type: ON_DEMAND (to mirror prod behaviour)
# API endpoint: Public + Private
# NAT: Single (cost saving)
# Log retention: 30 days
