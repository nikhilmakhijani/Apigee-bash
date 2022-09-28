import os
import sys
import json
import hcl
import argparse

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

def write_json_file(file,data):
    jsondata=json.dumps(data,indent=2)
    write_file(file,jsondata)

def parse_terraform_vars(file):
    check_path(file)
    with open(file, 'r') as fp:
        obj = hcl.load(fp)
    return obj

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_file", help="Location to Tfvars file",
                        type=str,required=True)
    parser.add_argument("--output_file", help="Location to Store Output",
                        type=str,required=True)
    args = parser.parse_args()
    input_file = args.input_file
    output_file = args.output_file
    input_data = parse_terraform_vars(input_file)
    write_json_file(output_file,input_data)

if __name__ == '__main__' :
    main()
