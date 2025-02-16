# Getting campaign data from Yandex Direct and uploading it into ClickHouse through Object Storage

## Version

**Version-1.0**

### Changes

- Added a version for publication.

## About the solution

This solution exports your Yandex Direct data in JSON format, converts it to Parquet in an intermediate object storage, and then uploads the processed data into ClickHouse:
- [Yandex Direct](https://yandex.ru/dev/direct/doc/examples-v5/python3-requests-campaigns.html)
- [Yandex Cloud Functions](https://yandex.cloud/docs/functions/)
- [Yandex Data Transfer](https://yandex.cloud/docs/data-transfer/)
- [Yandex Object Storage](https://yandex.cloud/services/storage)
- [Yandex Managed Service for ClickHouse](https://yandex.cloud/docs/managed-clickhouse/)
- [Yandex Virtual Private Cloud](https://yandex.cloud/docs/vpc/)
- [Yandex Identity and Access Management](https://yandex.cloud/services/iam)
- [Yandex Lockbox](https://yandex.cloud/docs/lockbox/)

## Solution features

- Deploys Yandex Object Storage, Yandex Managed Service for ClickHouse, and an endpoint for Yandex Data Transfer, along with Yandex Cloud Functions, Yandex Lockbox, and Yandex Virtual Private Cloud. Creates a dedicated service account.
- With Yandex Cloud Functions, sends requests (using the `requests` Python library) to Yandex Direct, converting the result from JSON to Parquet and then uploading it into Yandex Object Storage.
- With Yandex Data Transfer, uploads the processed data from Yandex Object Storage into Yandex Managed Service for ClickHouse.

## Solution architecture

<img width="786" alt="image" src="https://github.com/yandex-cloud-examples/yc-data-transfer-from-yandex-direct-to-clickhouse/blob/main/architecture.jpg">

## Installing the solution with Terraform 

1. Set up your Yandex Direct account and prepare the appropriate token, along with the data to export (you can use sandbox for this purpose).

1. [Create a service account](https://yandex.cloud/docs/iam/quickstart-sa#create-sa).

1. [Create an authorized key for your service account and save it to a file](https://yandex.cloud/docs/iam/quickstart-sa#run-operation-from-sa) (see step 1 and step 2).

1. Clone this repository to your local machine.

1. In `variables.tf`, set the following variables: `folder_id`, `cloud_id`, `service_account_key_file`, `direct_token`, and `path_to_zip_cf` (here, specify the path to the ZIP archive on your local machine).

1. Run `$ terraform init` (to install Terraform, follow [this guide](https://yandex.cloud/docs/tutorials/infrastructure-management/terraform-quickstart#from-hashicorp-site)).

1. Run `$ terraform apply` and wait for the services to start up (if any errors occur, refer to the logs).

1. Run your cloud function (in the **Testing** tab, click **Run test**). In your object storage, a Parquet file will appear, created from the JSON data obtained from Yandex Direct.

1. In Yandex Data Transfer, create an endpoint for the object storage:

   - Bucket: From the created object storage.
   - AWS_KEYS: From your Lockbox.
   - endpoint = https://storage.yandexcloud.net
   - zone = ru-central1
   - Schema: {"Id": "int64", "Name": "string"}.
   - Table: Use the name from the created Parquet file, e.g., `6a1eed08da13444886d705231c213ced.snappy.parquet`.
   - Result schema:
     - Id: Int64
     - Name: String

1. Create a data transfer between the two new endpoints (Object Storage for source, ClickHouse for target), leaving other settings default.

1. Activate your data transfer.

1. [Check that your ClickHouse target now houses the new data](https://yandex.cloud/docs/managed-clickhouse/operations/connect).
