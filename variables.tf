variable "db" {
  type = object({
    username = string
    password = string
    })
}

variable "kmsDefault" {
  type = string
  description = "arn of aws/secretsmanager default key"
}