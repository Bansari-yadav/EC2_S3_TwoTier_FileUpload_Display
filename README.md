# Two-Tier File Upload & Display with EC2, S3, and IAM Roles

**Student:** Bansari Yadav  
**NetID:** byadav1  
**Course:** Cloud Computing

## Overview

This lab uses two independent EC2 instances with Node.js/Express applications, communicating indirectly through Amazon S3 object `shared.txt`. The Uploader accepts `.txt` files up to 1 MB. The Viewer retrieves and displays the stored content. Code is embedded in launch-template user-data, while IAM instance profiles provide AWS access.

## Files

- `lab03/uploader-app/` — Uploader code and dependencies
- `lab03/viewer-app/` — Viewer code and dependencies
- `create_app_stack.sh` — provision EC2, S3, IAM and launch templates
- `delete_app_stack.sh` — lab cleanup
- `.env.example` — safe configuration placeholders
- `screenshots/` — evidence from the completed lab

## Screenshot checklist

| ID | Evidence | Screenshot |
|---|---|---|
| SS1 | Local uploader/viewer folder structure | [View](screenshots/SS1_Folder_Structure.png) |
| SS2 | Successful upload | [View](screenshots/SS2_Upload_Success.png) |
| SS3 | Rejection of file over 1 MB | [View](screenshots/SS3_File_Too_Large.png) |
| SS4 | Rejection of non-.txt file | [View](screenshots/SS4_Invalid_File.png) |
| SS5 | Viewer displaying initial file | [View](screenshots/SS5_Viewer.png) |
| SS6 | Viewer displaying updated text | **Missing: not provided** |
| SS7 | Both EC2 launch templates | [View](screenshots/SS7_Launch_Templates.png) |
| SS8 | Multiple uploader launch-template versions | [View](screenshots/SS8_Template_Versions.png) |
| SS9A | Uploader IAM policy | [View](screenshots/SS9A_Uploader_IAM.png) |
| SS9B | Viewer IAM policy | [View](screenshots/SS9B_Viewer_IAM.png) |
| SS10 | EC2 deployment output and public IPs | [View](screenshots/SS10_EC2_Deployment.png) |
| SS11 | Cleanup output | [View](screenshots/SS11_Cleanup.png) |

**Note:** SS6 is not available. The lab has already been cleaned up; no resources have been redeployed to recreate screenshots.

## Why separate IAM roles?

The Uploader and Viewer have different responsibilities, so separate IAM roles follow the principle of least privilege. The Uploader is permitted to perform `s3:PutObject` only on `shared.txt`. The Viewer is permitted to perform `s3:GetObject` on `shared.txt` and `s3:ListBucket` on its bucket. This reduces unnecessary access and limits the impact of a compromised application.

## Why embed code in EC2 user-data?

Embedding the application code directly in EC2 user-data lets each instance reconstruct its files at startup without fetching code from Git or S3. Consequently, separate Git or S3 *code-delivery* credentials are not required; IAM permissions are still needed to access the shared S3 data object.

## Deployment and cleanup

The creation script provisions the S3 bucket, IAM roles/profiles, launch templates and EC2 instances and prints public IP addresses. The cleanup script attempts to terminate recorded instances and remove corresponding resources. The completion and instance termination evidence is provided in SS11.

**Security:** Never commit the actual `.env`, AWS credentials or private keys. These scripts are retained for documentation only; do not run them again just to collect screenshots.
