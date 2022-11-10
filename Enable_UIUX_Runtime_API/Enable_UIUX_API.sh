#!/bin/bash
input_customer="${1}"
input_lob="${2}"
env="poc"

echo "=============== Starting Shell Script ===================="
CDDB_IP="10.100.16.51"
CDDB_PORT="3400"
CDDB_USERNAME="relusr"
CDDB_PASSWORD="relusr*1"
CDDB_NAME="provisioningdb"
CDDB_UIUX_CONNECTIONS_TABLE="UIUX_HOST"
CDDB_UIUX_LOG_TABLE="LOG_UIUX_DETAIL"


cust_lower=`echo "$input_customer" | tr [:upper:] [:lower:]`
uiux="uiux"
underscore="_"
ecosys_name="$cust_lower$uiux$underscore$env"



group_name="UIUX_Server"

output_json=/opt/ProvisioningAPI_2022/Enable_UIUX_Runtime_API/output.json
destn_invent=/opt/ProvisioningAPI_2022/Enable_UIUX_Runtime_API/inventory.txt



select_ip(){
results=`mysql -N -u $CDDB_USERNAME -p$CDDB_PASSWORD -h $CDDB_IP -P $CDDB_PORT -D $CDDB_NAME -e "SELECT UIUX_IP FROM $CDDB_UIUX_LOG_TABLE WHERE CUSTOMER='$input_customer' AND LOB='$input_lob' LIMIT 1;" 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."`

echo '"IP":"'$results'",' >> $output_json
{
if [[ -z $results ]]; then
echo "NO SQL FILES FOUND"
exit 1
else
echo "SQL FOUND"
fi
}

}

select_hostname(){

results=`mysql -N -u $CDDB_USERNAME -p$CDDB_PASSWORD -h $CDDB_IP -P $CDDB_PORT -D $CDDB_NAME -e "SELECT HOST_NAME FROM $CDDB_UIUX_CONNECTIONS_TABLE WHERE HOST='$results' AND GROUP_NAME = '$group_name' AND ACTIVE='Y';" 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."`

echo '"HOSTNAME":"'$results'",' >> $output_json

}

fileclr()
{

>$output_json
>$destn_invent

}


extracting_json(){

host=`cat $output_json | grep -iw 'IP' | sed -e 's/"//g'  -e 's/\,//g'| awk -F':' '{print $2}'`

count=`cat $output_json | grep -iw 'IP' | sed -e 's/"//g'  -e 's/\,//g'| awk -F':' '{print $2}' | wc --word`
i=1
until [ $i -gt $count ]
do
  
ip=`cat $output_json | grep -iw 'IP' | sed -e 's/"//g'  -e 's/\,//g' | awk -F':' '{print $2}' | awk -F' ' '{print $'$i'}'`

hostnme=`cat $output_json | grep -iw 'HOSTNAME' | sed -e 's/"//g'  -e 's/\,//g'| awk -F':' '{print $2}' | awk -F' ' '{print $'$i'}'`


create_inventory $ip $hostnme


  ((i=i+1))
done

}

create_inventory(){

echo "================= Inside Create Inventory Funtion !!! ==================="

echo "$2 ansible_host=$1" >> $destn_invent
}


calling_playbook()
{

echo "=============== CALLING THE MAIN PLAYBOOK ==============="

ansible-playbook /opt/ProvisioningAPI_2022/Enable_UIUX_Runtime_API/Enable_main.yml -i $destn_invent --extra-vars="customer_env=$ecosys_name"

if [[ $? != 0 ]]
then
echo "Playbook execution got failed"
exit 1
fi
}


fileclr
select_ip
select_hostname
echo "["$group_name"]" >> $destn_invent
extracting_json
calling_playbook
