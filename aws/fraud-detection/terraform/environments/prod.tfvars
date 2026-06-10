# Production Environment Configuration
# Full deployment with all components enabled

environment  = "prod"
aws_region   = "us-east-1"
project_name = "fraud-detection"

vpc_cidr = "10.0.0.0/16"

# Neptune - production sizing
neptune_instance_class = "db.r5.large"
enable_neptune         = true

# OpenSearch - production sizing
opensearch_instance_type  = "r6g.large.search"
opensearch_instance_count = 2
enable_opensearch         = true

# WAF
enable_waf = true

# Notifications (update with actual values)
notification_email = "fraud-alerts@company.com"
notification_phone = "+1234567890"
