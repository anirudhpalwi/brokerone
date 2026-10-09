

resource "aws_instance" "brokerone" {
  ami                    = var.ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  # No public IP (Scrut: "Instance with a Public IP Address"). The instance runs
  # in a private subnet and reaches the internet (dnf/npm, SSM, CodeCommit, SES)
  # through the NAT gateway. Inbound is only port 5192 from the ALB SG; no SSH.
  associate_public_ip_address = false

  # Don't boot until the private subnet's NAT route exists; user_data needs internet.
  depends_on = [
    aws_nat_gateway.brokerone,
    aws_route_table_association.private_a,
    aws_network_acl.private,
  ]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # 2 GB swap so npm ci / next build don't get OOM-killed on t3.small
    if [ ! -f /swapfile ]; then
      fallocate -l 2G /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
    fi
    swapon /swapfile || true
    grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab

    dnf update -y
    # curl is already provided by curl-minimal on AL2023; installing "curl" conflicts with it
    dnf install -y git wget unzip ruby postgresql15

    curl -fsSL https://rpm.nodesource.com/setup_24.x | bash -
    dnf install -y nodejs-2:24.21.0-1nodesource
    dnf install -y python3-dnf-plugin-versionlock
    dnf versionlock add nodejs

    systemctl enable amazon-ssm-agent || true
    systemctl start amazon-ssm-agent || true

    # CodeDeploy agent (the deployment group finds this instance by its Application tag)
    cd /tmp
    wget -q https://aws-codedeploy-ap-south-1.s3.ap-south-1.amazonaws.com/latest/install
    chmod +x ./install
    ./install auto
    systemctl enable codedeploy-agent || true

    # CloudWatch agent; its config is restored by hand after a rebuild
    dnf install -y amazon-cloudwatch-agent

    mkdir -p /opt/brokerone-dev/BrokerOne/brokerone
    mkdir -p /etc/brokerone

    chown -R ec2-user:ec2-user /opt/brokerone-dev
    chown root:ec2-user /etc/brokerone
    chmod 750 /etc/brokerone

    cat >/etc/systemd/system/brokerone.service <<'SERVICE'
    [Unit]
    Description=BrokerOne Next.js Application
    After=network.target

    [Service]
    Type=simple
    User=ec2-user
    WorkingDirectory=/opt/brokerone-dev/BrokerOne/brokerone
    Environment=NODE_ENV=production
    EnvironmentFile=-/etc/brokerone/brokerone.env
    ExecStart=/usr/bin/npx next start -H 0.0.0.0 -p 5192
    Restart=always
    RestartSec=5

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
  EOF

  # user_data only runs on first boot; don't stop/start the running instance when it changes
  lifecycle {
    ignore_changes = [user_data]
  }

  tags = {
    Name        = "brokerone-dev-ec2"
    Application = "BrokerOne-Dev"
  }
}


