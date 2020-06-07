provider "aws" {
        /*access_key = "${var.access_key}"
        secret_key = "${var.secret_key}"*/
	region = "eu-west-1"
        shared_credentials_file  = "$HOME/.aws/credentials"
        profile = "own_aws"
}

resource "aws_instance" "web" {
    ami = "ami-f9dd458a"
    instance_type = "t2.micro"
    key_name = "MyMacKey"
    security_groups = ["${aws_security_group.sshac.name}"]
    tags {
        Name = "HelloWorld"
    }
}


resource "aws_security_group" "sshac" {
  name = "sshac"
  description = "Allow ssh inbound traffic"

  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }
}
