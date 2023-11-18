#!/bin/bash

for proj in $(gcloud projects list --format="get(projectId)"); do
    echo "[*] scraping project $proj"

    enabled=$(gcloud services list --project "$proj" | grep "Cloud Functions API")

    if [ -z "$enabled" ]; then
	continue
    fi


    for func_region in $(gcloud functions list --quiet --project "$proj" --format="value[separator=','](NAME,REGION)"); do
        func="${func_region%%,*}"
        region="${func_region##*,}"
        ACL="$(gcloud functions get-iam-policy "$func" --project "$proj" --region "$region")"

        all_funcs="$(echo "$ACL")"

        if [ -z "$all_funcs" ]
        then
              :
        else
              echo "$proj: $func"
        fi

    done
done
