import sys
import os
import json
import argparse

def read_file(file):
    if os.path.exists(file):
        with open(file) as fl:
            data=fl.read()
            return data
    else:
        print('ERROR : File {} doesnt exist .'.format(file))
        sys.exit(1)

def check_path(file):
    path_dir = '/'.join(file.split('/')[:-1])
    if os.path.exists(path_dir):
        if os.path.exists(file):
            print('INFO : File {} already exists ! overwriting it !!! '.format(file))
    else:
        print('ERROR : Path {} doesnt exist .'.format(path_dir))
        sys.exit(1)

def write_file(file,data):
    check_path(file)
    with open(file,'w') as fl:
        fl.write(data)

def parse_json(file):
    data=read_file(file)
    try:
        json_data=json.loads(data)
        return json_data
    except json.decoder.JSONDecodeError:
        print('ERROR : File {} is not valid JSON'.format(file))
        sys.exit(1)

def get_component_envs(input,component):
    envs=[]
    for i in input[component]['env']:
        envs.append(i)
    return envs


def get_custom_envs(input):
    envs=[]
    synchronizer_envs=get_component_envs(input,'synchronizer')
    runtime_envs=get_component_envs(input,'runtime')
    udca_envs=get_component_envs(input,'udca')
    envs.extend(synchronizer_envs)
    envs.extend(runtime_envs)
    envs.extend(udca_envs)
    return list(set(envs))
    

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_file", help="Location to old input_file",
                        type=str,required=True)
    args = parser.parse_args()
    input_file = args.input_file
    input_data = parse_json(input_file)
    envs=get_custom_envs(input_data)
    print(" ".join(envs))

if __name__ == '__main__' :
    main()

---------------------------------------------------------------

# Generate yaml

import sys
import os
import json
import yaml
import jinja2
import argparse

def read_file(file):
    if os.path.exists(file):
        with open(file) as fl:
            data=fl.read()
            return data
    else:
        print('ERROR : File {} doesnt exist .'.format(file))
        sys.exit(1)

def check_path(file):
    path_dir = '/'.join(file.split('/')[:-1])
    if os.path.exists(path_dir):
        if os.path.exists(file):
            print('INFO : File {} already exists ! overwriting it !!! '.format(file))
    else:
        print('ERROR : Path {} doesnt exist .'.format(path_dir))
        sys.exit(1)


def write_file(file,data):
    check_path(file)
    with open(file,'w') as fl:
        fl.write(data)

def parse_json(file):
    data=read_file(file)
    try:
        json_data=json.loads(data)
        return json_data
    except json.decoder.JSONDecodeError:
        print('ERROR : File {} is not valid JSON'.format(file))
        sys.exit(1)

def read_jinja_template(template_file,template_path):
    templateLoader = jinja2.FileSystemLoader(searchpath=template_path)
    templateEnv = jinja2.Environment(loader=templateLoader)
    template = templateEnv.get_template(template_file)
    return template

def print_yaml(data):
    print(yaml.dump(yaml.load(data, Loader=yaml.FullLoader)))

def write_yaml(file,data):
    check_path(file)
    with open(file, 'w') as outfile:
        yaml.dump(
            yaml.load(data, Loader=yaml.FullLoader), 
            outfile, 
            default_flow_style=False
        )

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--primary_cassandra_dc_name", help="Cassandra Primary Datacenter Name",
                        type=str,required=True)
    parser.add_argument("--apigee_org", help="Name of Apigee CRD Org",
                        type=str,required=True)
    parser.add_argument("--output_file", help="Location to store overrides.yaml file",
    type=str,required=True)
    parser.add_argument("--template_location", help="Absolute Location Having jinja temaplate",
    type=str,required=True)
    parser.add_argument('--pretty_print', dest='pretty_print', required=False,action='store_true')
    args = parser.parse_args()
    template=read_jinja_template('datareplication.yaml',args.template_location)
    outputText = template.render({
        'apigee_org' : args.apigee_org,
        'cassandra_source_dc' : args.primary_cassandra_dc_name
    })
    if args.pretty_print:
        write_yaml(args.output_file,outputText)
    else:
        write_file(args.output_file,outputText)

if __name__ == '__main__' :
    main()

------------------------------

import sys
import os
import json
import yaml
import jinja2
import argparse

def read_file(file):
    if os.path.exists(file):
        with open(file) as fl:
            data=fl.read()
            return data
    else:
        print('ERROR : File {} doesnt exist .'.format(file))
        sys.exit(1)

