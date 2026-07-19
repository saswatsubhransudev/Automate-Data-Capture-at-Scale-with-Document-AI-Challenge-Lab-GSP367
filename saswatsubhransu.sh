#!/bin/bash

# Define color variables
BLACK_TEXT=$'\033[0;90m'
RED_TEXT=$'\033[0;91m'
GREEN_TEXT=$'\033[0;92m'
YELLOW_TEXT=$'\033[0;93m'
BLUE_TEXT=$'\033[0;94m'
MAGENTA_TEXT=$'\033[0;95m'
CYAN_TEXT=$'\033[0;96m'
WHITE_TEXT=$'\033[0;97m'

NO_COLOR=$'\033[0m'
RESET_FORMAT=$'\033[0m'

# Define text formatting variables
BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'

clear

# Welcome message
echo "${CYAN_TEXT}${BOLD_TEXT}===============================================${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}     Welcome to Saswat Subhransu's guides      ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}===============================================${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}            INITIATING EXECUTION...            ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}===============================================${RESET_FORMAT}"
echo

# Function to prompt user for input and export it as PROCESSOR
get_processor_input() {
    # Prompt user for input
    echo
    echo -n "${CYAN_TEXT}Enter the processor name: ${RESET_FORMAT}"
    read -r processor_input
    
    # Export the input as an environment variable
    export PROCESSOR="$processor_input"
    
    # Print confirmation
    echo
    echo "${GREEN_TEXT}Thanks for your input!${RESET_FORMAT}"
    echo
}

# Call the function
get_processor_input

# Step 1: Retrieve project details
echo "${CYAN_TEXT}Fetching Project Details...${RESET_FORMAT}"
export PROJECT_ID=$(gcloud config get-value core/project)
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export ZONE=$(gcloud compute instances list lab-vm --format 'csv[no-heading](zone)')
export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])")
export BUCKET_LOCATION=$REGION

# Step 2: Enable required Google Cloud services
echo "${BLUE_TEXT}Enabling Required Services...${RESET_FORMAT}"
gcloud services enable documentai.googleapis.com      
gcloud services enable cloudfunctions.googleapis.com  
gcloud services enable cloudbuild.googleapis.com    
gcloud services enable geocoding-backend.googleapis.com 
gcloud services enable eventarc.googleapis.com
gcloud services enable run.googleapis.com

# Step 3: Create a local directory and copy files
echo "${YELLOW_TEXT}Setting up local environment...${RESET_FORMAT}"
mkdir ./document-ai-challenge
gsutil -m cp -r gs://spls/gsp367/* \
  ~/document-ai-challenge/

# Step 4: Create a processor
echo "${MAGENTA_TEXT}Creating Processor...${RESET_FORMAT}"
ACCESS_TOKEN=$(gcloud auth application-default print-access-token)

curl -X POST \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "display_name": "'"$PROCESSOR"'",
    "type": "FORM_PARSER_PROCESSOR"
  }' \
  "https://documentai.googleapis.com/v1/projects/$PROJECT_ID/locations/us/processors"

# Step 5: Create Cloud Storage buckets
echo "${BLUE_TEXT}Creating Cloud Storage Buckets...${RESET_FORMAT}"
gsutil mb -c standard -l ${BUCKET_LOCATION} -b on \
 gs://${PROJECT_ID}-input-invoices
gsutil mb -c standard -l ${BUCKET_LOCATION} -b on \
 gs://${PROJECT_ID}-output-invoices
gsutil mb -c standard -l ${BUCKET_LOCATION} -b on \
 gs://${PROJECT_ID}-archived-invoices

# Step 6: Create BigQuery dataset and table
echo "${CYAN_TEXT}Setting up BigQuery Dataset and Table...${RESET_FORMAT}"
bq --location="US" mk -d \
    --description "Form Parser Results" \
    ${PROJECT_ID}:invoice_parser_results
    
cd ~/document-ai-challenge/scripts/table-schema/

bq mk --table \
invoice_parser_results.doc_ai_extracted_entities \
doc_ai_extracted_entities.json

cd ~/document-ai-challenge/scripts 

# Step 7: Grant IAM permissions
echo "${MAGENTA_TEXT}Granting IAM Permissions...${RESET_FORMAT}"
SERVICE_ACCOUNT=$(gcloud storage service-agent --project=$PROJECT_ID)

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$SERVICE_ACCOUNT \
  --role roles/pubsub.publisher

# Step 8: Set Cloud Function location and deploy function
echo "${BLUE_TEXT}Deploying Cloud Function...${RESET_FORMAT}"
export CLOUD_FUNCTION_LOCATION=$REGION

sleep 20

deploy_function() {
gcloud functions deploy process-invoices \
  --gen2 \
  --region=${CLOUD_FUNCTION_LOCATION} \
  --entry-point=process_invoice \
  --runtime=python39 \
  --service-account=${PROJECT_ID}@appspot.gserviceaccount.com \
  --source=cloud-functions/process-invoices \
  --timeout=400 \
  --env-vars-file=cloud-functions/process-invoices/.env.yaml \
  --trigger-resource=gs://${PROJECT_ID}-input-invoices \
  --trigger-event=google.storage.object.finalize \
  --service-account $PROJECT_NUMBER-compute@developer.gserviceaccount.com \
  --allow-unauthenticated
}

