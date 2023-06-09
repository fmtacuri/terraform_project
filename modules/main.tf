# main.tf

# Configuración del proveedor de AWS
provider "aws" {
  region = "us-west-2"  # Cambia esto según tu región preferida de AWS
}

# Creación de un grupo de seguridad para permitir acceso SSH
resource "aws_security_group" "ssh_access" {
  name        = "ssh_access"
  description = "Allow SSH access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creación de una VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Creación de subredes públicas
# Cambia esto según tu zona de disponibilidad preferida
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-2a"  
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-west-2b"
  map_public_ip_on_launch = true
}

# Creación de subredes privadas
# Cambia esto según tu zona de disponibilidad preferida
resource "aws_subnet" "private_subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-west-2a" 
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-west-2b" 
}

# Creación de una tabla de enrutamiento para las subredes públicas
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_internet_gateway.id
  }
}

# Asociación de las subredes públicas con la tabla de enrutamiento pública
resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Creación de una puerta de enlace de internet
resource "aws_internet_gateway" "my_internet_gateway" {
  vpc_id = aws_vpc.my_vpc.id
}

# Creación de una instancia de base de datos RDS (PostgreSQL)
resource "aws_db_instance" "postgres_db" {
  identifier             = "ups-postgres-db"
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "12.6"
  instance_class         = "db.t2.micro"
  username               = "ups_admin"
  password               = "UpsTesis2023*"
  publicly_accessible   = false
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.postgres_sg.id]
  subnet_group_name      = aws_db_subnet_group.postgres_subnet_group.name
}

# Creación de un grupo de seguridad para la base de datos PostgreSQL
resource "aws_security_group" "postgres_sg" {
  name        = "postgres_sg"
  description = "Allow PostgreSQL access"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creación de un grupo de seguridad para el clúster de Kubernetes
resource "aws_security_group" "kubernetes_sg" {
  name        = "kubernetes_sg"
  description = "Allow Kubernetes access"

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creación de un clúster de Kubernetes (EKS)
resource "aws_eks_cluster" "my_cluster" {
  name       = "my-ups-cluster"
  role_arn   = aws_iam_role.cluster_role.arn
  version    = "1.21"
  vpc_config {
    subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
    security_group_ids = [aws_security_group.kubernetes_sg.id]
  }
}

# Creación de un rol de IAM para el clúster de Kubernetes
resource "aws_iam_role" "cluster_role" {
  name = "eks_cluster_role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# Asociación de políticas al rol del clúster de Kubernetes
resource "aws_iam_role_policy_attachment" "cluster_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster_role.name
}

# Asociación de políticas al rol del clúster de Kubernetes (opcional)
resource "aws_iam_role_policy_attachment" "cluster_autoscaler_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
  role       = aws_iam_role.cluster_role.name
}

# Creación de un grupo de subredes de base de datos
resource "aws_db_subnet_group" "postgres_subnet_group" {
  name       = "postgres_subnet_group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}
