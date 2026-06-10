# Development Environment Configuration
# Reduced costs: smaller instances, optional components disabled

environment  = "dev"
aws_region   = "us-east-1"
project_name = "fraud-detection"

vpc_cidr = "10.0.0.0/16"

# Neptune - smaller instance for dev
neptune_instance_class = "db.t3.medium"
enable_neptune         = false  # Disable in dev to save cost

# OpenSearch - smaller for dev
opensearch_instance_type  = "t3.small.search"
opensearch_instance_count = 1
enable_opensearch         = false  # Disable in dev to save cost

# WAF
enable_waf = true

# Notifications
notification_email = ""
notification_phone = ""
