resource "google_pubsub_topic" "topic" {
  name                       = var.topic_name
  project                    = var.project_id
  message_retention_duration = var.message_retention_duration
  labels                     = var.labels
}

----------------------------------------------

resource "google_cloud_scheduler_job" "jobs" {
  for_each = var.jobs_list
  name     = each.key
  project  = var.project_id

  pubsub_target {
    data       = base64encode(jsonencode(each.value.data))
    topic_name = google_pubsub_topic.topic.id
  }

  region = var.region

  retry_config {
    max_backoff_duration = "3600s"
    max_doublings        = "5"
    max_retry_duration   = "0s"
    min_backoff_duration = "5s"
    retry_count          = "0"
  }

  schedule  = each.value.schedule
  time_zone = each.value.time_zone
}

----------------------------------------------

output "function_id" {
  value = google_cloudfunctions_function.function.id
}

output "topic_id" {
  value = google_pubsub_topic.topic.id
} 

--------------------------------------------

data "archive_file" "zip" {
  type        = "zip"
  source_dir  = var.folder_path
  output_path = "${var.folder_path}.zip"
}

resource "google_storage_bucket_object" "file" {
  name   = "export.zip"
  source = data.archive_file.zip.output_path
  bucket = var.bucket_name
}

resource "google_cloudfunctions_function" "function" {
  available_memory_mb = var.available_memory_mb
  entry_point         = var.entry_point

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    failure_policy {
      retry = var.failure_policy_retry
    }
    resource = var.resource == "" ? google_pubsub_topic.topic.id : var.resource
  }

  ingress_settings      = var.ingress_settings
  source_archive_bucket = var.bucket_name
  source_archive_object = google_storage_bucket_object.file.name
  labels                = var.labels
  max_instances         = var.max_instances
  min_instances         = var.min_instances
  name                  = var.function_name
  project               = var.project_id
  region                = var.region
  runtime               = var.runtime
  service_account_email = var.service_account_email
  timeout               = var.timeout
}

-----------------------------------------------------------------

# ---------------------------------------------------------------
#    Common Variables
# ---------------------------------------------------------------

variable "project_id" {
  description = "Name of the project."
  type        = string
}

variable "region" {
  description = " Name of the region."
  type        = string
}

# ---------------------------------------------------------------
#    Cloud Function Variables
# ---------------------------------------------------------------

variable "function_name" {
  description = "Name of the function."
  type        = string
}

variable "runtime" {
  description = "The runtime in which the function is going to run. Eg. nodejs10, nodejs12, nodejs14, python37, python38, python39, dotnet3, go113, java11 , ruby27, etc. Check the official doc for the up-to-date list."
  type        = string
}

variable "available_memory_mb" {
  description = "Memory (in MB), available to the function. Default value is 256. Possible values include 128, 256, 512, 1024, etc."
  type        = number
  default     = 256
}

variable "entry_point" {
  description = "Name of the function that will be executed when the Google Cloud Function is triggered."
  type        = string
  default     = ""
}

variable "ingress_settings" {
  description = "String value that controls what traffic can reach the function. Allowed values are ALLOW_ALL, ALLOW_INTERNAL_AND_GCLB and ALLOW_INTERNAL_ONLY"
  type        = string
  default     = "ALLOW_ALL"
}

variable "labels" {
  description = "A set of key/value label pairs to assign to the function"
  type        = map(string)
  default     = {}
}

variable "service_account_email" {
  description = "If provided, the self-provided service account to run the function with."
  type        = string
  default     = ""
}


variable "max_instances" {
  description = "The limit on the maximum number of function instances that may coexist at a given time"
  type        = number
  default     = 3000

}

variable "min_instances" {
  description = "The limit on the minimum number of function instances that may coexist at a given time"
  type        = number
  default     = 0
}

variable "timeout" {
  description = "Timeout (in seconds) for the function. Default value is 60 seconds. Cannot be more than 540 seconds."
  type        = number
  default     = 60
}

variable "failure_policy_retry" {
  description = "Whether the function should be retried on failure."
  type        = bool
  default     = false
}

variable "resource" {
  description = "The name or partial URI of the resource from which to observe events. For example -projects/my-project/topics/my-topic"
  type        = string
  default     = ""
}

variable "bucket_name" {
  description = "The bucket to upload the function code to."
  type        = string
}

variable "folder_path" {
  description = "The absolute path of the python code file."
  type        = string
}

# ---------------------------------------------------------------
#    Cloud Pub/Sub Topic Variable
# ---------------------------------------------------------------

variable "topic_name" {
  description = "The name of the Cloud Pub/Sub Topic"
  type        = string
}

variable "message_retention_duration" {
  description = "Indicates the minimum duration to retain a message after it is published to the topic. If this field is set, messages published to the topic in the last messageRetentionDuration are always available to subscribers."
  type        = string
  default     = ""
}

variable "topic_labels" {
  description = "A set of key/value label pairs to assign to this Topic."
  type        = map(any)
  default     = {}
}


# ---------------------------------------------------------------
#    Cloud Scheduler Variable
# ---------------------------------------------------------------

variable "jobs_list" {
  type = map(object({
    data      = any
    schedule  = string
    time_zone = string
  }))
}

--------------------------------------------------------------------

Example

    include {
      path = find_in_parent_folders()
    }

    terraform {
      source = "..//gcp_functions"  # Replace with module path
    }

    inputs = {
      project_id    = "<PROJECT_ID>"
      region        = "us-central1"
      function_name = "function-terra"
      runtime       = "python37"
      entry_point   = "main"
      bucket_name   = "<BUCKET_NAME>"
      folder_path   = "<ABSOLUTE_PATH_OF_CODE_FOLDER>"

      topic_name = "new-topic"

      jobs_list = {
        "job-ecp-compute" = {
          data = {
            "bq_dataset"  = "instancedata",
            "bq_project"  = "<PROJECT_ID>",
            "bq_table"    = "instancetable",
            "project"     = "<PROJECT_ID>",
            "asset_types" = ["compute.googleapis.com/Disk", "compute.googleapis.com/Address"]
          }
          schedule  = "0 22 * * *"
          time_zone = "Etc/UTC"
        },
        "job-ecp-storage" = {
          data = {
            "bq_dataset"  = "instancedata",
            "bq_project"  = "<PROJECT_ID>",
            "bq_table"    = "bucketinfo",
            "project"     = "<PROJECT_ID>",
            "asset_types" = ["storage.googleapis.com/Bucket"]
          }
          schedule  = "0 22 * * *"
          time_zone = "Etc/UTC"
        },
        "job-all" = {
          data = {
            "bq_dataset"  = "instancedata",
            "bq_project"  = "<PROJECT_ID>",
            "bq_table"    = "allinstance",
            "project"     = "<PROJECT_ID>",
            "asset_types" = []               # All assets will be exported
          }
          schedule  = "0 22 * * *"
          time_zone = "Etc/UTC"
        }
      }
    }
    ```
