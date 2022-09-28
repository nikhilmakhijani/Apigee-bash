export_path() {
    PROJECT_ID="$(cat $1 | jq -r .project_id)"
    HYBRID_HOME="${HOME}/$(cat $1 | jq -r .apigeectl_installation)/hybrid-files" 
    APIGEECTL_HOME="${HOME}/$(cat $1 | jq -r .apigeectl_installation)/apigeectl"
    APIGEECTL_ROOT="${HOME}/$(cat $1 | jq -r .apigeectl_installation)"
    QUICKSTART_TOOLS=$HOME
    ISTIO_CTL=$QUICKSTART_TOOLS/asm/istio-1.9.8-asm.6
    export PATH=$PATH:"$QUICKSTART_TOOLS"/kpt
    export PATH=$PATH:"$QUICKSTART_TOOLS"/jq
    export PATH=$ISTIO_CTL/bin:$PATH
    export PATH=$PATH:$APIGEECTL_HOME
    source "$HOME/google-cloud-sdk/path.bash.inc"
    source "$HOME/google-cloud-sdk/completion.bash.inc"
    echo ${GOOGLE_CREDENTIALS} > /tmp/GOOGLE_CREDENTIALS
    SERVICE_ACCOUNT=$(cat /tmp/GOOGLE_CREDENTIALS | jq -r .client_email)
    gcloud auth activate-service-account $SERVICE_ACCOUNT \
                --key-file=/tmp/GOOGLE_CREDENTIALS --project=$PROJECT_ID
    gcloud config set project $PROJECT_ID
}

function wait_for_ready(){
    local expected_output=$1
    local action=$2
    local message=$3
    local max_iterations=150 # 10min
    local iterations=0
    local actual_out

    echo -e "Waiting for $action to return output $expected_output"
    echo -e "Start: $(date)\n"

    while true; do
        iterations="$((iterations+1))"

        actual_out=$(bash -c "$action" || echo "error code $?")
        if [ "$expected_output" = "$actual_out" ]; then
            echo -e "\n$message"
            break
        fi

        if [ "$iterations" -ge "$max_iterations" ]; then
          echo "Wait timed out"
          exit 1
        fi
        echo -n "."
        sleep 5
    done
}

check_rs_ds_sts_pods() {
    namespace=$1
    kind=$2
    object_name=$3
    if [[ "$kind" == "sts" || "$kind" == "statefulset" || "$kind" == "rs" || "$kind" == "replicaset" ]] ; then
    sts_replicas=$(kubectl get \
        $kind \
        -n $namespace \
        $object_name \
        -o=json | \
        jq -r .status.replicas)
    wait_for_ready \
        $sts_replicas \
        "kubectl get $kind -n $namespace $object_name -o=json | jq -r .status.readyReplicas" "All $object_name Pods Are UP"
    
    elif [[ "$kind" == "ds" || "$kind" == "daemonset"  ]] ; then

    sts_replicas=$(kubectl get \
        $kind \
        -n $namespace \
        $object_name \
        -o=json | \
        jq -r .status.desiredNumberScheduled )
    wait_for_ready \
        $sts_replicas \
        "kubectl get  $kind -n $namespace $object_name -o=json | jq -r .status.numberReady" "All $object_name Pods Are UP"

    else 
        echo "Unknown Kubernetes Kind  : ----> $kind ... !!!"
        exit 1
    fi
}

# Create Kubernetes secret for certificates
create_secret_cert(){
  egn=$1
  cluster=$2
  kubectl create -n istio-system secret tls $egn-ssl-secret --kubeconfig=$cluster \
    --key=$HYBRID_HOME/certs/$egn.key \
    --cert=$HYBRID_HOME/certs/$egn.pem
}

# Retrieve token 
token() { echo -n "$(gcloud config config-helper --force-auth-refresh | grep access_token | grep -o -E '[^ ]+$')" ; }

