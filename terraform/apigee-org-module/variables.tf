variable "analytics_region" {
  description = "Analytics Region for the Apigee Organization (immutable). See https://cloud.google.com/apigee/docs/api-platform/get-started/install-cli."
  type        = string
}

variable "apigee_envgroups" {
  description = "Apigee Environment Groups."
  type = map(object({
    environments = list(string)
    hostnames    = list(string)
  }))
  default = {}
}

variable "apigee_environments" {
  description = "Apigee Environment Names."
  type        = list(string)
  default     = []
}

variable "authorized_network" {
  description = "VPC network self link (requires service network peering enabled (Used in Apigee X only)."
  type        = string
  default     = null
}

variable "database_encryption_key" {
  description = "Cloud KMS key self link (e.g. `projects/foo/locations/us/keyRings/bar/cryptoKeys/baz`) used for encrypting the data that is stored and replicated across runtime instances (immutable, used in Apigee X only)."
  type        = string
  default     = null
}

variable "description" {
  description = "Description of the Apigee Organization."
  type        = string
  default     = "Apigee Organization created by tf module"
}

variable "display_name" {
  description = "Display Name of the Apigee Organization."
  type        = string
  default     = null
}

variable "project_id" {
  description = "Project ID to host this Apigee organization (will also become the Apigee Org name)."
  type        = string
}

variable "runtime_type" {
  description = "Apigee runtime type. Must be `CLOUD` or `HYBRID`."
  type        = string
  validation {
    condition     = contains(["CLOUD", "HYBRID"], var.runtime_type)
    error_message = "Allowed values for runtime_type \"CLOUD\" or \"HYBRID\"."
  }
}