def check_path(file):
    path_dir = '/'.join(file.split('/')[:-1])
    if os.path.exists(path_dir):
        if os.path.exists(file):
            print('INFO : File {} already exists ! overwriting it !!! '.format(file))
    else:
        print('ERROR : Path {} doesnt exist .'.format(path_dir))
        sys.exit(1)


def write_file(file,data):
    check_path(file)
    with open(file,'w') as fl:
        fl.write(data)

def parse_json(file):
    data=read_file(file)
    try:
        json_data=json.loads(data)
        return json_data
    except json.decoder.JSONDecodeError:
        print('ERROR : File {} is not valid JSON'.format(file))
        sys.exit(1)

def read_jinja_template(template_file,template_path):
    templateLoader = jinja2.FileSystemLoader(searchpath=template_path)
    templateEnv = jinja2.Environment(loader=templateLoader)
    template = templateEnv.get_template(template_file)
    return template

def print_yaml(data):
    print(yaml.dump(yaml.load(data, Loader=yaml.FullLoader)))

def write_yaml(file,data):
    check_path(file)
    with open(file, 'w') as outfile:
        yaml.dump(
            yaml.load(data, Loader=yaml.FullLoader), 
            outfile, 
            default_flow_style=False
        )

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_file", help="Location to input_file",
                        type=str,required=True)
    parser.add_argument("--output_file", help="Location to store overrides.yaml file",
    type=str,required=True)
    parser.add_argument("--template_location", help="Absolute Location Having jinja temaplate",
    type=str,required=True)
    parser.add_argument('--pretty_print', dest='pretty_print', required=False,action='store_true')
    parser.add_argument('--second_region', dest='second_region', required=False,action='store_true')
    parser.add_argument("--cassandra_seed_host", help="Cassandra Seed Host IP",
                        type=str,required=False,default='')
    parser.add_argument("--custom_env", help="Environment Specific Custom Overrides",
                        type=str,required=False,default='')
    args = parser.parse_args()
    input_file = args.input_file
    custom_env = args.custom_env
    template=read_jinja_template('overrides.yaml',args.template_location)
    input_data = parse_json(input_file)
    input_data['custom_env'] = custom_env
    input_data['second_region']=args.second_region
    if args.second_region:
        cassandra_seed_host = args.cassandra_seed_host
        if cassandra_seed_host == '':
            input_data['cassandra_seed_host']=''
            print('INFO : Generating Overrides without Cassandra Seed Host')
        else:
            print('INFO : Generating Overrides with Cassandra Seed Host')
            input_data['cassandra_seed_host']=cassandra_seed_host
    outputText = template.render(input_data)
    if args.pretty_print:
        write_yaml(args.output_file,outputText)
    else:
        write_file(args.output_file,outputText)

if __name__ == '__main__' :
    main()

-----------------------------------------------------

import sys
import os
import json
import argparse
import subprocess
import shlex
from deepdiff import DeepDiff

def read_file(file):
    if os.path.exists(file):
        with open(file) as fl:
            data=fl.read()
            return data
    else:
        print('ERROR : File {} doesnt exist .'.format(file))
        sys.exit(1)

def check_path(file):
    path_dir = '/'.join(file.split('/')[:-1])
    if os.path.exists(path_dir):
        if os.path.exists(file):
            print('INFO : File {} already exists ! overwriting it !!! '.format(file))
    else:
        print('ERROR : Path {} doesnt exist .'.format(path_dir))
        sys.exit(1)

def write_file(file,data):
    check_path(file)
    with open(file,'w') as fl:
        fl.write(data)

def parse_json(file):
    data=read_file(file)
    try:
        json_data=json.loads(data)
        return json_data
    except json.decoder.JSONDecodeError:
        print('ERROR : File {} is not valid JSON'.format(file))
        sys.exit(1)

def are_dicts_different(dict1,dict2):
    diff = DeepDiff(dict1, dict2)
    if len(diff) > 0 :
        return True
    else:
        return False

def run_command(command):
    output,error=None,None
    command=shlex.split(command)
    p = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = p.communicate()
    if p.returncode != 0:
        error=stderr.decode('utf-8')
    else:
        output=stdout.decode('utf-8')
    return output,error
    