#Enable APIs
enable_all_apis() {

  echo "📝 Enabling all required APIs in GCP project \"$PROJECT_ID\""
  echo -n "⏳ Waiting for APIs to be enabled"

  gcloud services enable \
    apigee.googleapis.com \
    apigeeconnect.googleapis.com \
    cloudresourcemanager.googleapis.com \
    pubsub.googleapis.com \
    cloudresourcemanager.googleapis.com \
    compute.googleapis.com \
    container.googleapis.com --project $PROJECT_ID


  gcloud config set project $PROJECT_ID
}

# Configure the validating webhook [Istio]
validating_webhook(){
  cluster=$1
  echo "📝 Applying the validating webhook configuration"
  kubectl apply -f $ISTIOYAML --kubeconfig=$cluster
  # Verifying  configuration 
  kubectl get svc -n istio-system --kubeconfig=$cluster
}

# Install ASM
install_asm_cluster(){
  cluster=$1
  region=$2
  echo "🤔 Checking if namepsace exists on cluster- $region"
   if ( kubectl get namespace istio-system --kubeconfig=$cluster ) &>/dev/null;then
    echo " 🎉 istio-system namespace exists"
    else 
    echo "🤷‍♀️ istio-system namespace doesnt exist!! 🔧 Creating namespace for istio"
    kubectl create namespace istio-system --kubeconfig=$cluster
   fi
   if [[ ! -z $ASM_VERSION ]] ; then
    echo "🏗️ Installing Istio on cluster in region-$region"
    if [[ "$IS_PUBLIC" == "true" ]]; then
     yes | istioctl install --set profile=asm-multicloud --set revision="$ASM_REVISION" --kubeconfig=$cluster
    else
     yes | istioctl install --set profile=asm-multicloud \
             --set revision="$ASM_REVISION" \
             --set values.gateways.istio-ingressgateway.serviceAnnotations.'service\.beta\.kubernetes\.io/azure-load-balancer-internal'="true" \
             --kubeconfig=$cluster
     fi 
    echo "🤔 Checking installation status on cluster-$region"   # Checking status
    kubectl get pods -n istio-system --kubeconfig=$cluster
    kubectl get svc -n istio-system  --kubeconfig=$cluster
    validating_webhook $cluster
  else
    echo "Skipping ASM Installation"
  fi
}

# Enable synchronizer
enable_synchronizer() {

    if [[ "$ENV" == "non-prod" ]]; then

     echo -n "🔛 Enabling runtime synchronizer for $ENV "
     curl --fail -X POST -H "Authorization: Bearer $(token)" \
     -H "Content-Type:application/json" \
     "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}:setSyncAuthorization" \
     -d "{\"identities\":[\"serviceAccount:apigee-$ENV@${PROJECT_ID}.iam.gserviceaccount.com\"]}"

    elif [[ "$ENV" == "prod" ]]; then

      echo -n "🔛 Enabling runtime synchronizer"
      curl --fail -X POST -H "Authorization: Bearer $(token)" \
      -H "Content-Type:application/json" \
      "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}:setSyncAuthorization" \
      -d "{\"identities\":[\"serviceAccount:apigee-synchronizer@${PROJECT_ID}.iam.gserviceaccount.com\"]}"

    else
      echo "💣 Only Prod and Non-Prod are valid"
      exit 2
    fi
}

# Check CA cert secrets
check_ssl_secret(){
   env_group_name=$1
   cluster=$2
   domain=$3
   secret_response=$(kubectl get secret -n istio-system -o=json --kubeconfig=$cluster | jq --arg secret "$env_group_name-ssl-secret" -r '.items[] | select(.metadata.name | contains($secret))')
   if [[ -z $secret_response ]] ; then
     echo "🤷‍♀️ Secret Doesnt Exist !! 🔧 Creating Secret $env_group_name"
     openssl req  -nodes -new -x509 -keyout $HYBRID_HOME/certs/$env_group_name.key -out $HYBRID_HOME/certs/$env_group_name.pem -subj '/CN='*.$domain'' -days 3650
     create_secret_cert $env_group_name $cluster
   else
     echo "🎉 Secret $1 Already Exists !!"
   fi 
}

