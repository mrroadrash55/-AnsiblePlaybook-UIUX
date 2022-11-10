#!/bin/bash
input_customer="${1}"
input_lob="${2}"
cust_type="${3}"
owner_id="${4}"
resource_url="${5}"
resource_token="${6}"
BuildUser="${7}"
BuildNum="${8}"
job_name="${9}"
stage_name="${10}"
cust_folder="${input_customer}_UIUXREACT"
env="poc"
main_playbook="Create_UIUX_Runtime_API"
#echo "$BuildUser and $BuildNum"

#input_modes="${3}"
#input_interface="${4}"
echo "=============== Starting Shell Script ===================="
CDDB_IP="10.100.16.51"
CDDB_PORT="3400"
CDDB_USERNAME="relusr"
CDDB_PASSWORD="relusr*1"
CDDB_NAME="provisioningdb"
CDDB_DB_CONNECTIONS_TABLE="UIUX_HOST"
space_thrs='80'
ram_thrs='20'
#rand_port=`shuf -i 5000-5500 -n 1`
default_port='443'
cust_lower=`echo "$input_customer" | tr [:upper:] [:lower:]`
lob_lower=`echo "$input_lob" | tr [:upper:] [:lower:]`
domain_name="$env$cust_lower"
uiux="uiux"
underscore="_"
ecosys_name="$cust_lower$uiux$underscore$env"
host_name="$domain_name.solartis.net"
echo "DOMAIN NAME $domain_name"
echo "echosys name $ecosys_name"
group_name="UIUX_Server"

output_json=/opt/ProvisioningAPI_2022/Create_UIUX_Runtime_API/output.json
destn_invent=/opt/ProvisioningAPI_2022/Create_UIUX_Runtime_API/inventory.txt

#connection_mode="ssh"

if [[ "${3}" == "ISO" ]]
then
env_id=15
else
env_id=115
fi

select_ip(){
results=`mysql -N -u $CDDB_USERNAME -p$CDDB_PASSWORD -h $CDDB_IP -P $CDDB_PORT -D $CDDB_NAME -e "SELECT HOST FROM $CDDB_DB_CONNECTIONS_TABLE WHERE GROUP_NAME = '$group_name' AND ACTIVE='Y';" 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."`
echo '"IP":"'$results'",' >> $output_json
}


select_hostname(){
results=`mysql -N -u $CDDB_USERNAME -p$CDDB_PASSWORD -h $CDDB_IP -P $CDDB_PORT -D $CDDB_NAME -e "SELECT HOST_NAME FROM $CDDB_DB_CONNECTIONS_TABLE WHERE GROUP_NAME = '$group_name' AND ACTIVE='Y';" 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."`
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
  #echo i: $i
ip=`cat $output_json | grep -iw 'IP' | sed -e 's/"//g'  -e 's/\,//g' | awk -F':' '{print $2}' | awk -F' ' '{print $'$i'}'`
#echo "IP is:" $ip
hostnme=`cat $output_json | grep -iw 'HOSTNAME' | sed -e 's/"//g'  -e 's/\,//g'| awk -F':' '{print $2}' | awk -F' ' '{print $'$i'}'`
#echo "HOSTNAME is:" $hostnme
resource_check $ip
create_inventory $ip $hostnme
#pm2_free_port_check $ip
nginx_free_port_check $ip
#echo "Host $i is:-"   $(host_$i)"
  ((i=i+1))
done

}

create_inventory(){

echo "================= Inside Create Inventory Funtion !!! ==================="
#echo "IP =" $1
#echo "Username =" $2
#echo "Password =" $3
#echo "Connecion_Mode =" $connection_mode
echo "$2 ansible_host=$1" >> $destn_invent
}

resource_check()
{
#echo "IP =" $1
#echo "Username =" $2
#echo "Password =" $3

space=`ssh $1 df -h /home | awk 'NR==2 {print $5+0}'`
ram=`ssh $1 free -g | awk 'NR==2 {print $4}'`
echo "FOR VM::$1 SPACE::$space and RAM::$ram"
if [ $space -le $space_thrs ] && [ $ram -le $ram_thrs ];
then
echo "Available space is less than the threshold, So we can use this VM"
else
echo "Available space exceeds the threshold, so proceeding to create new VM"
#call VM creation playbook
exit 1
fi
}

pm2_free_port_check()
{
rand_port=`shuf -i 5000-5500 -n 1`
check_port=`ssh $1 sudo netstat -ltnp | grep -w $rand_port`
if [[ -z $check_port ]]
then
pm2_free_port_num=$rand_port
echo "PM2 Free port on $1 is: $pm2_free_port_num"
else
while [[ ! -z $check_port ]]
do
echo "$rand_port is already in use. So finding another port."
rand_port=`shuf -i 5000-5500 -n 1`
check_port=`ssh $1 sudo netstat -ltnp | grep -w $rand_port`
if [[ -z $check_port ]]
then
pm2_free_port_num=$rand_port
echo "PM2 Free port on $1 is: $pm2_free_port_num"
else
break
fi
done
fi

}