def check_diff(apigeectl_flag_map_data,old_input_data,new_input_data,kube_config):
    response = {}
    flags = []
    components = []
    if old_input_data['apigeectl_version'] != new_input_data['apigeectl_version'] :
        response['flags'] = ['upgrade']
        response['components'] = ['upgrade']
        return response
    for component in apigeectl_flag_map_data:
        if are_dicts_different(old_input_data[component],new_input_data[component]):
            components.append(component)
            if apigeectl_flag_map_data[component] == '--org' :
                flags.append('--org {}'.format(new_input_data['project_id']))
            else:
                flags.append(apigeectl_flag_map_data[component])
    command='kubectl get apigeeenv -n apigee -o=json --kubeconfig={}'.format(kube_config)
    output,error=run_command(command)
    if error is not None:
        print('ERROR : Unable to get Apigee envs from Cluster .')
        sys.exit(1)
    else:
        output=json.loads(output)
        apigee_envs=[ i['spec']['name'] for i in output['items'] ]

    env_del_check=list(set(apigee_envs) - set(new_input_data['apigee_environments'].keys()))
    env_add_check=list(set(new_input_data['apigee_environments'].keys()) - set(apigee_envs))

    if len(env_add_check) > 0 and len(env_del_check) > 0:
        print('ERROR : Env Change can either be Addition or Deletion only !!! ')
        sys.exit(1)

    if len(env_add_check) > 0:
        response['flags'] = ['add_env']
        response['components'] = env_add_check
        return response
    elif len(env_del_check) > 0 :
        response['flags'] = ['delete_env']
        response['components'] = env_del_check
        return response
    else:
        pass

    flags = list(set(flags))
    if '--settings virtualhosts' in flags and '--all-envs' in flags :
        flags.remove('--settings virtualhosts')
    response['flags'] = flags
    response['components'] = components
    return response

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--new_input_file", help="Location to old input_file",
                        type=str,required=True)
    parser.add_argument("--old_input_file", help="Location to newly generated input_file",
                        type=str,required=True)
    parser.add_argument("--apigeectl_flag_map", help="Location to apigeectl_flag_map.json",
                        type=str,required=True)
    parser.add_argument("--kube_config", help="Location to kube_config",
                        type=str,required=True)
    args = parser.parse_args()
    new_input_file = args.new_input_file
    old_input_file = args.old_input_file
    apigeectl_flag_map = args.apigeectl_flag_map
    kube_config = args.kube_config
    apigeectl_flags = {
        'flags' :'',
        'components' :'',
    }
    new_input_data = parse_json(new_input_file)
    old_input_data = parse_json(old_input_file)
    apigeectl_flag_map_data = parse_json(apigeectl_flag_map)
    apigeectl_flags=check_diff(apigeectl_flag_map_data,old_input_data,new_input_data,kube_config)
    output={
        'flags' :' '.join(apigeectl_flags['flags']),
        'components' :' '.join(apigeectl_flags['components']),
    }
    print(json.dumps(output))

if __name__ == '__main__' :
    main()

----------------------------------

PyYAML ==5.4.1
Jinja2==3.0.1
requests==2.25.1
deepdiff==5.5.0
prettytable==2.5.0

--------------------------------------

from email.policy import default
import sys
import os
import json
import re
import argparse
import subprocess
import shlex

errors =[]

def read_file(file):
    if os.path.exists(file):
        with open(file) as fl:
            data=fl.read()
            return data
    else:
        print('ERROR : File {} doesnt exist .'.format(file))
        sys.exit(1)

def check_path(file):
    path_dir = '/'.join(file.split('/')[:-1])
    if os.path.exists(path_dir):
        if os.path.exists(file):
            print('INFO : File {} already exists ! overwriting it !!! '.format(file))
    else:
        print('ERROR : Path {} doesnt exist .'.format(path_dir))
        sys.exit(1)


def write_file(file,data):
    check_path(file)
    with open(file,'w') as fl:
        fl.write(data)

def parse_json(file):
    data=read_file(file)
    try:
        json_data=json.loads(data)
        return json_data
    except json.decoder.JSONDecodeError:
        print('ERROR : File {} is not valid JSON'.format(file))
        sys.exit(1)

def run_command(command):
    output,error=None,None
    command=shlex.split(command)
    p = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = p.communicate()
    if p.returncode != 0:
        error=stderr.decode('utf-8')
    else:
        output=stdout.decode('utf-8')
    return output,error