# Check if service account exists
check_for_sa() {
    if [[ "$ENV" == "non-prod" ]]; then
      echo "🤔 Checking required service account $ENV"
        if (gcloud iam service-accounts describe apigee-non-prod@$PROJECT_ID.iam.gserviceaccount.com) &>/dev/null;then
         echo "🎉 Service account exists"
         return 0
        else
         echo "💣 Service account doesnt exist. Please create sa!! Exiting"
         return 1
        fi
    else
      echo "🤔 Checking required service account $ENV ⏳"
      flag=1
       saNames=(apigee-cassandra apigee-logger apigee-mart apigee-metrics apigee-runtime apigee-synchronizer apigee-udca apigee-watcher)
       for sa in ${saNames[@]}
        do
         if ( ! gcloud iam service-accounts describe $sa@$PROJECT_ID.iam.gserviceaccount.com) &>/dev/null;then
           echo "💣 Service Account - $sa doesn't exist"
           flag=0
         fi
        done
      if [[ $flag == 0 ]]; then
        echo "📥 You need to create service accounts to continue. Exiting"
        return 1
       else
        return 0
      fi
    fi 
}

check_k8s_object() {
  cluster=$1
  obj=$2
  name=$3
  ns=$4

  if [[ "$obj" == "namespace" || "$obj" == "ns"  ]] ; then
    obj_response=$(kubectl get $obj -o=json --kubeconfig=$cluster | jq --arg obj "$name" -r '.items[] | select(.metadata.name | contains($obj))')
    if [[ -z $obj_response ]] ; then
    return 1
    else
    return 0
    fi
  else
    obj_response=$(kubectl get $obj -n $ns -o=json --kubeconfig=$cluster | jq --arg obj "$name" -r '.items[] | select(.metadata.name | contains($obj))')
    if [[ -z $obj_response ]] ; then
    return 1
    else
    return 0
    fi
  fi
}

validate_cluster() {
    wait_for_ready "Running" "kubectl get po -l app=$1 -n $2 -o=jsonpath='{.items[0].status.phase}' 2>/dev/null" "$1: Running"
}

deploy_api() {
    api_proxy_name="mock"
    proxy_bundle_file="mock_rev1_2021_12_30.zip"
    for ENV_GROUP_NAME in $ENVGPARR
    do
     envnames=$(cat $INPUTFILE | jq -r  .apigee_envgroups.$ENV_GROUP_NAME.environments[])
          for envname in $envnames
           do
            python3 $SCRIPT_PATH/python/deploy_api.py \
                --project_id $PROJECT_ID \
                --api_proxy_name $api_proxy_name \
                --proxy_bundle_path $SCRIPT_PATH/api_proxy_bundle/$proxy_bundle_file \
                --env $envname
            done
    done
}

