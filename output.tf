output "ec2-ip"  {
  value = aws_instance.web.public_ip
}

output "db-ip-private" {
  value = aws_db_instance.this.address
}

output "db-conn" {
  value = "mysql -u${var.db.username} -p${var.db.password} -h ${aws_db_instance.this.address}"
}

output "db-proxy" {
  value = "mysql -u${var.db.username} -p${var.db.password} -h ${aws_db_proxy.this.endpoint}" 
}