nginx_free_port_check()
{
rand_port=`shuf -i 5000-5500 -n 1`
check_port=`ssh $1 sudo netstat -ltnp | grep -w $rand_port`
if [[ -z $check_port ]]
then
nginx_free_port_num=$rand_port
echo "Nginx Free port on $1 is: $nginx_free_port_num"
else
while [[ ! -z $check_port ]]
do
echo "$rand_port is already in use. So finding another port."
rand_port=`shuf -i 5000-5500 -n 1`
check_port=`ssh $1 sudo netstat -ltnp | grep -w $rand_port`
if [[ -z $check_port ]]
then
nginx_free_port_num=$rand_port
echo "Nginx Free port on $1 is: $nginx_free_port_num"
else
break
fi
done
fi

}

jenkins_build_status()
{
query=`mysql -N -u relusr -prelusr*1 -h 10.100.16.51 -P 3400 -D provisioningdb -e "INSERT INTO JENKINS_BUILD_STATUS(OWNER_ID,CUSTOMER,LOB,JENKINS_BUILD_NUMBER,PIPELINE_NAME,TRIGGERED_BY,TRIGGERED_TIME) VALUES('$owner_id','$input_customer','$input_lob','$BuildNum','$job_name','$BuildUser','NOW()');" 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."`
 }

customer_ip_details()
{
echo "$input_customer and $ip"
query=`mysql -N -u relusr -prelusr*1 -h 10.100.16.51 -P 3400 -D provisioningdb -e "INSERT INTO CUSTOMER_IP_DETAILS_V3(CUSTOMERNAME,HOSTIP) VALUES('$input_customer','$ip');" 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."`
}




insert_playbook_list()
{
playbook_result_input=`mysql -N -u $CDDB_USERNAME -p$CDDB_PASSWORD -h $CDDB_IP -P $CDDB_PORT -D $CDDB_NAME -e "SELECT PLAYS_TO_EXECUTE FROM PLAYBOOK_EXECUTION_CONTROL WHERE TASK = 'Create_UIUX_Runtime_API' AND ENVIRONMENT = '$env';" 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."`
if [ -z "$playbook_result_input" ] ; then
echo "No entry found in PLAYBOOK_EXECUTION_CONTROL for Create_UIUX_Runtime_API"
exit 1
else
echo "Going to insert playbook lists in ProvisionDB"

#exe_order=l;
IFS=$',' read -ra playbook_result <<< $playbook_result_input

exe_order='1';
for playlist in ${playbook_result[@]}
do
 echo "NAME : $playlist"
 nowDate="$(date +"%d-%m-%y")";
 nowTime="$(date +"%H:%M")";
 start_date="$nowDate $nowTime";
 status='Started';
 query=`mysql -N -u relusr -prelusr*1 -h 10.100.16.51 -P 3400 -D provisioningdb -e "INSERT INTO PROVISIONING_PROGRESS_V2(OWNER_ID,CUSTOMER,LOB,ENVIRONMENT,MAIN_PLAY,SUB_PLAYS,EXECUTION_ORDER,STARTDATE,ENDDATE,STATUS,COMMENTS) VALUES('$owner_id','$input_customer','$input_lob','$env','Create_UIUX_Runtime_API','$playlist','$exe_order','$start_date','null','Started','$playlist execution started');" 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."`
 exe_order=$((exe_order+1));
done
fi

}





calling_playbook()
{
insert_playbook_list
echo "=============== CALLING THE MAIN PLAYBOOK ==============="
#ansible-playbook /home/UIUX/uiux_main_play.yml -i $destn_invent --extra-vars="ip=$free_ip default_port=$default_port free_port=$free_port_num cert_path=$cert_path cert_key=$cert_key customer=$input_customer domain_name=$domain_name"
ansible-playbook /opt/ProvisioningAPI_2022/Create_UIUX_Runtime_API/uiux_main_play.yml -i $destn_invent --extra-vars="ip=$ip pm2_free_port=$nginx_free_port_num nginx_free_port=$nginx_free_port_num customer=$input_customer domain_name=$domain_name customer_env=$ecosys_name env_id=$env_id own_id=$owner_id resource_url=$resource_url resource_token=$resource_token cust_folder=$cust_folder customer_name=$input_customer lob_name=$input_lob main_play=$main_playbook environment=$env" 





query=`mysql -N -u relusr -prelusr*1 -h 10.100.16.51 -P 3400 -D provisioningdb -e "INSERT INTO LOG_UIUX_DETAIL (CUSTOMER,LOB,CUSTOMER_TYPE,ENVIRONMENT,UIUX_IP,UIUX_PORT,UIUX_URL,CREATED_DATE) VALUES ('$input_customer','$input_lob','$cust_type','$env','$ip','$nginx_free_port_num','$host_name', NOW());" 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."`


echo "===========KINDLY ADD BELOW IN HOSTMAP==============="

echo "$ip $host_name"


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
jenkins_build_status
customer_ip_details
insert_playbook_list
calling_playbook
