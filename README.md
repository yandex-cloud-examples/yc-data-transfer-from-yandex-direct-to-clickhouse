# Получение данных кампаний из Yandex Direct и их загрузка через Object Storage в Clickhouse


## Version

**Version-1.0**

Изменения:
- Добавлена версия для публикации


## Описание решения
Решение позволяет собрать данные из Yandex Direct в формате JSON, преобразовать в parquet на промежуточном хранилище object storage и затем загрузить в Clickhouse:
- [Yandex Direct](https://yandex.ru/dev/direct/doc/examples-v5/python3-requests-campaigns.html)
- [Yandex Cloud Functions](https://cloud.yandex.ru/docs/functions/)
- [Yandex Data Transfer](https://cloud.yandex.ru/docs/data-transfer/)
- [Yandex Object Storage](https://cloud.yandex.ru/services/storage)
- [Yandex Managed Service for ClickHouse](https://cloud.yandex.ru/docs/managed-clickhouse/)
- [Yandex Virtual Private Cloud](https://cloud.yandex.ru/docs/vpc/)
- [Yandex Identity and Access Management](https://cloud.yandex.ru/services/iam)
- [Yandex Lockbox](https://cloud.yandex.ru/docs/lockbox/)


## Что делает решение
- ☑️ Разворачивает Yandex Object Storage, Yandex Managed Service for Clickhouse, эндпоинт для Yandex Data Transfer, Yandex Cloud functions, Lockbox, Yandex Virtual Private Cloud. Создает сервисный аккаунт
- ☑️ С помощью Yandex Cloud Functions отправляется запрос в Yandex Direct через python requests, результат преобразуется из JSON в Parquet и загружается в Yandex Object Storage
- ☑️ С помощью Yandex Data Transfer загружаются преобразованные данные из Yandex Object Storage в Yandex Managed Service for Clickhouse

## Схема решения
<img width="786" alt="image" src="https://github.com/yandex-cloud-examples/yc-data-transfer-from-yandex-direct-to-clickhouse/blob/main/architecture.jpg">


## Установка решения с помощью Terraform 
### Шаги 0, 1, 2, 3, 4, 7-11 выполняются вручную

0. Настройте аккаунт в яндекс директе и подготовьте токен, а также данные для выгрузки (можно через песочницу)
   
1. Создайте сервисный аккаунт (https://cloud.yandex.ru/docs/iam/quickstart-sa#create-sa)

2. Создайте авторизованный ключ для вашего сервисного аккаунта и запишите его в файл (https://cloud.yandex.ru/docs/iam/quickstart-sa#run-operation-from-sa, шаги 1 и 2)

3. Клонируйте себе данный репозиторий

4. Заполните variables.tf (folder_id, cloud_id, service_account_key_file, direct_token, path_to_zip_cf (здесь будет путь из п3 к zip архиву на локальной машине)) 

5. Выполните `$ terraform init` (если нужно установить terraform, то https://cloud.yandex.ru/docs/tutorials/infrastructure-management/terraform-quickstart#from-hashicorp-site)

6. Выполните `$ terraform apply` и подождите, пока произойдет поднятие сервисов (если возникают ошибки - смотрите логи)

7. Запустите выполнение Cloud Function (через тестирование - запустить тест). В object storage появится файл в формате parquet из полученного из Yandex Direct JSON
   
8. Cоздайте эндпоинт в Data Transfer для object storage:

- Bucket = возьмите из созданного object storage
- AWS_KEYS = возьмите из Lockbox
- endpoint = https://storage.yandexcloud.net
- zone = ru-central1
- схема: {"Id": "int64", "Name": "string"}
- таблица = возьмите название из созданного parquet файла (например, 6a1eed08da13444886d705231c213ced.snappy.parquet)
- результирующая схема:
Id: Int64
Name: String

9. Создайте Data Transfer с использованием двух новых эндпоинтов (источник object storage, приемник clickhouse) - остальные настройки по умолчанию

10.   Запустите Data Transfer (активировать)

11.   Проверьте наличие новых данных в Clickhouse  (https://cloud.yandex.ru/docs/managed-clickhouse/operations/connect)