terraform {
  backend "s3" {
    bucket       = "apex-sync-tfstate-456441406929-eu-west-1"
    key          = "terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}