deploy_success=false

while [ "$deploy_success" = false ]; do
  if deploy_function; then
    echo "${GREEN_TEXT}Function deployed successfully.${RESET_FORMAT}"
    deploy_success=true
  else
    echo "${RED_TEXT}Deployment failed, retrying in 30 seconds...${RESET_FORMAT}"
    sleep 30
  fi
done

# Step 9: Fetch and update PROCESSOR_ID
echo "${CYAN_TEXT}Fetching Processor ID...${RESET_FORMAT}"
PROCESSOR_ID=$(curl -X GET \
  -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  -H "Content-Type: application/json" \
  "https://documentai.googleapis.com/v1/projects/$PROJECT_ID/locations/us/processors" | \
  grep '"name":' | \
  sed -E 's/.*"name": "projects\/[0-9]+\/locations\/us\/processors\/([^"]+)".*/\1/')

export PROCESSOR_ID

# Step 10: Update Cloud Function
echo "${BLUE_TEXT}Updating Cloud Function...${RESET_FORMAT}"
gcloud functions deploy process-invoices \
  --gen2 \
  --region=${CLOUD_FUNCTION_LOCATION} \
  --entry-point=process_invoice \
  --runtime=python39 \
  --source=cloud-functions/process-invoices \
  --timeout=400 \
  --trigger-resource=gs://${PROJECT_ID}-input-invoices \
  --trigger-event=google.storage.object.finalize \
  --update-env-vars=PROCESSOR_ID=${PROCESSOR_ID},PARSER_LOCATION=us,PROJECT_ID=${PROJECT_ID} \
  --service-account=$PROJECT_NUMBER-compute@developer.gserviceaccount.com


# Step 11: Upload invoices
echo "${MAGENTA_TEXT}Uploading Sample Invoices...${RESET_FORMAT}"
gsutil -m cp -r gs://cloud-training/gsp367/* \
~/document-ai-challenge/invoices gs://${PROJECT_ID}-input-invoices/

echo

