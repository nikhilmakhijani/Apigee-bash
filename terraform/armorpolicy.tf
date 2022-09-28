/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

locals {
  rules = merge(var.security_team_rules, var.pdg_rules)
}

resource "google_compute_security_policy" "this" {
  count   = var.create ? 1 : 0
  name    = var.policy_name
  project = var.project_id

  # ---------------------------------------------------------------
  #    IP address allowlist and denylist rules
  # ---------------------------------------------------------------
  dynamic "rule" {
    for_each = var.ipaddress_rules
    content {
      action   = rule.value.action
      priority = rule.value.priority
      match {
        versioned_expr = rule.value.versioned_expr
        config {
          src_ip_ranges = rule.value.src_ip_ranges
        }
      }
      description = rule.value.description
    }
  }

  # ---------------------------------------------------------------
  #   Preconfigured rules for XSS, SQLi, LFI, RFI, and RCE
  # ---------------------------------------------------------------
  dynamic "rule" {
    for_each = local.rules
    content {
      action   = rule.value.action
      priority = rule.value.priority
      preview  = rule.value.preview
      match {
        expr {
          expression = rule.value.expression
        }
      }

      dynamic "rate_limit_options" {
        for_each = rule.value.action == "throttle" || rule.value.action == "rate_based_ban" ? [true] : []
        content {
          ban_duration_sec    = lookup(rule.value.rate_limit_options, "ban_duration_sec", null)
          conform_action      = rule.value.rate_limit_options["conform_action"]
          enforce_on_key      = rule.value.rate_limit_options["enforce_on_key"]
          enforce_on_key_name = rule.value.rate_limit_options["enforce_on_key_name"]
          exceed_action       = rule.value.rate_limit_options["exceed_action"]
          rate_limit_threshold {
            count        = rule.value.rate_limit_options["count"]
            interval_sec = rule.value.rate_limit_options["interval_sec"]
          }
          dynamic "ban_threshold" {
            for_each = rule.value.action == "rate_based_ban" ? [true] : []
            content {
              count        = rule.value.rate_limit_options["ban_count"]
              interval_sec = rule.value.rate_limit_options["ban_interval_sec"]
            }
          }
        }
      }
      description = rule.value.description
    }
  }
}

````````

variable "create" {
  description = "Whether to create the resources from this module."
  type        = bool
  default     = true
}

variable "project_id" {
  description = "Project id where cloud armor policy will be created."
  type        = string
}

variable "policy_name" {
  description = "Name of the policy."
  type        = string
}

variable "ipaddress_rules" {
  description = "List of IP address allowlist and denylist rules within a security policy."
  type = map(object({
    action         = string
    priority       = string
    versioned_expr = string
    src_ip_ranges  = list(string)
    description    = string
  }))
}

variable "security_team_rules" {
  description = "List of rules defined by the secuirty team."
  type = map(object({
    action             = string
    priority           = string
    expression         = string
    description        = string
    preview            = bool
    rate_limit_options = map(string)
  }))
}

variable "pdg_rules" {
  description = "List of rules defined by PDGs."
  type = map(object({
    action             = string
    priority           = string
    expression         = string
    description        = string
    preview            = bool
    rate_limit_options = map(string)
  }))
  default = {}
}

``````````


