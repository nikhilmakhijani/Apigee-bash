#!/bin/bash

set -e
INPUTFILE=$1
KUBECONFIGCL1="$(cat $INPUTFILE | jq -r .kubeconfig_cl1_path)"
KUBECONFIGCL2="$(cat $INPUTFILE | jq -r .kubeconfig_cl2_path)"
ENV=$(cat $INPUTFILE | jq -r .env ) 
CA_CERT=$(cat $INPUTFILE | jq -r .ca_cert) 
HYBRID_HOME="$(cat $INPUTFILE | jq -r .apigeectl_installation)/hybrid-files" 
APIGEECTL_HOME="$(cat $INPUTFILE | jq -r .apigeectl_installation)/apigeectl"
PROJECT_ID=$(cat $INPUTFILE | jq -r .project_id) 
envgparr=$(cat $INPUTFILE | jq -r '.apigee_envgroups | keys[]')

#Functions definition

# Create Kubernetes secret for certificates
create_secret_cert(){
  egn=$1
   echo "Creating Kubernetes secret on first cluster"
  kubectl create -n istio-system secret generic $egn-ssl-secret --kubeconfig=$KUBECONFIGCL1 \
    --from-file=key=$HYBRID_HOME/certs/$egn.key \
    --from-file=cert=$HYBRID_HOME/certs/$egn.pem
    echo "Creating Kubernetes secret on second cluster"
  kubectl create -n istio-system secret generic $egn-_ssl_secret--kubeconfig=$KUBECONFIGCL2 \
    --from-file=key=$HYBRID_HOME/certs/$egn.key \
    --from-file=cert=$HYBRID_HOME/certs/$egn.pem
}

# Create Kubernetes secret for service account
create_secret_sa(){
  name=$1
  path=$2
  if [[ "$ENV" == "non-prod" ]];then
   echo "Creating Kubernetes secret on first cluster"
   kubectl create secret generic $name --from-file=key.json=$path --kubeconfig=$KUBECONFIGCL1
   echo "Creating Kubernetes secret on second cluster"
   kubectl create secret generic $name --from-file=key.json=$path --kubeconfig=$KUBECONFIGCL2
  else
  echo "Creating Kubernetes secret on first cluster"
  kubectl create secret generic apigee-cassandra-sa --from-file=key.json=$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-cassandra.json --kubeconfig=$KUBECONFIGCL1
  kubectl create secret generic apigee-logger-sa --from-file=key.json=$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-logger.json --kubeconfig=$KUBECONFIGCL1
  kubectl create secret generic apigee-mart-sa --from-file=key.json=$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-mart.json --kubeconfig=$KUBECONFIGCL1
  kubectl create secret generic apigee-metrics-sa --from-file=key.json=$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-metrics.json --kubeconfig=$KUBECONFIGCL1
  kubectl create secret generic apigee-runtime-sa --from-file=key.json=$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-runtime.json --kubeconfig=$KUBECONFIGCL1
  kubectl create secret generic apigee-synchronizer-sa --from-file=key.json=$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-synchronizer.json --kubeconfig=$KUBECONFIGCL1
  kubectl create secret generic apigee-udca-sa --from-file=key.json=$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-udca.json --kubeconfig=$KUBECONFIGCL1
  kubectl create secret generic apigee-watcher-sa --from-file=key.json=$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-watcher.json --kubeconfig=$KUBECONFIGCL1

  echo "Creating Kubernetes secret on second cluster"
  kubectl create secret generic apigee-cassandra-sa --from-file=key.json=$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-cassandra.json --kubeconfig=$KUBECONFIGCL2
  kubectl create secret generic apigee-logger-sa --from-file=key.json=$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-logger.json --kubeconfig=$KUBECONFIGCL2
  kubectl create secret generic apigee-mart-sa --from-file=key.json=$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-mart.json --kubeconfig=$KUBECONFIGCL2
  kubectl create secret generic apigee-metrics-sa --from-file=key.json=$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-metrics.json --kubeconfig=$KUBECONFIGCL2
  kubectl create secret generic apigee-runtime-sa --from-file=key.json=$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-runtime.json --kubeconfig=$KUBECONFIGCL2
  kubectl create secret generic apigee-synchronizer-sa --from-file=key.json=$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-synchronizer.json --kubeconfig=$KUBECONFIGCL2
  kubectl create secret generic apigee-udca-sa --from-file=key.json=$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-udca.json --kubeconfig=$KUBECONFIGCL2
  kubectl create secret generic apigee-watcher-sa --from-file=key.json=$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-watcher.json --kubeconfig=$KUBECONFIGCL2
fi
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
    pubsub.googleapis.com  --project $PROJECT_ID

echo "Printing all enabled APIs in GCP project \"$PROJECT_ID\""
gcloud services list
}

