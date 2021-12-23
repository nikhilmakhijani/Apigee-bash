# Setup Apigee Org
module "apigeesetup" {
  source              = "./apigee-org"
  project_id          = var.project_id
  analytics_region    = var.analytics_gcp_region
  runtime_type        = var.runtime_type
  apigee_environments = var.apigee_environments
  apigee_envgroups    = var.apigee_envgroups
}

# Creating input.json for bash scripts
locals {
  input_json = {
    project_id                          = var.project_id
    analytics_gcp_region                = var.analytics_gcp_region
    runtime_type                        = var.runtime_type
    apigee_environments                 = var.apigee_environments
    apigee_envgroups                    = var.apigee_envgroups
    env                                 = var.env
    apigeectl_installation              = var.apigeectl_installation
    ca_cert                             = var.ca_cert
    kubeconfig_cl1_path                 = var.kubeconfig_cl1_path
    kubeconfig_cl2_path                 = var.kubeconfig_cl2_path
    apigeectl_version                   = var.apigeectl_version
    cert_mg_version                     = var.cert_mg_version
    k8s_cluster_name                    = var.k8s_cluster_name
    k8s_gcp_cluster_region              = var.k8s_gcp_cluster_region
    aks_region                          = var.aks_region
    dc_name                             = var.dc_name
    apigee_org_name                     = var.project_id
    apigee_instance_id                  = var.apigee_instance_id
    image_pull_secret                   = var.image_pull_secret
    apigee_runtime_nodepool_label_key   = var.apigee_runtime_nodepool_label_key
    apigee_runtime_nodepool_label_value = var.apigee_runtime_nodepool_label_value
    apigee_data_nodepool_label_key      = var.apigee_data_nodepool_label_key
    apigee_data_nodepool_label_value    = var.apigee_data_nodepool_label_value
    kmsEncryptionKey                    = var.kmsEncryptionKey
    kvmEncryptionKey                    = var.kvmEncryptionKey
    cacheEncryptionKey                  = var.cacheEncryptionKey
    synchronizer_svc_account_secret     = var.synchronizer_svc_account_secret
    runtime_svc_account_secret          = var.runtime_svc_account_secret
    mart_svc_account_secret             = var.mart_svc_account_secret
    logger_svc_account_secret           = var.logger_svc_account_secret
    metrics_svc_account_secret          = var.metrics_svc_account_secret
    connectagent_svc_account_secret     = var.connectagent_svc_account_secret
    watcher_svc_account_secret          = var.watcher_svc_account_secret
    authz                               = var.authz
    mart                                = var.mart
    synchronizer                        = var.synchronizer
    runtime                             = var.runtime
    cassandra                           = var.cassandra
    cassandra_auth                      = var.cassandra_auth
    cassandra_backup                    = var.cassandra_backup
    cassandra_restore                   = var.cassandra_restore
    udca                                = var.udca
    fluentd                             = var.fluentd
    logger                              = var.logger
    metrics_prometheus                  = var.metrics_prometheus
    metrics_sdSidecar                   = var.metrics_sdSidecar
    connectAgent                        = var.connectAgent
    watcher                             = var.watcher
    redis                               = var.redis
    envoy                               = var.envoy
    ao                                  = var.ao
    ao_installer                        = var.ao_installer
    apigee_rbac                         = var.apigee_rbac
  }
}

resource "local_file" "output" {
  content  = jsonencode(local.input_json)
  filename = "../scripts/tmp/input.json"
}

output "input_json" {
  value = jsonencode(local.input_json)
}

# Calling Bash script using null resource
module "bashscript" {
  source      = "../null-res-module"
  input_path  = var.input_path
  script_path = var.script_path
}

