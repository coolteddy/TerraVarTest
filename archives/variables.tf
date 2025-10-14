/*variable "access_key" {
  description = "AWS access key"
}

variable "secret_key" {
  description = "AWS secret access key"
}*/

variable "key_name" {
  description = "My Existing AWS key pair"
  default = "test-keypair"
}
