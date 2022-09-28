set -e

action=$1
branch=$2
project_id=$3
directory=$4
base_dir=$(pwd)/${directory}
echo $base_dir
tmp_plan="${base_dir}/tmp_plan" #if you change this, update build triggers

## Terragrunt init function
tg_init() {
  local path=$1
  local tf_env=$2
  local tf_component=$3
  echo "*************** TERRAGRUNT INIT *******************"
  echo "      At environment: ${tf_component}/${tf_env} "
  echo "**************************************************"
  if [ -d "$path" ]; then
    cd "$path" || exit
    terragrunt init || exit 11
    cd "$base_dir" || exit
  else
    echo "ERROR:  ${path} does not exist"
  fi
}

## Terragrunt plan function
tg_plan() {
  local path=$1
  local tf_env=$2
  local tf_component=$3
  echo "*************** TERRAGRUNT PLAN *******************"
  echo "      At environment: ${tf_component}/${tf_env} "
  echo "**************************************************"
  if [ ! -d "${tmp_plan}" ]; then
    mkdir "${tmp_plan}" || exit
  fi
  if [ -d "$path" ]; then
    cd "$path" || exit
    echo "hello"
    terragrunt plan --terragrunt-log-level debug -input=false -out "${tmp_plan}/${tf_component}-${tf_env}.tfplan" || exit 21
    cd "$base_dir" || exit
  else
    echo "ERROR:  ${tf_env} does not exist"
  fi
}

## Terragrunt apply function
tg_apply() {
  local path=$1
  local tf_env=$2
  local tf_component=$3
  echo "*************** TERRAGRUNT APPLY *******************"
  echo "      At environment: ${tf_component}/${tf_env} "
  echo "***************************************************"
  if [ -d "$path" ]; then
    cd "$path" || exit
    terragrunt apply -input=false -auto-approve "${tmp_plan}/${tf_component}-${tf_env}.tfplan" || exit 1
    cd "$base_dir" || exit
  else
    echo "ERROR:  ${path} does not exist"
  fi
}

## Terragrunt plan for all
tg_plan_all() {
  local env
  local component
  env="$(basename "$base_dir")"
  component="$(basename $(dirname $base_dir))"
  tg_init "$base_dir" "$env" "$component"
  tg_plan "$base_dir" "$env" "$component"
}

## Terragrunt apply for all
tg_apply_all() {
  local env
  local component
  env="$(basename "$base_dir")"
  component="$(basename $(dirname $base_dir))"
  tg_init "$base_dir" "$env" "$component"
  tg_plan "$base_dir" "$env" "$component"
  tg_apply "$base_dir" "$env" "$component"
}

echo "Inside wrapper script"
case "$action" in
  plan_all )
    tg_plan_all
    ;;
  apply_all )
    tg_apply_all
    ;;
  * )
    echo "unknown option: ${1}"
    exit 99
    ;;
esac