def k8s_secret_exists(namespace,secret,kube_config,key=None):
    status=True
    msg=''
    command="kubectl get secret -n {} {} -o=json --kubeconfig={}".format(namespace,secret,kube_config)
    output,error=run_command(command)
    if error is not None:
        status=False
        if re.search('secrets.*not found',error) is not None:
            msg='ERROR : Secret {} doesnt exist in namespace  {}'.format(secret,namespace)
        else:
            msg='ERROR : {} '.format(error)
    else:
        if key is not None:
            output=json.loads(output)
            if key not in output['data'].keys():
                status=False
                msg='ERROR : Secret {} exists in namespace  {} , but key {} doesnt exist '.format(secret,namespace,key)
    return status,msg

def verify_gcp_sa_secret(input_data,kube_config):
    gcp_sa_secrets = [
        'udca_svc_account_secret',
        'synchronizer_svc_account_secret' ,
        'runtime_svc_account_secret' ,
        'mart_svc_account_secret' ,
        'logger_svc_account_secret' ,
        'metrics_svc_account_secret' ,
        'watcher_svc_account_secret'
    ]
    for each_sa in gcp_sa_secrets:
        each_status,each_msg=k8s_secret_exists('apigee',input_data[each_sa],kube_config,'client_secret.json')
        if not each_status:
            errors.append(each_msg)
        else:
            print('INFO: {} secret with key "client_secret.json"  is present in namespace apigee. '.format(each_sa))

def verify_cassandra_secret(input_data,kube_config):
    if input_data['cassandra_backup']['enabled']:
        if input_data['cassandra_backup']['service_account_secret'].strip() != '':
            each_status,each_msg=k8s_secret_exists(
                'apigee',
                input_data['cassandra_backup']['service_account_secret'],
                kube_config,
                'dbbackup_key.json'
            )
            if not each_status:
                errors.append(each_msg)
            else:
                print('INFO: cassandra_backup is enabled and  service_account_secret is verified . ')
        else:
            errors.append('ERROR : cassandra_backup is enabled but service_account_secret is not defined')
    else:
        print('INFO: cassandra_backup is not enabled ! ')

    if input_data['cassandra_restore']['enabled']:
        if input_data['cassandra_restore']['service_account_secret'].strip() != '':
            each_status,each_msg=k8s_secret_exists(
                'apigee',
                input_data['cassandra_restore']['service_account_secret'],
                kube_config,
                'dbbackup_key.json'
            )
            if not each_status:
                errors.append(each_msg)
            else:
                print('INFO: cassandra_restore is enabled and  service_account_secret is verified . ')
        else:
            errors.append('ERROR : cassandra_restore is enabled but service_account_secret is not defined')
    else:
        print('INFO: cassandra_restore is not enabled ! ')

def verify_ssl_secret(input_data,kube_config):
    ns='istio-system'
    keys=['cert','key']
    for _,gr_info in input_data['apigee_envgroups'].items():
        for sec_key in keys:
            each_status,each_msg=k8s_secret_exists(ns,gr_info['ssl_secret_ref'],kube_config,sec_key)
            if not each_status:
                errors.append(each_msg)
            else:
                print('INFO: {} secret with key "{}"  is present in namespace {}. '.format(gr_info['ssl_secret_ref'],sec_key,ns))
            if gr_info['tls_mode'] == 'MUTUAL':
                each_status,each_msg=k8s_secret_exists(ns,gr_info['ssl_secret_ref']+'-cacert',kube_config,'cacert')
                if not each_status:
                    errors.append(each_msg)
                else:
                    print('INFO: {} secret is present in namespace {}. '.format(gr_info['ssl_secret_ref']+'-cacert',ns))

def verify_multi_region(input_data):
    if input_data['is_multi_regional'] and len(input_data['kubeconfig_multi_path']) == 0 :
        errors.append('ERROR : When multi-region is enabled , "kubeconfig_multi_path" list cannot be be empty ')
    else:
        print('INFO: multi-region is enabled and kubeconfig_multi_path is provided .')

def validate_cassandra_param(input_data):
    if input_data['cassandra_backup']['enabled'] and input_data['cassandra_restore']['enabled'] :
        errors.append('ERROR : Please check if cassandra_backup &  cassandra_restore Cannot be enabled at the same time.')
    else:
        print('INFO: cassandra backup & restore are not enabled at same time .')

def get_component_envs(input,component):
    envs=[]
    for i in input[component]['env']:
        envs.append(i)
    return envs