# Function to display a random congratulatory message
function random_congrats() {
    MESSAGES=(
        "${GREEN_TEXT}Congratulations For Completing The Lab! Keep up the great work!${RESET_FORMAT}"
        "${CYAN_TEXT}Well done! Your hard work and effort have paid off!${RESET_FORMAT}"
        "${YELLOW_TEXT}Amazing job! You’ve successfully completed the lab!${RESET_FORMAT}"
        "${BLUE_TEXT}Outstanding! Your dedication has brought you success!${RESET_FORMAT}"
        "${MAGENTA_TEXT}Great work! You’re one step closer to mastering this!${RESET_FORMAT}"
        "${RED_TEXT}Fantastic effort! You’ve earned this achievement!${RESET_FORMAT}"
        "${CYAN_TEXT}Congratulations! Your persistence has paid off brilliantly!${RESET_FORMAT}"
        "${GREEN_TEXT}Bravo! You’ve completed the lab with flying colors!${RESET_FORMAT}"
        "${YELLOW_TEXT}Excellent job! Your commitment is inspiring!${RESET_FORMAT}"
        "${BLUE_TEXT}You did it! Keep striving for more successes like this!${RESET_FORMAT}"
        "${MAGENTA_TEXT}Kudos! Your hard work has turned into a great accomplishment!${RESET_FORMAT}"
        "${RED_TEXT}You’ve smashed it! Completing this lab shows your dedication!${RESET_FORMAT}"
        "${CYAN_TEXT}Impressive work! You’re making great strides!${RESET_FORMAT}"
        "${GREEN_TEXT}Well done! This is a big step towards mastering the topic!${RESET_FORMAT}"
        "${YELLOW_TEXT}You nailed it! Every step you took led you to success!${RESET_FORMAT}"
        "${BLUE_TEXT}Exceptional work! Keep this momentum going!${RESET_FORMAT}"
        "${MAGENTA_TEXT}Fantastic! You’ve achieved something great today!${RESET_FORMAT}"
        "${RED_TEXT}Incredible job! Your determination is truly inspiring!${RESET_FORMAT}"
        "${CYAN_TEXT}Well deserved! Your effort has truly paid off!${RESET_FORMAT}"
        "${GREEN_TEXT}You’ve got this! Every step was a success!${RESET_FORMAT}"
        "${YELLOW_TEXT}Nice work! Your focus and effort are shining through!${RESET_FORMAT}"
        "${BLUE_TEXT}Superb performance! You’re truly making progress!${RESET_FORMAT}"
        "${MAGENTA_TEXT}Top-notch! Your skill and dedication are paying off!${RESET_FORMAT}"
        "${RED_TEXT}Mission accomplished! This success is a reflection of your hard work!${RESET_FORMAT}"
        "${CYAN_TEXT}You crushed it! Keep pushing towards your goals!${RESET_FORMAT}"
        "${GREEN_TEXT}You did a great job! Stay motivated and keep learning!${RESET_FORMAT}"
        "${YELLOW_TEXT}Well executed! You’ve made excellent progress today!${RESET_FORMAT}"
        "${BLUE_TEXT}Remarkable! You’re on your way to becoming an expert!${RESET_FORMAT}"
        "${MAGENTA_TEXT}Keep it up! Your persistence is showing impressive results!${RESET_FORMAT}"
        "${RED_TEXT}This is just the beginning! Your hard work will take you far!${RESET_FORMAT}"
        "${CYAN_TEXT}Terrific work! Your efforts are paying off in a big way!${RESET_FORMAT}"
        "${GREEN_TEXT}You’ve made it! This achievement is a testament to your effort!${RESET_FORMAT}"
        "${YELLOW_TEXT}Excellent execution! You’re well on your way to mastering the subject!${RESET_FORMAT}"
        "${BLUE_TEXT}Wonderful job! Your hard work has definitely paid off!${RESET_FORMAT}"
        "${MAGENTA_TEXT}You’re amazing! Keep up the awesome work!${RESET_FORMAT}"
        "${RED_TEXT}What an achievement! Your perseverance is truly admirable!${RESET_FORMAT}"
        "${CYAN_TEXT}Incredible effort! This is a huge milestone for you!${RESET_FORMAT}"
        "${GREEN_TEXT}Awesome! You’ve done something incredible today!${RESET_FORMAT}"
        "${YELLOW_TEXT}Great job! Keep up the excellent work and aim higher!${RESET_FORMAT}"
        "${BLUE_TEXT}You’ve succeeded! Your dedication is your superpower!${RESET_FORMAT}"
        "${MAGENTA_TEXT}Congratulations! Your hard work has brought great results!${RESET_FORMAT}"
        "${RED_TEXT}Fantastic work! You’ve taken a huge leap forward today!${RESET_FORMAT}"
        "${CYAN_TEXT}You’re on fire! Keep up the great work!${RESET_FORMAT}"
        "${GREEN_TEXT}Well deserved! Your efforts have led to success!${RESET_FORMAT}"
        "${YELLOW_TEXT}Incredible! You’ve achieved something special!${RESET_FORMAT}"
        "${BLUE_TEXT}Outstanding performance! You’re truly excelling!${RESET_FORMAT}"
        "${MAGENTA_TEXT}Terrific achievement! Keep building on this success!${RESET_FORMAT}"
        "${RED_TEXT}Bravo! You’ve completed the lab with excellence!${RESET_FORMAT}"
        "${CYAN_TEXT}Superb job! You’ve shown remarkable focus and effort!${RESET_FORMAT}"
        "${GREEN_TEXT}Amazing work! You’re making impressive progress!${RESET_FORMAT}"
        "${YELLOW_TEXT}You nailed it again! Your consistency is paying off!${RESET_FORMAT}"
        "${BLUE_TEXT}Incredible dedication! Keep pushing forward!${RESET_FORMAT}"
        "${MAGENTA_TEXT}Excellent work! Your success today is well earned!${RESET_FORMAT}"
        "${RED_TEXT}You’ve made it! This is a well-deserved victory!${RESET_FORMAT}"
        "${CYAN_TEXT}Wonderful job! Your passion and hard work are shining through!${RESET_FORMAT}"
        "${GREEN_TEXT}You’ve done it! Keep up the hard work and success will follow!${RESET_FORMAT}"
        "${YELLOW_TEXT}Great execution! You’re truly mastering this!${RESET_FORMAT}"
        "${BLUE_TEXT}Impressive! This is just the beginning of your journey!${RESET_FORMAT}"
        "${MAGENTA_TEXT}You’ve achieved something great today! Keep it up!${RESET_FORMAT}"
        "${RED_TEXT}You’ve made remarkable progress! This is just the start!${RESET_FORMAT}"
    )

    RANDOM_INDEX=$((RANDOM % ${#MESSAGES[@]}))
    echo -e "${BOLD_TEXT}${MESSAGES[$RANDOM_INDEX]}"
}

# Display a random congratulatory message
random_congrats

echo -e "\n"  # Adding one blank line

cd

remove_files() {
    # Loop through all files in the current directory
    for file in *; do
        # Check if the file name starts with "gsp", "arc", or "shell"
        if [[ "$file" == gsp* || "$file" == arc* || "$file" == shell* ]]; then
            # Check if it's a regular file (not a directory)
            if [[ -f "$file" ]]; then
                # Remove the file and echo the file name
                rm "$file"
                echo "File removed: $file"
            fi
        fi
    done
}

remove_files

# Final message
echo
echo "${CYAN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}              LAB COMPLETED SUCCESSFULLY!              ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo
echo "${MAGENTA_TEXT}${BOLD_TEXT}✨ Thank you for using Saswat Subhransu's guides! ✨${RESET_FORMAT}"
echo "${BLUE_TEXT}${BOLD_TEXT}      Keep learning, keep building, keep growing.      ${RESET_FORMAT}"
echo "${CYAN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo
