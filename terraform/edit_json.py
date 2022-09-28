mport sys
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

def write_json(file,data):
    check_path(file)
    data=json.dumps(data,indent=2)
    write_file(file,data)


def edit_dict(data,key,value):
    query_array=[]
    query=key.split('.')
    for i in query:
        if i.isnumeric():
            query_array.append('[{}]'.format(i))
        else:
            query_array.append("['{}']".format(i))
    final_cmd = "data{}='{}'".format(''.join(query_array),value)
    try:
        exec(final_cmd)
    except KeyError:
        print('Error Editing Dict , as parent or intermedite key doesnt exist in {}'.format(key))
        return None
    return data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_file", help="Location to input_file",
                        type=str,required=True)
    parser.add_argument("--key", help="Key to Edit",
    type=str,required=True)
    parser.add_argument("--value", help="Value to Edit",
    type=str,required=True)
    args = parser.parse_args()
    input_file = args.input_file
    key = args.key
    value = args.value
    input_data = parse_json(input_file)
    edit_data=edit_dict(input_data,key,value)
    if edit_data is None:
        print('ERROR: Issue Editing file {}'.format(input_file))
        sys.exit(1)
    else:
        write_json(input_file,input_data)
    

if __name__ == '__main__' :
    main()
