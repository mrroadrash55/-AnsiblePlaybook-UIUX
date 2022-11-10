build_trigger()
{
curl -X POST -u provision_apiuser:11b78f3078560ba38010a3e4b6f23861b3 -i 'http://10.100.16.53:8080/job/Demo_Sample/buildWithParameters?token=provision_auth&Customer=Allriskss&LOB=PL_Newui&Modes=TEST' > tmp.txt
location=`grep Location tmp.txt | awk '{print $NF}'`
echo "$location"
exit 1
curl -X POST -u provision_apiuser:11b78f3078560ba38010a3e4b6f23861b3 -i $location/api/json > tmp1.txt
number=`grep -o -P '(?<="number":).*(?=,"url)' tmp1.txt`
echo "Number : $number"
}

insert()
{

playbook_result_input=`mysql -N -u relusr -prelusr*1 -h 10.100.16.51 -P 3400 -D provisioningdb -e "SELECT PLAYS_TO_EXECUTE FROM PLAYBOOK_EXECUTION_CONTROL WHERE TASK = 'Create_UIUX_Runtime_API' AND ENVIRONMENT = 'sci';" 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."`

echo "$playbook_result_input"

if [ -z "$playbook_result_input" ] ; then
echo "No entry found in PLAYBOOK_EXECUTION_CONTROL for Create_UIUX_Runtime_API"
exit 1
else
echo "Going to insert playbook lists in ProvisionDB"

IFS=$',' read -ra playbook_result <<< $playbook_result_input

order=1;
for playlist in ${playbook_result[@]}
do
 echo "NAME : $playlist"
 query=`mysql -N -u relusr -prelusr*1 -h 10.100.16.51 -P 3400 -D provisioningdb -e "INSERT INTO PROVISIONING_PROGRESS_V2(OWNER_ID,CUSTOMER,LOB,ENVIRONMENT,MAIN_PLAY,SUB_PLAYS,EXECUTION_ORDER,STARTDATE,ENDDATE,STATUS,COMMENTS) VALUES('$owner_id','$input_customer','$input_lob','$env','Create_UIUX_Runtime_API','$playlist','$order','$start_date','null','Started','$playlist execution started');" 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."`
 order=$((order+1));
done
fi
}

build_trigger