# Create service account
create_sa() {

    if [[ "$ENV" == "non-prod" ]]; then
      echo "Creating required service account and roles for $ENV"
      echo "Waiting for creation ⏳"
      yes | "$APIGEECTL_HOME"/tools/create-service-account -e non-prod -d "$HYBRID_HOME/service-accounts"
      create_secret_sa "apigee-non-prod-sa" "$HYBRID_HOME/service-accounts/$PROJECT_ID-apigee-non-prod.json"
    elif [[ "$ENV" == "prod" ]]; then
      echo "Creating required service account and roles for $ENV"
      echo "Waiting for creation ⏳"
      yes | "$APIGEECTL_HOME"/tools/create-service-account -e prod -d "$HYBRID_HOME/service-accounts"
       create_secret_sa "apigee-prod-sa" "$HYBRID_HOME/service-accounts/$PROJECT_ID"
    else
      echo "💣 Only Prod and Non-Prod are valid"
      exit 2
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

# Create certificates
create_cert() {

  if [[ "$CA_CERT" = "false" ]];then

    echo "CA not required"
    return

   else
    # looping ENV_GROUP_NAME
     for ENV_GROUP_NAME in $envgparr
       do
    # create CA cert if not exist
         i=0
          hostnames=$(cat $INPUTFILE | jq -r  .apigee_envgroups.$ENV_GROUP_NAME.hostnames[])
          for hostname in $hostnames
           do
             domain=$( echo $hostname | cut -d'.' -f2- )
            if [[ $i == 0 ]];then
              echo "domain name is $domain"
              fd=$domain
               echo "checking if certificate secret exists"
               if (( kubectl get secret $ENV_GROUP_NAME-ssl-secret -n istio-system --kubeconfig=$KUBECONFIGL1 ) && (kubectl get secret $ENV_GROUP_NAME-ssl-secret -n istio-system --kubeconfig=$KUBECONFIGCL2 )) &>/dev/null;then
                echo "Secret exists"
               else
                openssl req  -nodes -new -x509 -keyout $HYBRID_HOME/certs/$ENV_GROUP_NAME.key -out $HYBRID_HOME/certs/$ENV_GROUP_NAME.pem -subj '/CN='*.$domain'' -days 3650
                create_secret_cert $ENV_GROUP_NAME
                echo "Secret Created"
               fi
           else
              if [[ "$domain" == "$fd" ]];then
              echo "same domain"
              fi
            fi
             i=$((i+1))
          done   
        
      done
 fi
}

# Check if service account exists
 check_for_sa() {
    if [[ "$ENV" == "non-prod" ]]; then
      echo "Checking required service account $ENV ⏳"
        if (gcloud iam service-accounts describe apigee-non-prod@$PROJECT_ID.iam.gserviceaccount.com) &>/dev/null;then
         echo "Service account exists"
        else
         echo "Service account doesnt exist. Please create sa!! Exiting"
         exit 2
        fi
    else
      echo "Checking required service account $ENV ⏳"
      flag=1
       saNames=(apigee-cassandra apigee-logger apigee-mart apigee-metrics apigee-runtime apigee-synchronizer apigee-udca apigee-watcher)
       for sa in ${saNames[@]}
        do
         if ( ! gcloud iam service-accounts describe $sa@$PROJECT_ID.iam.gserviceaccount.com) &>/dev/null;then
           echo " Service Account - $sa doesn't exist"
           flag=0
         fi
        done
      if [[ $flag == 0 ]]; then
        echo "You need to create service accounts to continue. Exiting"
        exit 
      fi
    fi 
 }

# Function calls

enable_all_apis
create_sa
create_cert
check_for_sa
enable_synchronizer

