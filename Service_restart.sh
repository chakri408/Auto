#!/bin/bash

INSTANCE_ID=$1
ELBNAME=$2
Instance_state=InService
SSH_USER=$3
EC2_USER=root

echo $Instance_state


Instance_IP=$(aws ec2 describe-instances --instance-id $INSTANCE_ID --query Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddresses[].PrivateIpAddress --output text)
ssh $SSH_USER@$Instance_IP "/usr/bin/sudo su $EC2_USER -c 'aws s3 cp s3://ll-bundles/cservice/chservice.sh /tmp'"
ssh $SSH_USER@$Instance_IP "/usr/bin/sudo su $EC2_USER -c 'cd /opt/cservice/conf && touch maint; echo -e "maint file was touched " && ls -l'"

until [ $Instance_state == "OutOfService" ]

do

sleep 4

Instance_state=$(aws elb describe-instance-health --load-balancer-name $ELBNAME --instances $INSTANCE_ID --query InstanceStates[].State --output text)

if [  $Instance_state == "OutOfService" ] 
then

   echo "Instance is out of service, application before restart"
   ssh $SSH_USER@$Instance_IP "/usr/bin/sudo su $EC2_USER -c 'ps -ef|grep mpadmin|grep -v root'"
   echo "Instance is out of service, restarting the application"
   ssh $SSH_USER@$Instance_IP "/usr/bin/sudo su $EC2_USER -c 'sh /tmp/chservice.sh restart'"
   sleep 4
   echo -e "\nApplication is up and running"
   ssh $SSH_USER@$Instance_IP "/usr/bin/sudo su $EC2_USER -c 'ps -ef|grep mpadmin|grep -v root'"
   echo -e "\nRemoving maint file"
   ssh $SSH_USER@$Instance_IP "/usr/bin/sudo su $EC2_USER -c 'cd /opt/cservice/conf && rm maint; echo -e "maint file was removed" && ls -l'"

   until [ $Instance_state = "InService" ]
   do
   sleep 4
   Instance_state=$(aws elb describe-instance-health --load-balancer-name $ELBNAME --instances $INSTANCE_ID --query InstanceStates[].State --output text)
   count=0
   if [  $Instance_state = "InService" ]
    then
      echo "Instance is in service; Everything back to normal" 
      exit 0
   else
      echo "Instance is out of Service; looping until Instance is InService" 
      count=`expr $count + 1`
      if [ $count -ge 5 ]
         then
         echo "Something went wrong, Instance is still OutOfService"
         exit 1
      fi 
      
   fi
   done

else 

echo "Still Instance is in service; looping"

fi

done