validate_api() {
    client_pod_name=$(date +%s)
    client_pod_spec="/tmp/validate_client.yaml"
    sed "s*<VALIDATION_IMAGE>*$VALIDATION_IMAGE*;s*<date>*${client_pod_name}*;s*<VALIDATION_IMAGE_PULL_SECRET>*$VALIDATION_IMAGE_PULL_SECRET*" $SCRIPT_PATH/templates/validate_client.yaml > ${client_pod_spec}
    kubectl apply -f ${client_pod_spec}
    for ENV_GROUP_NAME in $ENVGPARR
     do
      hostnames=$(cat $INPUTFILE | jq -r  .apigee_envgroups.$ENV_GROUP_NAME.hostnames[])
      tlsmode=$(cat $INPUTFILE | jq -r  .apigee_envgroups.$ENV_GROUP_NAME.tls_mode)
      if [[ "$tlsmode" = "SIMPLE" ]]; then
       for hostname in $hostnames
         do
           HOSTALIAS=$hostname
           export INGRESS_HOST=$(kubectl -n istio-system get service \
           istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
           export SECURE_INGRESS_PORT=$(kubectl -n istio-system get \
           service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
           expected_output=$(curl https://mocktarget.apigee.net/json)
           wait_for_ready "$expected_output" \
           "kubectl exec curl-$client_pod_name -n apigee -- curl -H Host:$HOSTALIAS --resolve $HOSTALIAS:$SECURE_INGRESS_PORT:$INGRESS_HOST https://$HOSTALIAS:$SECURE_INGRESS_PORT/mock -k" \
           "API Proxy Validation Successful"
          done
       else
          echo " Change tls_mode value to SIMPLE instead of MUTUAL" 
     fi          
    done
     kubectl delete -f ${client_pod_spec} 
}

check_cassandra_pods() {
  cassandra_desired_replicas=$(kubectl get \
    sts \
    -n apigee \
    apigee-cassandra-default \
    -o=json | \
    jq -r .status.replicas)
  wait_for_ready $cassandra_desired_replicas "kubectl get sts -n apigee apigee-cassandra-default -o=json | jq -r .status.readyReplicas" "All Cassandra Pods Are UP"
}

check_apigeedatastore() {
  wait_for_ready "running" "kubectl get apigeeds default -n apigee -o=json | jq -r .status.state" "ApigeeDatastore is running"
}

install_cert_manager() {
    CLUSTER=$1
    echo "Installing cert manager"
    kubectl apply --validate=false -f $CERT_MG_URL --kubeconfig=$CLUSTER | sleep 20
    kubectl get pods -n cert-manager --kubeconfig=$CLUSTER
}

edit_cluster_specific_params() {
  kube_config=$1
  input_file=$2
  k8s_cluster_name=$(kubectl \
      config \
      view \
      --kubeconfig=$kube_config \
      -o jsonpath='{.contexts[0].context.cluster}')
  k8s_cluster_region=$(kubectl config view \
           --kubeconfig=$kube_config -o jsonpath="{.clusters[].cluster.server}" | \
           python3 -c "import sys;print(sys.stdin.read().split('.')[-3])")
  python3 $SCRIPT_PATH/python/edit_json.py \
      --input_file $input_file \
      --key k8s_cluster_name  \
      --value $k8s_cluster_name
  python3 $SCRIPT_PATH/python/edit_json.py \
      --input_file $input_file \
      --key aks_region  \
      --value $k8s_cluster_region
}

generate_single_region_overrides() {
    kube_config=$1
    input_file=$2
    yaml_file=$3
    echo "Generating overrides in $yaml_file"
    edit_cluster_specific_params $kube_config $input_file
    python3 $SCRIPT_PATH/python/generate_overrides.py \
        --input_file $input_file  \
        --output_file $yaml_file \
        --template_location  $SCRIPT_PATH/templates
    echo "################# First Region Overrides #################"
    cat $yaml_file
    echo "################# First Region Overrides #################"
}

generate_multi_region_overrides() {
  kube_config=$1
  input_file=$2
  yaml_file=$3
  cassandra_ip=$4
  edit_cluster_specific_params $kube_config $input_file
  if [[ -z $cassandra_ip ]] ; then 
      echo "Generating overrides for second region without Cassandra IP"
      python3 $SCRIPT_PATH/python/generate_overrides.py  \
          --input_file $input_file  \
          --output_file $yaml_file \
          --template_location  $SCRIPT_PATH/templates \
          --second_region 
  else
      echo "Generating overrides for second region with Cassandra IP"
      python3 $SCRIPT_PATH/python/generate_overrides.py  \
          --input_file $input_file  \
          --output_file $yaml_file \
          --template_location $SCRIPT_PATH/templates \
          --second_region \
          --cassandra_seed_host $cassandra_ip
  fi
  echo "################# Second Region Overrides #################"
  cat $yaml_file
  echo "################# Second Region Overrides #################"
}

install_runtime() {
    pushd "$HYBRID_HOME" || return # because apigeectl uses pwd-relative paths
    mkdir -p "$HYBRID_HOME"/generated
    echo "Running  apigeectl init using  $1"
    "$APIGEECTL_HOME"/apigeectl init -f $1 --print-yaml > "$HYBRID_HOME"/generated/apigee-init.yaml || ( sleep 120 && "$APIGEECTL_HOME"/apigeectl init -f $1 > "$HYBRID_HOME"/generated/apigee-init.yaml )
    sleep 2 && echo -n "Waiting for Apigeectl init "
    wait_for_ready "Running" "kubectl get po -l app=apigee-controller -n apigee-system -o=jsonpath='{.items[0].status.phase}' 2>/dev/null" "Apigee Controller: Running"
    echo "waiting for 30s for the webhook certs to propagate" && sleep 30
    echo "Running  apigeectl apply using  $1"
    "$APIGEECTL_HOME"/apigeectl apply -f $1 --dry-run=client
    if [ $? -eq 0 ]; then
    "$APIGEECTL_HOME"/apigeectl apply -f $1 --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml || ( sleep 120 && "$APIGEECTL_HOME"/apigeectl apply -f $1 --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml )
    sleep 2 && echo -n "Waiting for Apigeectl apply"
    wait_for_ready "Running" "kubectl get po -l app=apigee-runtime -n apigee -o=jsonpath='{.items[0].status.phase}' 2>/dev/null" "Apigee Runtime: Running."
    echo  "Hybrid installation completed!"
    fi
    popd || return
}

region_01_details() {
    kube_config=$1
    ns_manifest_file=$2
    secret_manifest_file=$3
    kubectl get namespace apigee --kubeconfig=$kube_config -o yaml  > $ns_manifest_file
    kubectl -n cert-manager get secret apigee-ca --kubeconfig=$kube_config -o yaml  > $secret_manifest_file
    echo "################# First  Region NS Manifest #################"
    cat $ns_manifest_file
    echo "################# First  Region NS Manifest#################"
}

secondary_regions_installation() {
    kube_config="$1"
    ns_manifest_file="$2"
    secret_manifest_file="$3"
    if ! (check_k8s_object "$kube_config" "namespace" "apigee") ; then
        kubectl apply -f "$ns_manifest_file" --kubeconfig="$kube_config"
    else
        echo "Namespace apigee Already Exists  !!! Hence Skipping "
    fi
    if ! (check_k8s_object "$kube_config" "secret" "apigee-ca" "cert-manager") ; then
        kubectl -n cert-manager apply -f "$secret_manifest_file" --kubeconfig="$kube_config"
    else
        echo "Secret apigee-ca Already Exists in the namespace cert-manager !!! Hence Skipping "
    fi
}

generate_data_replication_manifest() {
    dc_name=$1
    replication_manifest=$2
    org_name=$(kubectl get apigeeorg -n apigee -o json | jq .items[].metadata.name)
    python3 $SCRIPT_PATH/python/generate_data_replication.py --primary_cassandra_dc_name $dc_name \
        --apigee_org $org_name \
        --output_file $replication_manifest \
        --template_location $SCRIPT_PATH/templates
    cat $replication_manifest
}

cassandra_replication() {
    replication_manifest=$1
    kubectl apply -f $replication_manifest
    sleep 2 && echo -n "Waiting for datareplication apply"
    wait_for_ready "complete" "kubectl -n apigee get apigeeds -o json | jq -r '.items[].status.cassandraDataReplication.rebuildDetails.\"apigee-cassandra-default-0\".state'" "Replication completed !!"
    echo  "Data replicaiton completed!"
}

check_installtion_status() {
 if [ $(kubectl get configmap $1 --kubeconfig=$2 -o jsonpath='{.data.install}'  2> /dev/null) ]; then
 echo "Config Map Exists !! Checking value"
 value=$(kubectl get configmap $1 --kubeconfig=$2 -o jsonpath='{.data.install}')
  if [[ "$value" == "setupdone" ]]; then
   echo "Value is matching"
   return 0
  else
  echo "Value doesn't match"
   return 1
  fi
 else
  return 1
 fi
}

upload_to_gcs() {
  src=$1
  dest=$2
  gsutil -m cp -c $src gs://$dest
}

fetch_from_gcs() {
  src=$1
  dest=$2
  gsutil -m cp -c gs://$src $dest &>/dev/null
  if [ $? -eq 0 ]; then
   echo "File Exists!! Downloaded"
  else
   echo "File Doesn't exist"
  fi
}

detect_changes() {
  kube_config=$1
  compare_input_file="/tmp/compare.json"
  fetch_from_gcs "$CONFIG_BUCKET_NAME/$PROJECT_ID/apigee-config/$(basename -- $INPUTFILE)" $compare_input_file
  python3 $SCRIPT_PATH/python/input_change_detector.py \
     --new_input_file $INPUTFILE \
     --old_input_file $compare_input_file \
     --apigeectl_flag_map $SCRIPT_PATH/configs/apigeectl_flag_map.json \
     --kube_config $kube_config > $CHANGES 
}

apply_operational_change(){
  overrides=$1
  flag=$2
  pushd "$HYBRID_HOME" || return # because apigeectl uses pwd-relative paths
  mkdir -p "$HYBRID_HOME"/generated
  echo "Applying changes!!"
  echo ""$APIGEECTL_HOME"/apigeectl apply -f $overrides $flag"
  "$APIGEECTL_HOME"/apigeectl apply -f $overrides $flag --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml || ( sleep 120 && "$APIGEECTL_HOME"/apigeectl apply -f $overrides $flag --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml )
  sleep 2 && echo -n "Waiting for Apigeectl apply"
  echo "Update Completed"
  popd || return
}

verify_backup_restore(){
    backup_enabled="$(cat $INPUTFILE | jq -r .cassandra_backup.enabled)"
    restore_enabled="$(cat $INPUTFILE | jq -r .cassandra_restore.enabled)"
    if [[ "$backup_enabled" == "true" ]]; then 
      echo "Backup parameter is enabled. Checking Backup Status !!"
      download_cluster_version_kubectl $cluster_kubectl_location
      job_name="backup-trigger-$(date +%s)"
      $cluster_kubectl_location create job --from=cronjob/apigee-cassandra-backup -n apigee $job_name
      wait_for_ready "Succeeded" "kubectl get pod -n apigee -l job-name=$job_name -o json | jq -r '.items[0].status.phase'" "Backup job is completed !!"
      kubectl delete job $job_name -n apigee
    elif [[ "$restore_enabled" == "true" ]]; then
      echo "Backup is not enabled !! Checking Restore Parameter !!"
      echo "Restore parameter is enabled. Checking Restore Status !!"
      wait_for_ready "Succeeded" "kubectl get pod -n apigee -l job-name=apigee-cassandra-restore -o json| jq -r '.items[0].status.phase'" "Restore job is completed !!"
    else
      echo "Backup and Restore both are disabled"
    fi
}

download_cluster_version_kubectl() {
    kubectl_location=$1
    k8s_server_version=$(kubectl version -o=json | jq -r .serverVersion.gitVersion)
    curl -LO "https://dl.k8s.io/release/$k8s_server_version/bin/linux/amd64/kubectl"
    mv kubectl ${kubectl_location}
    chmod +x ${kubectl_location}
}

update_runtime() {
  changes=$1
  kube_config=$2
  overrides_yaml=$3
  echo "####### Updating Cluster #######"
  generate_single_region_overrides $kube_config $INPUTFILE $overrides_yaml
  upload_to_gcs \
    $overrides_yaml \
    "$CONFIG_BUCKET_NAME/$PROJECT_ID/apigee-config/$(basename -- $overrides_yaml)"
  export KUBECONFIG=$kube_config
  flags="$(cat $changes| jq -r .flags )"
  if [[ "$flags" == "upgrade" ]]; then
   echo "Upgrading apigee hybrid runtime"
   apigee_upgrade_init $overrides_yaml
   apigee_upgrade_apply $overrides_yaml
  elif [[ "$flags" == "add_env" ]]; then
   create_apigee_env_envgroup $overrides_yaml
  elif [[ "$flags" == "delete_env" ]]; then
    envs="$(cat $changes | jq -r .components)"
    for each_env in $envs
      do
        echo "Processing environment --> $each_env"
        env_overrides=$(echo $3 | cut -d '.' -f 1)
        old_region_overrides="$env_overrides-$each_env.yaml"
        fetch_from_gcs "$CONFIG_BUCKET_NAME/$PROJECT_ID/apigee-config/$(basename -- $old_region_overrides)" $old_region_overrides
        delete_apigee_env_components $old_region_overrides $each_env
      done
    apply_operational_change $overrides_yaml
  else 
   apply_operational_change $overrides_yaml "$flags"
   echo "####### Update Completed #######" 
  fi
}

apigee_upgrade_init() {
    overrides=$1
    pushd "$HYBRID_HOME" || return # because apigeectl uses pwd-relative paths
    mkdir -p "$HYBRID_HOME"/generated
    echo "Running  apigeectl init using  $overrides"
    "$APIGEECTL_HOME"/apigeectl init -f $overrides --print-yaml > "$HYBRID_HOME"/generated/apigee-init.yaml || ( sleep 120 && "$APIGEECTL_HOME"/apigeectl init -f $overrides > "$HYBRID_HOME"/generated/apigee-init.yaml )
    sleep 2 && echo -n "Waiting for Apigeectl init "
    wait_for_ready "Running" "kubectl get po -l app=apigee-controller -n apigee-system -o=jsonpath='{.items[0].status.phase}' 2>/dev/null" "Apigee Controller: Running"
    echo "waiting for 30s for the webhook certs to propagate" && sleep 30

    popd || return
}

apigee_upgrade_apply(){
  overrides=$1
  components=(--datastore --telemetry --redis --org --all-envs)
  for component in "${components[@]}"
   do
    echo "Applying $component flag"
    apply_operational_change $overrides $component
    case $flag in 
    --datastore)
        check_rs_ds_sts_pods apigee sts apigee-cassandra-default
        ;;
        
    --telemetry)
        check_rs_ds_sts_pods apigee ds apigee-logger-apigee-telemetry
        ;;

    --redis)
        check_rs_ds_sts_pods apigee sts apigee-redis-default
        ;;

    --all-envs)
        wait_for_ready "Running" "kubectl get po -l app=apigee-runtime -n apigee -o=jsonpath='{.items[0].status.phase}' 2>/dev/null" "Apigee Runtime: Running."
         ;;

    --org)
      echo "Checking watcher"
      wait_for_ready "Running" "kubectl get po -l app=apigee-watcher -n apigee -o=jsonpath='{.items[0].status.phase}' 2>/dev/null" "Apigee Watcher: Running."
      echo "Checking mart"
      wait_for_ready "Running" "kubectl get po -l app=apigee-mart -n apigee -o=jsonpath='{.items[0].status.phase}' 2>/dev/null" "Apigee Mart: Running."
      echo "Checking connect agent"
      wait_for_ready "Running" "kubectl get po -l app=apigee-connect-agent -n apigee -o=jsonpath='{.items[0].status.phase}' 2>/dev/null" "Apigee connectAgent: Running."
       ;;

     *)
     echo "Wrong flag"
      ;;

    esac
  done
}

