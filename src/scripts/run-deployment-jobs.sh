#! /bin/bash
export PATH=$PATH:$HOME/bin

BASE_REPO_NAME=$(basename ${GITHUB_REPOSITORY})
CURRENT_BRANCH=${GITHUB_REF_NAME}

BASE_SPACE_NAME=${BASE_REPO_NAME}

CODE_PACKAGE_NAME=${BASE_REPO_NAME}


# Find deployment jobs
deploy=false
for job_file in $(find assets/.METADATA -name 'job.deploy*');do
    job_name=$(cat ${job_file} | jq -r .metadata.name)
    notebook_file=$(cat ${job_file} | jq -r .entity.job.configuration.file_ref)
    if [[ "${notebook_file}" != "" ]];then
        echo "Deployment python notebook ${notebook_file} found in deployment job ${job_name}"
        deploy=true
    fi
done

if ${deploy};then
    # Delete old artifacts
    rm -f /tmp/${CODE_PACKAGE_NAME}.zip

    # Create zip file from current directory
    zip -r /tmp/${CODE_PACKAGE_NAME}.zip *

    # Create space
    TS=$(date +"%Y%m%d%H%M%S")
    space_name=${BASE_SPACE_NAME}-${CURRENT_BRANCH}-${TS}
    echo "Creating space ${space_name}"
    space_id=$(cpdctl space create --name ${space_name} --output json --raw-output --jmes-query "metadata.id")
    echo "Space ${space_name} created with id ${space_id}"

    # Create code package in space
    echo "Creating code package ${CODE_PACKAGE_NAME} in space ${space_name}"
    cpdctl asset file upload --path code_package/${CODE_PACKAGE_NAME} \
        --file /tmp/${BASE_REPO_NAME}.zip \
        --space-id ${space_id}

    code_package_id=$(cpdctl code-package create \
        --file-reference code_package/${CODE_PACKAGE_NAME} \
        --name ${CODE_PACKAGE_NAME} \
        --space-id ${space_id} \
        --output json -j "metadata.asset_id" --raw-output)

    for job_file in $(find assets/.METADATA -name 'job.deploy*');do
        job_name=$(cat ${job_file} | jq -r .metadata.name)
        job_description=$(cat ${job_file} | jq -r .metadata.description)
        notebook_file=$(cat ${job_file} | jq -r .entity.job.configuration.file_ref)
        environment_id=$(cat ${job_file} | jq -r .entity.job.configuration.env_id)

        # Create job
        echo "Creating job ${job_name} with environment ${environment_id}"
        job_json='{
            "asset_ref": "%s", 
            "configuration": 
                {
                    "env_id": "%s", 
                    "env_variables": ["CURRENT_BRANCH=%s"], 
                    "entrypoint": "%s" }, 
            "description": "%s", 
            "name": "%s"
            }\n'
        job_submit_json=$(printf "${job_json}" "${code_package_id}" "${environment_id}" "${CURRENT_BRANCH}" "${notebook_file}" "${job_description}" "${job_name}")
        echo "Job submit JSON: ${job_submit_json}"

        job_id=$(cpdctl job create --job "${job_submit_json}" --space-id ${space_id} --output json -j "metadata.asset_id" --raw-output)
        if [ $? -ne 0 ];then
            echo "Error while creating job, exiting"
            echo "${job_id}"
            exit 1
        fi

        # Run job
        echo "Running job ${job_name}"
        job_run_id=$(cpdctl job run create --space-id ${space_id} --job-id ${job_id} --job-run '{}' --output json -j "metadata.asset_id" --raw-output)
        if [ $? -ne 0 ];then
            echo "Error while running job, exiting"
            echo "${job_run_id}"
            exit 2
        fi
    done

    # Delete temporary space
    echo "Deleting deployment space ${space_name}"
    cpdctl space delete --space-id ${space_id}

fi

echo "Finished"