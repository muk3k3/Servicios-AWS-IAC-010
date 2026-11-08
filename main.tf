module "kinesis_demo" {
  source       = "./modules/kinesis"
  project_name = var.project_name
}

module "firehose_demo" {
  source       = "./modules/firehose"
  project_name = var.project_name
}
