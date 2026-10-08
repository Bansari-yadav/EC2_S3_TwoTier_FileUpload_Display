# Two-Tier File Upload & Display with Amazon EC2, S3, and IAM Roles

**Student:** Bansari Yadav  
**NetID:** byadav1  
**Course:** Cloud Computing

## 1. Project Overview

This project demonstrates a two-tier file upload and display system deployed on AWS using two EC2 instances, Amazon S3, and IAM roles.

The first EC2 instance runs an Uploader application that accepts text files and saves their content to Amazon S3. The second EC2 instance runs a Viewer application that retrieves the stored content from S3 and displays it in a browser.

The two applications communicate indirectly through S3 rather than through a direct connection.

## 2. AWS Services Used

- **Amazon EC2:** Runs the Uploader and Viewer applications.
- **Amazon S3:** Stores the shared text file.
- **AWS IAM:** Provides separate access permissions for each application.
- **EC2 Launch Templates:** Store instance configuration and user-data scripts.
- **User Data:** Installs and starts the applications during instance initialization.

## 3. Project Architecture

```text
        User / Web Browser
                |
       -------------------
       |                 |
       v                 v
  Uploader EC2      Viewer EC2
       |                 ^
       | PutObject       | GetObject
       v                 |
       ------ Amazon S3 --
              shared.txt
```

The Uploader writes the shared file to S3, and the Viewer reads it. This separates upload functionality from display functionality.

## 4. Project Folder Structure

```text
EC2_S3_TwoTier_FileUpload_Display/
|
|-- lab03/
|   |-- uploader-app/
|   |-- viewer-app/
|
|-- screenshots/
|   |-- SS1_Folder_Structure.png
|   |-- SS2_Upload_Success.png
|   |-- SS3_File_Too_Large.png
|   |-- SS4_Invalid_File.png
|   |-- SS5_Viewer.png
|   |-- SS7_Launch_Templates.png
|   |-- SS8_Template_Versions.png
|   |-- SS9A_Uploader_IAM.png
|   |-- SS9B_Viewer_IAM.png
|   |-- SS10_EC2_Deployment.png
|   |-- SS11_Cleanup.png
|
|-- create_app_stack.sh
|-- delete_app_stack.sh
|-- .env.example
|-- .gitignore
|-- README.md
```

## 5. Implementation Steps

### Step 1 — Prepare the Applications

Created separate Uploader and Viewer applications using Node.js and Express.

The Uploader handles file uploads, while the Viewer retrieves and displays previously uploaded content.

![Application Folder Structure](screenshots/SS1_Folder_Structure.png)

### Step 2 — Configure Amazon S3

Configured Amazon S3 as shared storage between the two EC2 instances.

The applications use a common S3 object named `shared.txt`.

### Step 3 — Configure IAM Permissions

Created separate IAM roles for the two applications to follow the principle of least privilege.

**Uploader IAM Role**
- Permits `s3:PutObject` on the shared object.
- Allows the Uploader to save text content to S3.

![Uploader IAM Policy](screenshots/SS9A_Uploader_IAM.png)

**Viewer IAM Role**
- Permits `s3:GetObject` on the shared object.
- Permits `s3:ListBucket` on the associated bucket.
- Allows the Viewer to retrieve and display the uploaded text.

![Viewer IAM Policy](screenshots/SS9B_Viewer_IAM.png)

### Step 4 — Create EC2 Launch Templates

Created launch templates for the Uploader and Viewer EC2 instances.

The launch templates include instance configuration and user-data scripts used to install and start the applications.

![EC2 Launch Templates](screenshots/SS7_Launch_Templates.png)

The Uploader launch template also has multiple versions.

![Launch Template Versions](screenshots/SS8_Template_Versions.png)

### Step 5 — Deploy the Application

Used the `create_app_stack.sh` script to provision the required AWS resources and launch EC2 instances.

The deployment output includes the public IP addresses used to access the applications.

![EC2 Deployment](screenshots/SS10_EC2_Deployment.png)

### Step 6 — Test the Uploader Application

Tested the Uploader with valid and invalid files.

**Test 1: Successful Text File Upload**

Uploaded a supported text file successfully.

![Successful Upload](screenshots/SS2_Upload_Success.png)

**Test 2: File Size Validation**

Attempted to upload a file exceeding the 1 MB limit. The application rejected it.

![File Too Large](screenshots/SS3_File_Too_Large.png)

**Test 3: File Type Validation**

Attempted to upload a file that was not a `.txt` file. The application rejected it.

![Invalid File Type](screenshots/SS4_Invalid_File.png)

### Step 7 — Verify the Viewer Application

Opened the Viewer application to confirm that it could retrieve and display text stored in Amazon S3.

![Viewer Application](screenshots/SS5_Viewer.png)

The viewer displaying updated text is an additional verification case, but its screenshot was not available in the original screenshot checklist.

### Step 8 — Clean Up AWS Resources

Ran the `delete_app_stack.sh` script to clean up the resources created for this lab.

Cleaning up unused resources helps prevent unnecessary AWS charges.

![Cleanup Output](screenshots/SS11_Cleanup.png)

## 6. Security Considerations

Several AWS security practices are demonstrated in this project:

- Separate IAM roles for the Uploader and Viewer.
- Limited S3 permissions based on application responsibilities.
- IAM instance profiles instead of hardcoded AWS access keys.
- Configuration placeholders stored in `.env.example`.
- Sensitive environment files excluded using `.gitignore`.

## 7. Challenges and Learning Outcomes

This project helped me understand how multiple EC2 instances can work together using a shared AWS service.

Some important learning outcomes were:

- Understanding how EC2 user-data automates application setup.
- Configuring S3 permissions for different application roles.
- Testing file upload restrictions and error handling.
- Using launch templates to manage EC2 configuration.
- Deploying and cleaning up AWS resources using shell scripts.

## 8. Conclusion

This lab demonstrates how AWS EC2, S3, and IAM can be combined to build a simple two-tier application.

By separating uploading and viewing into different instances, the system demonstrates component separation and shared cloud storage. The project also provides practical experience with IAM permissions, launch templates, application testing, and resource cleanup.

## 9. Repository Files

- [Uploader and Viewer Application](lab03/)
- [Create AWS Stack Script](create_app_stack.sh)
- [Delete AWS Stack Script](delete_app_stack.sh)
- [Environment Configuration Example](.env.example)
- [Screenshots](screenshots/)

**Note:** All application screenshots are from the completed lab. AWS resources were cleaned up after testing.

