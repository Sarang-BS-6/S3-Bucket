#!/bin/bash
echo "Enter the bucket name"
read name
echo "Enter the name of policy: "
read policy_name
echo "Enter the prefix to target the documents: "
read prefix

pre=""
if [ ${#prefix} -ge 1 ]
then 
    pre=$prefix
fi

transitions=()
vertransitions=()

expString=""
transitionString=""
versionString=""
versionExpString=""
abortString=""
expFlag=false
transitionFlag=false
versionFlag=false
versionExpFlag=false
abortFlag=false
noneFlag=true

stop=false
firstTrans=true
firstVerTrans=true

while [ $stop == false ]
do
    echo "Enter the choice:"
    echo " 
          1.Move current versions of objects between storage classes 
          2.Move noncurrent versions of objects between storage classes
          3.Expire current versions of objects
          4.Permanently delete noncurrent versions of objects
          5.Delete expired object delete markers or incomplete multipart uploads
          6.Exit
          "
    read option

    case $option in
    "1") 
        noneFlag=false
        transitionFlag=true
        echo "Enter the Transitions"
        cond=false
        while [ $cond == false ]
        do
             echo "Do you want to enter the transition yes or no"
             read choice
             case $choice in
             "yes") echo "Enter the days"
                    read days
                    echo "Enter the Storage class"
                    read lowerclass
                    class=$(echo $lowerclass | tr a-z A-Z)
                    if [ $firstTrans == true ]
                    then
                        firstTrans=false
                        newItem={\"Days\":"$days",\"StorageClass\":\"$class\"}
                    else
                        newItem=,{\"Days\":"$days",\"StorageClass\":\"$class\"}
                    fi
                    len=${#transitions[@]}
                    transitions+=($newItem)
                ;;
            "no")  cond=true ;;
            *) echo "Enter valid choice" 
            esac
        done

        echo ${transitions[@]} > demo
        jsontrans=$(cat demo) ;;
    "2")
        noneFlag=false
        versionFlag=true
        echo "Enter the version Transitions"
        cond=false
        while [ $cond == false ]
        do
            echo "Do you want to enter the transition yes or no"
            read choice
            case $choice in
            "yes") echo "Enter the days"
                read days
                echo "Enter the Storage class"
                read lowerclass
                class=$(echo $lowerclass | tr a-z A-Z)
                echo "Enter the versions to keep"
                read ver
                if [ $firstVerTrans == true ]
                then
                    firstVerTrans=false
                    newItem={\"NoncurrentDays\":"$days",\"StorageClass\":\"$class\",\"NewerNoncurrentVersions\":"$ver"}
                else
                    newItem=,{\"NoncurrentDays\":"$days",\"StorageClass\":\"$class\",\"NewerNoncurrentVersions\":"$ver"}
                fi
                len=${#vertransitions[@]}
                vertransitions+=($newItem)
                ;;
            "no")  cond=true ;;
            *) echo "Enter valid choice" 
            esac
        done

        echo ${vertransitions[@]} > demo
        verjsontrans=$(cat demo) ;;
    "3")
        noneFlag=false
        expFlag=true
        echo "Enter the expiration days"
        read expireDays ;;
    "4")
        noneFlag=false
        versionExpFlag=true
        echo "Enter the number of latest version to keep after expiration"
        read nover
        echo "Enter the days to expire old versions"
        read verexpireDays ;;
    "5") 
        noneFlag=false
        abortFlag=true
        echo "Enter the number of days after initiation for aborting incomplete multipart upload"
        read abort_multipart_days ;;
    "6")
        stop==true ;;
    *)
        echo "Enter the right choice" ;;
    esac
done

if [ $noneFlag == true ]
then
    echo "No Operation chosen hence no lifecycle poilcy"
    exit 1
fi



if [ $transitionFlag == true ]
then
    transitionString="\"Transitions\": [
                        $jsontrans
                    ]"
fi

if [ $expFlag == true ]
then
    if [ $transitionFlag == true ]
    then
        expString=",
            \"Expiration\": {
                \"Days\": $expireDays
            }"
    else
        expString="\"Expiration\": {
                    \"Days\": $expireDays
                  }"
    fi
fi

if [ $versionFlag == true ]
then
    if [ $expFlag == true || $transitionFlag == true ]
    then
        versionString=",
                \"NoncurrentVersionTransitions\": [
                    $verjsontrans
                ]"
    else
        versionString="\"NoncurrentVersionTransitions\": [
                         $verjsontrans
                      ]"
    fi
fi

if [ $versionExpFlag == true ]
then
    if [ $versionFlag == true || $expFlag == true || $transitionFlag == true ]
    then
        versionExpString=",
                    \"NoncurrentVersionExpiration\": {
                        \"NoncurrentDays\": $verexpireDays,
                        \"NewerNoncurrentVersions\": $nover
                    }"
    else
        versionExpString="\"NoncurrentVersionExpiration\": {
                            \"NoncurrentDays\": $verexpireDays,
                            \"NewerNoncurrentVersions\": $nover
                         }"
    fi
fi

if [ $abortFlag == true ]
then
    if [ $versionExpFlag == true || $versionFlag == true || $expFlag == true || $transitionFlag == true ]
    then
        abortString=",
                \"AbortIncompleteMultipartUpload\": {
                    \"DaysAfterInitiation\": $abort_multipart_days
                }"
    else
        abortString="\"AbortIncompleteMultipartUpload\": {
                        \"DaysAfterInitiation\": $abort_multipart_days
                    }"
    fi
fi

content=$(aws s3api get-bucket-lifecycle-configuration --bucket "$name" 2>&1)


if [[ "$content" == *"NoSuchLifecycleConfiguration"* ]];
then
    echo "{
            \"Rules\": [
                {
                    \"ID\": \"$policy_name\",
                    \"Filter\": {
                        \"Prefix\": \"$pre\"
                    },
                    \"Status\": \"Enabled\",
                    $transitionString$expString$versionString$versionExpString$abortString
                }
            ]
        }" > S_lifecycle.json

else
    echo $content > ./S_lifecycle.json
    existing=$(cat ./S_lifecycle.json | jq '.[]')
    echo $existing
    list=()
    for i in $existing
    do
        echo $i
        if [ ! $i == '[' ]
        then 
            if [ ! $i == ']' ]
            then
                list+=($i)
            fi
        fi
    done
    len=${#list[@]}
    if [ $(($len - 1)) -eq 0 ]
    then 
        new="
            {
                    \"ID\": \"$policy_name\",
                    \"Filter\": {
                        \"Prefix\": \"$pre\"
                    },
                    \"Status\": \"Enabled\",
                    $transitionString$expString$versionString$versionExpString$abortString
            }"
    else
        new=",
            {
                    \"ID\": \"$policy_name\",
                    \"Filter\": {
                        \"Prefix\": \"$pre\"
                    },
                    \"Status\": \"Enabled\",
                    $transitionString$expString$versionString$versionExpString$abortString
            }"
    fi
    list+=($new)
    newlist=${list[@]}
    # echo $newlist
    echo "
        {
            \"Rules\": [
                $newlist
            ]
        }" > S_lifecycle.json
#END
fi

aws s3api put-bucket-lifecycle-configuration --bucket $name --lifecycle-configuration file://S_lifecycle.json
echo "Configured lifecycle for bucket $name with following rules"
aws s3api get-bucket-lifecycle-configuration --bucket $name 