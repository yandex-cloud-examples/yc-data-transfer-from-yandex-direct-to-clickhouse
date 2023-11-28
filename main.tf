# Создания random-string
resource "random_string" "random" {
  length              = 4
  special             = false
  upper               = false 
}


# Create a Yandex VPC
resource "yandex_vpc_network" "example-vpc" {
  name      = "example-vpc-${random_string.random.result}"
#   zone           = "ru-central1-c"
#   network_id     = yandex_vpc_network.cluster-net.id
}

resource "yandex_vpc_subnet" "example-subnet" {
  folder_id           = var.folder_id
  count               = 3
  name                = "app-example-subnet-${element(var.network_names, count.index)}"
  zone                = element(var.zones, count.index)
  network_id          = yandex_vpc_network.example-vpc.id
  v4_cidr_blocks      = [element(var.app_cidrs, count.index)]
}

# rules for clickhouse to be available publicly
resource "yandex_vpc_default_security_group" "example-ch-sg" {
  network_id = yandex_vpc_network.example-vpc.id

  ingress {
    description    = "HTTPS (secure)"
    port           = 8443
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "clickhouse-client (secure)"
    port           = 9440
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow all egress cluster traffic"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Создание service account
resource "yandex_iam_service_account" "example-sa" {
  folder_id           = var.folder_id
  name                = "example-sa-${random_string.random.result}"
}

# Создание статического ключа для service account
resource "yandex_iam_service_account_static_access_key" "example-sa-sk" {
  service_account_id  = yandex_iam_service_account.example-sa.id
}

# Назначение прав на service account
resource "yandex_resourcemanager_folder_iam_binding" "admin" {
  folder_id           = var.folder_id
  role                = "admin"

  members = [
    "serviceAccount:${yandex_iam_service_account.example-sa.id}",
  ]
}

# Create Yandex Object Storage bucket
resource "yandex_storage_bucket" "example-bucket" {
  bucket              = "example-bucket-${random_string.random.result}"
  access_key = yandex_iam_service_account_static_access_key.example-sa-sk.access_key
  secret_key = yandex_iam_service_account_static_access_key.example-sa-sk.secret_key
}

resource "yandex_lockbox_secret_version" "first_version" {
  secret_id = "${yandex_lockbox_secret.obj_storage_secret.id}"
  entries {
    key        = "secret_key"
    text_value = yandex_iam_service_account_static_access_key.example-sa-sk.secret_key
  }
  entries {
    key        = "access_key"
    text_value = yandex_iam_service_account_static_access_key.example-sa-sk.access_key
  }
    entries {
    key        = "direct_token"
    text_value = var.direct_token
  }
}

# saves access_key and secret_key into Lockbox in order to pass it later to Yandex Cloud Function
resource "yandex_lockbox_secret" "obj_storage_secret" {
  name                = "obj_storage_secret"
  description         = "Saves access_key and secret_key + token into Lockbox in order to pass it later to Yandex Cloud Function"
  folder_id           = var.folder_id
}



# # Create a Yandex Cloud Function
resource "yandex_function" "example-function" {
  name        = "example-function"
  user_hash = "example-function-hash"
  folder_id   = var.folder_id
  runtime     = "python39"
  entrypoint  = "example.foo"
  memory = "128"
  execution_timeout ="100"
  service_account_id = yandex_iam_service_account.example-sa.id
  content {
    zip_filename = var.path_to_zip_cf
    }
  secrets {
    id                   = "${yandex_lockbox_secret.obj_storage_secret.id}"
    version_id           = yandex_lockbox_secret_version.first_version.id
    key                  = "access_key"
    environment_variable = "AWS_ACCESS_KEY_ID"
  }

  secrets {
    id                   = "${yandex_lockbox_secret.obj_storage_secret.id}"
    version_id           = yandex_lockbox_secret_version.first_version.id
    key                  = "secret_key"
    environment_variable = "AWS_SECRET_ACCESS_KEY"
  }

    secrets {
    id                   = "${yandex_lockbox_secret.obj_storage_secret.id}"
    version_id           = yandex_lockbox_secret_version.first_version.id
    key                  = "direct_token"
    environment_variable = "TOKEN"
  }
  environment = {
        BUCKET = yandex_storage_bucket.example-bucket.bucket
    }
}

# Create Yandex ClickHouse Managed Database
resource "yandex_mdb_clickhouse_cluster" "example-cluster" {
  name      = "example-cluster"
  environment = "PRODUCTION"
  network_id = yandex_vpc_network.example-vpc.id
  security_group_ids = [yandex_vpc_default_security_group.example-ch-sg.id]

  clickhouse {
    resources {
        resource_preset_id = "s2.micro"
        disk_type_id = "network-ssd"
        disk_size = 32
    }
  }

  host {
    type = "CLICKHOUSE"
    zone = "ru-central1-a"
    subnet_id = yandex_vpc_subnet.example-subnet[0].id
    assign_public_ip = true
  }

    database  {
    name = var.database_name
    }
  
  user {
    name     = var.clickhouse_user
    password = var.clickhouse_password
    permission {
        database_name = var.database_name
    }
  }
}

resource "yandex_datatransfer_endpoint" "yandex-mdb-clickhouse-endpoint" {
  name = "yandex-mdb-clickhouse-endpoint"
  settings {
    clickhouse_target {
      security_groups = [yandex_vpc_default_security_group.example-ch-sg.id]
      subnet_id       = yandex_vpc_subnet.example-subnet[0].id
      connection {
        connection_options {
          mdb_cluster_id = yandex_mdb_clickhouse_cluster.example-cluster.id
          database       = element([for database in yandex_mdb_clickhouse_cluster.example-cluster.database: database.name], 0)
          user           = element([for user in yandex_mdb_clickhouse_cluster.example-cluster.user: user.name], 0)
          password {
            raw = element([for user in yandex_mdb_clickhouse_cluster.example-cluster.user: user.password], 0)
          }
        }
      }
    }
  }
}

