class YunionKeystone < Formula
  desc "Yunion Cloud Keystone Identity server"
  homepage "https://github.com/yunionio/onecloud.git"
  url "https://github.com/yunionio/onecloud.git",
    :tag      => "release/2.10.0"
  version_scheme 1
  head "https://github.com/yunionio/onecloud.git"

  depends_on "go" => :build

  def install
    ENV["GOPATH"] = buildpath

    (buildpath/"src/yunion.io/x/onecloud").install buildpath.children
    cd buildpath/"src/yunion.io/x/onecloud" do
      system "make", "cmd/keystone"
      bin.install "_output/bin/keystone"
      prefix.install_metafiles
    end

    (buildpath/"keystone.conf").write keystone_conf
    (etc/"keystone").install "keystone.conf"

    (buildpath/"rc_admin").write rc_admin
    (etc/"keystone/config").install "rc_admin"

    (buildpath/"sysadmin.yaml").write sysadmin_yaml
    (etc/"keystone/policies").install "sysadmin.yaml"

    (buildpath/"domainadmin.yaml").write domainadmin_yaml
    (etc/"keystone/policies").install "domainadmin.yaml"

    (buildpath/"member.yaml").write member_yaml
    (etc/"keystone/policies").install "member.yaml"

    (buildpath/"projectfa.yaml").write projectfa_yaml
    (etc/"keystone/policies").install "projectfa.yaml"

    (buildpath/"projectowner.yaml").write projectowner_yamlf
    (etc/"keystone/policies").install "projectowner.yaml"

    (buildpath/"projectsa.yaml").write projectsa_yamlf
    (etc/"keystone/policies").install "projectsa.yaml"

    (buildpath/"sysfa.yaml").write sysfa_yamlf
    (etc/"keystone/policies").install "sysfa.yaml"

    (buildpath/"syssa.yaml").write syssa_yamlf
    (etc/"keystone/policies").install "syssa.yaml"
  end

  def keystone_conf; <<~EOS
  address = '127.0.0.1'
  port = 5000
  admin_port = 35357
  sql_connection = 'mysql+pymysql://root:password@localhost:3306/keystone?charset=utf8'

  enable_ssl = true
  ssl_certfile = '#{etc}/keystone/keys/keystone-full.crt'
  ssl_keyfile = '#{etc}/keystone/keys/keystone.key'
  EOS
  end

  def sysadmin_yaml; <<~EOS
  # system wide administrator, root of the platform, can do anything
  projects:
    - system
  roles:
    - admin
  scope: system
  policy:
    *: allow
  EOS
  end

  def domainadmin_yaml; <<~EOS
  # project owner, allow do any with her project resources
  roles:
    - domainadmin
  scope: domain
  policy:
    *: allow
  EOS
  end

  def member_yaml; <<~EOS
  # rbac for normal user, not allow for delete
  scope: project
  policy:
    *:
      *:
        *: allow
        delete: deny
  EOS
  end

  def projectfa_yaml; <<~EOS
  # project finance administrator, allow any operation in meter
  roles:
    - fa
  scope: project
  policy:
    meter: allow
  EOS
  end

  def projectowner_yaml; <<~EOS
  # project owner, allow do any with her project resources
  roles:
    - project_owner
    - admin
  scope: project
  policy:
    *: allow
  EOS
  end

  def projectsa_yaml; <<~EOS
  # project system administrator, allow any operation in compute, image, k8s
  roles:
    - sa
  scope: project
  policy:
    compute: allow
    image: allow
    k8s: owner
  EOS
  end

  def sysfa_yaml; <<~EOS
  # system wide financial administrator, can do anything wrt billing&metering
  projects:
    - system
  roles:
    - fa
  scope: system
  policy:
    meter: allow
  EOS
  end

  def syssa_yaml; <<~EOS
  # system wide ops administrator, can do anything wrt compute/image/k8s
  projects:
    - system
  roles:
    - sa
  scope: system
  policy:
    compute: allow
    image: allow
    k8s: allow
  EOS
  end

  def rc_admin; <<~EOS
  export OS_USERNAME=sysadmin
  export OS_PASSWORD=sysadmin
  export OS_PROJECT_NAME=system
  export OS_DOMAIN_NAME=Default
  export OS_AUTH_URL=https://127.0.0.1:5000/v3
  export OS_REGION_NAME=Yunion
  #export YUNION_CERT_FILE=/opt/yunionsetup/config/keys/climc/climc-full.crt
  #export YUNION_KEY_FILE=/opt/yunionsetup/config/keys/climc/climc.key
  export YUNION_INSECURE=true
  EOS
  end


  def post_install
    (var/"log/keystone").mkpath
    (etc/"keystone/keys").mkpath
    (etc/"keystone/policies").mkpath
    (etc/"keystone/config").mkpath
  end


  def caveats; <<~EOS
    Change #{etc}/keystone/keystone.conf sql_connection options and create keystone database
    brew services start yunion-keystone

    source #{etc}/keystone/config/rc_admin
    climc policy-create domainadmin #{etc}/keystone/policies/domainadmin.yaml
    climc policy-create member #{etc}/keystone/policies/member.yaml
    climc policy-create projectfa #{etc}/keystone/policies/projectfa.yaml
    climc policy-create projectowner #{etc}/keystone/policies/projectowner.yaml
    climc policy-create projectsa #{etc}/keystone/policies/projectsa.yaml
    climc policy-create sysadmin #{etc}/keystone/policies/sysadmin.yaml
    climc policy-create sysfa #{etc}/keystone/policies/sysfa.yaml
    climc policy-create syssa #{etc}/keystone/policies/syssa.yaml

  EOS
  end

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>KeepAlive</key>
      <true/>
      <key>RunAtLoad</key>
      <true/>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>ProgramArguments</key>
      <array>
        <string>#{opt_bin}/keystone</string>
        <string>--conf</string>
        <string>#{etc}/keystone/keystone.conf</string>
        <string>--auto-sync-table</string>
      </array>
      <key>WorkingDirectory</key>
      <string>#{HOMEBREW_PREFIX}</string>
      <key>StandardErrorPath</key>
      <string>#{var}/log/keystone/output.log</string>
      <key>StandardOutPath</key>
      <string>#{var}/log/keystone/output.log</string>
    </dict>
    </plist>
  EOS
  end

  test do
    system "false"
  end
end
