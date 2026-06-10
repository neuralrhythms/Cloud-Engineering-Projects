################################################################################
# Amazon Fraud Detector - Variables
################################################################################

resource "aws_frauddetector_variable" "ip_address" {
  name          = "ip_address"
  data_type     = "STRING"
  data_source   = "EVENT"
  default_value = "0.0.0.0"
  variable_type = "IP_ADDRESS"

  tags = var.tags
}

resource "aws_frauddetector_variable" "user_agent" {
  name          = "user_agent"
  data_type     = "STRING"
  data_source   = "EVENT"
  default_value = "unknown"
  variable_type = "USERAGENT"

  tags = var.tags
}

resource "aws_frauddetector_variable" "email_address" {
  name          = "email_address"
  data_type     = "STRING"
  data_source   = "EVENT"
  default_value = "unknown@example.com"
  variable_type = "EMAIL_ADDRESS"

  tags = var.tags
}

################################################################################
# Entity Type
################################################################################

resource "aws_frauddetector_entity_type" "customer" {
  name = "${var.name_prefix}_customer"

  tags = var.tags
}

################################################################################
# Labels
################################################################################

resource "aws_frauddetector_label" "fraud" {
  name = "${var.name_prefix}_fraud"

  tags = var.tags
}

resource "aws_frauddetector_label" "legit" {
  name = "${var.name_prefix}_legit"

  tags = var.tags
}

################################################################################
# Outcomes
################################################################################

resource "aws_frauddetector_outcome" "block_transaction" {
  name = "${var.name_prefix}_block_transaction"

  tags = var.tags
}

resource "aws_frauddetector_outcome" "review_transaction" {
  name = "${var.name_prefix}_review_transaction"

  tags = var.tags
}

resource "aws_frauddetector_outcome" "approve_transaction" {
  name = "${var.name_prefix}_approve_transaction"

  tags = var.tags
}

################################################################################
# Event Type
################################################################################

resource "aws_frauddetector_event_type" "ato_check" {
  name = "${var.name_prefix}_ato_check"

  event_variables {
    name = aws_frauddetector_variable.ip_address.name
  }

  event_variables {
    name = aws_frauddetector_variable.user_agent.name
  }

  event_variables {
    name = aws_frauddetector_variable.email_address.name
  }

  entity_types {
    name = aws_frauddetector_entity_type.customer.name
  }

  labels {
    name = aws_frauddetector_label.fraud.name
  }

  labels {
    name = aws_frauddetector_label.legit.name
  }

  tags = var.tags
}

################################################################################
# Detector
################################################################################

resource "aws_frauddetector_detector" "ato_detector" {
  name            = "${var.name_prefix}-ato-detector"
  event_type_name = aws_frauddetector_event_type.ato_check.name

  rule {
    detector_id  = "${var.name_prefix}-ato-detector"
    rule_id      = "${var.name_prefix}-high-risk-rule"
    rule_version = "1"
    expression   = "$ip_address != '0.0.0.0'"
    language     = "DETECTORPL"
    outcomes     = [aws_frauddetector_outcome.block_transaction.name]
  }

  rule {
    detector_id  = "${var.name_prefix}-ato-detector"
    rule_id      = "${var.name_prefix}-medium-risk-rule"
    rule_version = "1"
    expression   = "$email_address != 'unknown@example.com'"
    language     = "DETECTORPL"
    outcomes     = [aws_frauddetector_outcome.review_transaction.name]
  }

  rule {
    detector_id  = "${var.name_prefix}-ato-detector"
    rule_id      = "${var.name_prefix}-low-risk-rule"
    rule_version = "1"
    expression   = "$user_agent != 'unknown'"
    language     = "DETECTORPL"
    outcomes     = [aws_frauddetector_outcome.approve_transaction.name]
  }

  tags = var.tags
}
