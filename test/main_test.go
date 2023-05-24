package main_test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformDeployment(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "./",
		Vars: map[string]interface{}{
			"region": "us-west-2", // Cambia esto según tu región preferida de AWS
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Obtén la información de los recursos creados por Terraform
	actualVpc := aws.GetVpcById(t, terraform.Output(t, terraformOptions, "vpc_id"), "us-west-2")
	actualSubnet1 := aws.GetSubnetById(t, terraform.Output(t, terraformOptions, "public_subnet_1_id"), "us-west-2")
	actualSubnet2 := aws.GetSubnetById(t, terraform.Output(t, terraformOptions, "public_subnet_2_id"), "us-west-2")
	actualDbInstance := aws.GetDbInstanceById(t, terraform.Output(t, terraformOptions, "postgres_db_id"), "us-west-2")
	actualDbSecurityGroup := aws.GetSecurityGroupById(t, terraform.Output(t, terraformOptions, "postgres_sg_id"), "us-west-2")
	actualKubernetesCluster := aws.GetEksCluster(t, terraform.Output(t, terraformOptions, "my_cluster_name"), "us-west-2")
	actualKubernetesSecurityGroup := aws.GetSecurityGroupById(t, terraform.Output(t, terraformOptions, "kubernetes_sg_id"), "us-west-2")

	// Verifica que los recursos se hayan creado correctamente
	assert.Equal(t, "10.0.0.0/16", actualVpc.CidrBlock)
	assert.Equal(t, "10.0.1.0/24", actualSubnet1.CidrBlock)
	assert.Equal(t, "10.0.2.0/24", actualSubnet2.CidrBlock)
	assert.Equal(t, "ups-postgres-db", actualDbInstance.DBInstanceIdentifier)
	assert.Equal(t, "postgres_sg", actualDbSecurityGroup.GroupName)
	assert.Equal(t, "my-ups-cluster", actualKubernetesCluster.Name)
	assert.Equal(t, "kubernetes_sg", actualKubernetesSecurityGroup.GroupName)
}

func TestTerraformDeployment_SSHSecurityGroup(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "./",
		Vars: map[string]interface{}{
			"region": "us-west-2", // Cambia esto según tu región preferida de AWS
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Obtén el ID del grupo de seguridad creado por Terraform
	sshSecurityGroupID := terraform.Output(t, terraformOptions, "ssh_security_group_id")

	// Verifica que el grupo de seguridad se haya creado correctamente
	actualSSHSecurityGroup := aws.GetSecurityGroupById(t, sshSecurityGroupID, "us-west-2")

	assert.Equal(t, "ssh_access", actualSSHSecurityGroup.GroupName)
	assert.Equal(t, "Allow SSH access", actualSSHSecurityGroup.Description)
	assert.Equal(t, 1, len(actualSSHSecurityGroup.InboundRules))
	assert.Equal(t, 22, actualSSHSecurityGroup.InboundRules[0].FromPort)
	assert.Equal(t, 22, actualSSHSecurityGroup.InboundRules[0].ToPort)
	assert.Equal(t, "tcp", actualSSHSecurityGroup.InboundRules[0].Protocol)
	assert.Equal(t, "0.0.0.0/0", actualSSHSecurityGroup.InboundRules[0].CidrBlocks[0])
}
