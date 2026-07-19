<div align="center">

# 🌐 Automate Data Capture at Scale with Document AI: Challenge Lab || GSP367 🚀 

<img src="https://img.shields.io/badge/Google%20Cloud-%234285F4.svg?style=for-the-badge&logo=google-cloud&logoColor=white" alt="Google Cloud">
<img src="https://img.shields.io/badge/Document%20AI-4285F4?style=for-the-badge&logo=googlecloud&logoColor=white" alt="Document AI">
<img src="https://img.shields.io/badge/Bash_Scripting-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white" alt="Bash Script">

<br>

**A fully automated, one-click deployment script to solve the GSP367 Challenge Lab.**

*Last updated: July 2026*

</div>

---

## 📖 About This Repository

This repository contains an automated Bash script designed to instantly provision and configure the infrastructure required for the **"Automate Data Capture at Scale with Document AI"** challenge lab. 

Instead of manually navigating the Google Cloud Console, this script interacts directly with the Google Cloud SDK and REST APIs to deploy the entire document processing pipeline in minutes.

### 🏗️ Architecture Deployed:
1. **Cloud Storage Buckets:** Automatically provisions Input, Output, and Archive buckets.
2. **Document AI:** Programmatically creates a Form Parser Processor via REST API.
3. **BigQuery:** Sets up the necessary datasets and table schemas for structured data output.
4. **Cloud Run Functions (Gen 2):** Deploys a Python 3.9 serverless function, assigns IAM permissions, configures Eventarc triggers, and dynamically injects environmental variables.

---

## ⚠️ Disclaimer 

> **Educational Purpose Only:** This script and guide are provided strictly for educational purposes to help developers and cloud enthusiasts understand Google Cloud services, API management, and infrastructure-as-code automation. 
> 
> **Terms Compliance:** Always ensure compliance with Google Cloud Skills Boost / Qwiklabs terms of service. Before running the script, please review the code to familiarize yourself with the underlying commands and concepts. The aim is to enhance your learning experience — not to circumvent it.

---

---

## 🚀 Quick Start: Run in Cloud Shell

To execute the automated deployment, open your Google Cloud Shell terminal, copy the block below, and paste it to run the commands:

```bash
curl -LO https://raw.githubusercontent.com/saswatsubhransudev/Automate-Data-Capture-at-Scale-with-Document-AI-Challenge-Lab-GSP367/refs/heads/main/saswatsubhransu.sh && chmod +x saswatsubhransu.sh && ./saswatsubhransu.sh