generate_env_specific_overrides() {
    kube_config=$1
    input_file=$2
    yaml_file=$3
    env=$4
    echo "Generating overrides in $yaml_file"
    edit_cluster_specific_params $kube_config $input_file
    python3 $SCRIPT_PATH/python/generate_overrides.py \
        --input_file $input_file  \
        --output_file $yaml_file \
        --template_location  $SCRIPT_PATH/templates \
        --custom_env $env
    echo "################# $env specific overrides #################"
    cat $yaml_file
    echo "################# $env specific overrides #################"
}

apply_env_configuration() { 
    kubeconfig=$1
    env_overrides=$(echo $2 | cut -d '.' -f 1)
    for env in $ENV_CONFIG
      do
       echo "Environment is $env"
       env_overrides_yaml="$env_overrides-$env.yaml"
       generate_env_specific_overrides $kubeconfig $INPUTFILE $env_overrides_yaml $env
       upload_to_gcs \
        $env_overrides_yaml \
        "$CONFIG_BUCKET_NAME/$PROJECT_ID/apigee-config/$(basename -- $env_overrides_yaml)"
       apply_operational_change $env_overrides_yaml "--env $env"
      done
}

generate_env_configuration() { 
    kubeconfig=$1
    env_overrides=$(echo $2 | cut -d '.' -f 1)
    for env in $ALL_ENVS
      do
       echo "Environment is $env"
       env_overrides_yaml="$env_overrides-$env.yaml"
       generate_env_specific_overrides $kubeconfig $INPUTFILE $env_overrides_yaml $env
       upload_to_gcs \
        $env_overrides_yaml \
        "$CONFIG_BUCKET_NAME/$PROJECT_ID/apigee-config/$(basename -- $env_overrides_yaml)"
      done
}

