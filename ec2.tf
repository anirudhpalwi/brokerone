

resource "aws_instance" "brokerone" {
  ami                         = var.ami_id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true

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
    dnf install -y git curl wget unzip ruby postgresql15

    curl -fsSL https://rpm.nodesource.com/setup_24.x | bash -
    dnf install -y nodejs-2:24.21.0-1nodesource
    dnf install -y python3-dnf-plugin-versionlock
    dnf versionlock add nodejs

    systemctl enable amazon-ssm-agent || true
    systemctl start amazon-ssm-agent || true

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

resource "aws_eip" "brokerone" {
  domain = "vpc"

  tags = {
    Name = "brokerone-dev-eip"
  }
}

resource "aws_eip_association" "brokerone" {
  instance_id   = aws_instance.brokerone.id
  allocation_id = aws_eip.brokerone.id
}
