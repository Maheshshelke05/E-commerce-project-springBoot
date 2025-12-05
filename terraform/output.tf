output "ec2_public_ip" {
  value = aws_instance.ecom_ec2.public_ip
}

output "ec2_public_dns" {
  value = aws_instance.ecom_ec2.public_dns
}

output "rds_endpoint" {
  value = aws_db_instance.ecom_db.address
}

output "keypair_name" {
  value = aws_key_pair.mainkey.key_name
}
