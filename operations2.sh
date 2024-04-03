# #!/bin/bash
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


firstTrans=true
firstVerTrans=true


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
        echo ${transitions[@]} > demo
        jsontrans=$(cat demo) ;;
    "2")
        noneFlag=false
        versionFlag=true
        class=$(echo $lowerclass | tr a-z A-Z)
        if [ $firstVerTrans == true ]
        then
            firstVerTrans=false
            newItem={\"NoncurrentDays\":"$days",\"StorageClass\":\"$class\",\"NewerNoncurrentVersions\":"$ver"}
        else
            newItem=,{\"NoncurrentDays\":"$days",\"StorageClass\":\"$class\",\"NewerNoncurrentVersions\":"$ver"}
        fi
        len=${#vertransitions[@]}
        vertransitions+=($newItem)
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


if [ $noneFlag == true ]
then
    echo "No Operation chosen hence no lifecycle poilcy"
    exit 1
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

if [ $transitionFlag == true ]
then
    transitionString="\"Transitions\": [
                        $jsontrans
                    ]"
fi

if [ $versionFlag == true ]
then
    if [ $expFlag == true ]
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
    if [ $versionFlag == true ]
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
    if [ $versionExpFlag == true ]
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


# echo "{
#     \"Rules\": [
#         {
#             \"ID\": \"$policy_name\",
#             \"Filter\": {
#                 \"Prefix\": \"$pre\"
#             },
#             \"Status\": \"Enabled\",
#             $transitionString$expString$versionString$versionExpString$abortString
#         }
#     ]
# }" > S_lifecycle.json

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
    list=()
    for i in $existing
    do
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
# content=$(cat ./S_lifecycle.json | jq '.[]')
# list=()
# for i in $content
# do
#     if [ ! $i == '[' ]
#     then 
#         if [ ! $i == ']' ]
#         then
#             list+=($i)
#         fi
#     fi
# done
# len=${#list[@]}
# if [ $(($len - 1)) -eq 0 ]
# then 
#     new="
#         {
#             \"ID\": \"policy-d\",
#             \"Filter\": {
#                 \"Prefix\": \"\"
#             },
#             \"Status\": \"Enabled\",
#             \"Expiration\": {
#                     \"Days\": 2000
#                   }
#         }"
# else
#     new=",
#         {
#             \"ID\": \"policy-d\",
#             \"Filter\": {
#                 \"Prefix\": \"\"
#             },
#             \"Status\": \"Enabled\",
#             \"Expiration\": {
#                     \"Days\": 2000
#                   }
#         }"
# fi
# list+=($new)
# newlist=${list[@]}
# # echo $newlist
# echo "
# [
#     {
#         \"Rules\": [
#             $newlist
#         ]
#     }
# ]" > S_lifecycle.json

aws s3api put-bucket-lifecycle-configuration --bucket $name --lifecycle-configuration file://S_lifecycle.json
echo "Configured lifecycle for bucket $name with following rules"
aws s3api get-bucket-lifecycle-configuration --bucket $name 