def validate_custom_config(input_data):
    apigee_environments = list(input_data['apigee_environments'].keys())
    custom_envs=[]
    synchronizer_envs=get_component_envs(input_data,'synchronizer')
    runtime_envs=get_component_envs(input_data,'runtime')
    udca_envs=get_component_envs(input_data,'udca')
    custom_envs.extend(synchronizer_envs)
    custom_envs.extend(runtime_envs)
    custom_envs.extend(udca_envs)
    custom_envs = list(set(custom_envs))
    if len(set(custom_envs) - set(apigee_environments))> 0:
        errors.append('ERROR : Please check if all Environments defined in apigee_environments & synchronizer|runtime|udca .')
    else:
        print('INFO: apigee_environments & synchronizer|runtime|udca Env variables validated')

def validate_env_group(input_data):
    apigee_envgroups = input_data['apigee_envgroups']
    apigee_environments = input_data['apigee_environments']
    envs = []
    for _,v in apigee_envgroups.items():
        envs.extend(v['environments'])
    envs = list(set(envs))
    if not (sorted(apigee_environments) == sorted(envs)) :
        errors.append('ERROR : Please check if all Environments defined in apigee_environments & apigee_envgroups .')
    else:
        print('INFO: apigee_environments & apigee_envgroups variables validated')
    hostnames={}
    for _,v in apigee_envgroups.items():
        for host in v['hostnames']:
            if host in hostnames.keys():
                hostnames[host]+=1
            else:
                hostnames[host]=1
    for each_host,count in hostnames.items():
        if count > 1:
            errors.append('ERROR : Hostname : {} has been defined twice in input'.format(each_host))
        else:
            print('INFO: apigee_envgroups hostnames validated')


def is_apigee_installed(configmap,kube_config,namespace='default',key='install'):
    status=True
    command="kubectl get cm -n {} {} -o=json --kubeconfig={}".format(namespace,configmap,kube_config)
    output,error=run_command(command)
    if error is not None:
        if re.search('configmaps.*not found',error) is not None:
            status=False
        else:
            print('ERROR : {} '.format(error))
            sys.exit(1)
    else:
        if key is not None:
            output=json.loads(output)
            if key in output['data'].keys():
                if output['data'][key] == 'setupdone':
                    status=True
                else:
                    status=False
    return status

def check_env_updates(input_data,kube_config):
    apigee_envs=[]
    command='kubectl get apigeeenv -n apigee -o=json --kubeconfig={}'.format(kube_config)
    output,error=run_command(command)
    if error is not None:
        errors.append('ERROR : Unable to access Apigee envs CRD from Cluster .')
    else:
        output=json.loads(output)
        apigee_envs=[ i['spec']['name'] for i in output['items'] ]
    print(apigee_envs)
    env_del_check=list(set(apigee_envs) - set(input_data['apigee_environments'].keys()))
    env_add_check=list(set(input_data['apigee_environments'].keys()) - set(apigee_envs))
    if len(env_add_check) > 0 and len(env_del_check) > 0:
        errors.append('ERROR : Env Change can either be Addition or Deletion only !!! Addtion detected : {} & deletion Detected {}'.format(
            ' '.join(env_add_check),
            ' '.join(env_del_check)
        ))

def banner(msg=' OPERATION '):
    print('\n' + '#'*50 + msg + '#'*50 + '\n')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_file", help="Location to input_file",
                        type=str,required=True)
    args = parser.parse_args()
    input_file = args.input_file
    input_data = parse_json(input_file)
    validate_env_group(input_data)
    validate_custom_config(input_data)
    validate_cassandra_param(input_data)
    verify_multi_region(input_data)

    verify_gcp_sa_secret(input_data,input_data['kubeconfig_cl1_path'])
    verify_cassandra_secret(input_data,input_data['kubeconfig_cl1_path'])
    verify_ssl_secret(input_data,input_data['kubeconfig_cl1_path'])
    if is_apigee_installed('apigee-hybrid-install-status',input_data['kubeconfig_cl1_path']):
        check_env_updates(input_data,input_data['kubeconfig_cl1_path'])
    if input_data['is_multi_regional']:
        for each_kubeconfig in input_data['kubeconfig_multi_path']:
            verify_gcp_sa_secret(input_data,each_kubeconfig)
            verify_cassandra_secret(input_data,each_kubeconfig)
            verify_ssl_secret(input_data,each_kubeconfig)

    if len(errors) > 0:
        print('Fix the following errors in terraform.tfvars and re-run !!!! ')
        banner(' ERRORS ')
        print('\n'.join(set(errors)))
        banner(' ERRORS ')
        sys.exit(1)
    else:
        print('Terraform.tfvars have been validated')

if __name__ == '__main__' :
    main()

------------------------------