create_apigee_env_envgroup(){
  overrides=$1
  pushd "$HYBRID_HOME" || return # because apigeectl uses pwd-relative paths
  mkdir -p "$HYBRID_HOME"/generated

  echo "Creating Environments !!"
  echo ""$APIGEECTL_HOME"/apigeectl apply -f $overrides --all-envs"
  "$APIGEECTL_HOME"/apigeectl apply -f $overrides --all-envs --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml || ( sleep 120 && "$APIGEECTL_HOME"/apigeectl apply -f $overrides --all-envs --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml )

  echo "Creating Environment Groups!!"
  echo ""$APIGEECTL_HOME"/apigeectl apply -f $overrides --settings virtualhosts"
  "$APIGEECTL_HOME"/apigeectl apply -f $overrides --settings virtualhosts --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml || ( sleep 120 && "$APIGEECTL_HOME"/apigeectl apply -f $overrides --settings virtualhosts --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml )

  echo "Creating of Environment & Environment Groups Completed"
  popd || return
}

delete_apigee_env_components(){
  overrides=$1
  env=$2
  if [ -z "$env" ]; then
    echo "Environment param is empty !! "
    exit 1
  fi
  pushd "$HYBRID_HOME" || return # because apigeectl uses pwd-relative paths
  mkdir -p "$HYBRID_HOME"/generated
  echo "Deleting Environment  $env!!"
  echo ""$APIGEECTL_HOME"/apigeectl delete -f $overrides --env=$env"
  "$APIGEECTL_HOME"/apigeectl delete -f $overrides --env=$env --dry-run=true
  if [ $? -eq 0 ]; then
  "$APIGEECTL_HOME"/apigeectl delete -f $overrides --env=$env --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml || ( sleep 120 && "$APIGEECTL_HOME"/apigeectl delete -f $overrides --env=$env --print-yaml > "$HYBRID_HOME"/generated/apigee-runtime.yaml )
  sleep 2 && echo -n "Waiting for Apigeectl delete"
  fi
  echo "Delete of Environment $env Completed"
  popd || return
}
