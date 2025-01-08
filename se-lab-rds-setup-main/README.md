# lab-rds-setup
Creates a PostgreSQL db instance on RDS with sample data.  Sample data is the classic Northwind DB

- Make sure you update the file terraform.tfvars with appropriate values.  In particular, ensure that resource tags are properly updated. 

- Authenticate to AWS using env variables or SSO 
```bash
export AWS_ACCESS_KEY_ID="anaccesskey"
export AWS_SECRET_ACCESS_KEY="asecretkey"
export AWS_SESSION_TOKEN="aSessionToken"
```

## Database Bootstrapping
This Terraform deployment creates and populates the following databases:

* Northwind
* Netflix
* Chinook
* Pagila
* Lego

The source of the databases other than Northwind is https://github.com/neondatabase-labs/postgres-sample-dbs

### Make sure you have psql in your path.  This is required for to populate your new DB with sample data.

If you do not have local Postgres installation on your Mac, install libpq client to ensure that local client is installed to connect to the database:

```zsh
brew install libpq
brew link --force libpq
```

## S3 Bucket
Want an S3 Bucket with Sample Data?
https://github.com/ray-ryjewski-cyera/lab-s3-setup.git
