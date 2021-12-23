locals {
  env_envgroup_pairs = flatten([
    for eg_name, eg in var.apigee_envgroups : [
      for e in eg.environments : {
        envgroup = eg_name
        env      = e
      }
    ]
  ])
}

resource "google_apigee_organization" "apigee_org" {
  project_id                           = var.project_id
  analytics_region                     = var.analytics_region
  display_name                         = var.display_name
  description                          = var.description
  runtime_type                         = var.runtime_type
  authorized_network                   = var.authorized_network
  runtime_database_encryption_key_name = var.database_encryption_key
}

resource "google_apigee_environment" "apigee_env" {
  for_each = toset(var.apigee_environments)
  org_id   = google_apigee_organization.apigee_org.id
  name     = each.key
}

resource "google_apigee_envgroup" "apigee_envgroup" {
  for_each  = var.apigee_envgroups
  org_id    = google_apigee_organization.apigee_org.id
  name      = each.key
  hostnames = each.value.hostnames
}

resource "google_apigee_envgroup_attachment" "env_to_envgroup_attachment" {
  for_each    = { for pair in local.env_envgroup_pairs : "${pair.envgroup}-${pair.env}" => pair }
  envgroup_id = google_apigee_envgroup.apigee_envgroup[each.value.envgroup].id
  environment = google_apigee_environment.apigee_env[each.value.env].name
