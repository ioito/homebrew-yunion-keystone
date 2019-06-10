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

    (buildpath/"logging.conf").write keystone_log_conf
    (etc/"keystone").install "logging.conf"

    (buildpath/"policy.json").write policy
    (etc/"keystone").install "policy.json"

    (buildpath/"keystone.paste.ini").write paste
    (etc/"keystone").install "keystone.paste.ini"

  end

  def paste; <<~EOS
  # Keystone PasteDeploy configuration file.

  [filter:debug]
  use = egg:oslo.middleware#debug

  [filter:request_id]
  use = egg:oslo.middleware#request_id

  [filter:build_auth_context]
  use = egg:keystone#build_auth_context

  [filter:token_auth]
  use = egg:keystone#token_auth

  [filter:json_body]
  use = egg:keystone#json_body

  [filter:cors]
  use = egg:oslo.middleware#cors
  oslo_config_project = keystone

  [filter:http_proxy_to_wsgi]
  use = egg:oslo.middleware#http_proxy_to_wsgi

  [filter:healthcheck]
  use = egg:oslo.middleware#healthcheck

  [filter:ec2_extension]
  use = egg:keystone#ec2_extension

  [filter:ec2_extension_v3]
  use = egg:keystone#ec2_extension_v3

  [filter:s3_extension]
  use = egg:keystone#s3_extension

  [filter:url_normalize]
  use = egg:keystone#url_normalize

  [filter:sizelimit]
  use = egg:oslo.middleware#sizelimit

  [filter:osprofiler]
  use = egg:osprofiler#osprofiler

  [app:public_service]
  use = egg:keystone#public_service

  [app:service_v3]
  use = egg:keystone#service_v3

  [app:admin_service]
  use = egg:keystone#admin_service

  [pipeline:public_api]
  # The last item in this pipeline must be public_service or an equivalent
  # application. It cannot be a filter.
  pipeline = healthcheck cors sizelimit http_proxy_to_wsgi osprofiler url_normalize request_id build_auth_context token_auth json_body ec2_extension public_service

  [pipeline:admin_api]
  # The last item in this pipeline must be admin_service or an equivalent
  # application. It cannot be a filter.
  pipeline = healthcheck cors sizelimit http_proxy_to_wsgi osprofiler url_normalize request_id build_auth_context token_auth json_body ec2_extension s3_extension admin_service

  [pipeline:api_v3]
  # The last item in this pipeline must be service_v3 or an equivalent
  # application. It cannot be a filter.
  pipeline = healthcheck cors sizelimit http_proxy_to_wsgi osprofiler url_normalize request_id build_auth_context token_auth json_body ec2_extension_v3 s3_extension service_v3

  [app:public_version_service]
  use = egg:keystone#public_version_service

  [app:admin_version_service]
  use = egg:keystone#admin_version_service

  [pipeline:public_version_api]
  pipeline = healthcheck cors sizelimit osprofiler url_normalize public_version_service

  [pipeline:admin_version_api]
  pipeline = healthcheck cors sizelimit osprofiler url_normalize admin_version_service

  [composite:main]
  use = egg:Paste#urlmap
  /v2.0 = public_api
  /v3 = api_v3
  / = public_version_api

  [composite:admin]
  use = egg:Paste#urlmap
  /v2.0 = admin_api
  /v3 = api_v3
  / = admin_version_api
  EOS
  end

  def policy; <<~EOS
  {
    "admin_required": "role:admin",
    "project_owner_required": "role:project_owner",
    "cloud_admin": "role:admin and (is_admin_project:True or domain_id:admin_domain_id)",
    "service_role": "role:service",
    "service_or_admin": "rule:admin_required or rule:service_role",
    "owner" : "user_id:%(user_id)s or user_id:%(target.token.user_id)s",
    "admin_or_owner": "(rule:admin_required and domain_id:%(target.token.user.domain.id)s) or rule:owner",
    "admin_and_matching_domain_id": "rule:admin_required and domain_id:%(domain_id)s",
    "service_admin_or_owner": "rule:service_or_admin or rule:owner",

    "default": "rule:admin_required",

    "identity:get_region": "",
    "identity:list_regions": "",
    "identity:create_region": "rule:cloud_admin",
    "identity:update_region": "rule:cloud_admin",
    "identity:delete_region": "rule:cloud_admin",

    "identity:get_service": "rule:admin_required",
    "identity:list_services": "rule:admin_required",
    "identity:create_service": "rule:cloud_admin",
    "identity:update_service": "rule:cloud_admin",
    "identity:delete_service": "rule:cloud_admin",

    "identity:get_endpoint": "rule:admin_required",
    "identity:list_endpoints": "rule:admin_required",
    "identity:create_endpoint": "rule:cloud_admin",
    "identity:update_endpoint": "rule:cloud_admin",
    "identity:delete_endpoint": "rule:cloud_admin",

    "identity:get_domain": "rule:cloud_admin or rule:admin_and_matching_domain_id or token.project.domain.id:%(target.domain.id)s",
    "identity:list_domains": "",
    "identity:create_domain": "rule:cloud_admin",
    "identity:update_domain": "rule:cloud_admin",
    "identity:delete_domain": "rule:cloud_admin",

    "admin_and_matching_target_project_domain_id": "rule:admin_required and domain_id:%(target.project.domain_id)s",
    "admin_and_matching_project_domain_id": "rule:admin_required and domain_id:%(project.domain_id)s",
    "identity:get_project": "rule:cloud_admin or rule:admin_and_matching_target_project_domain_id or project_id:%(target.project.id)s",
    "identity:list_projects": "rule:cloud_admin or rule:admin_and_matching_domain_id",
    "identity:list_user_projects": "rule:cloud_admin or rule:owner or rule:admin_and_matching_domain_id",
    "identity:create_project": "rule:cloud_admin or rule:admin_and_matching_project_domain_id",
    "identity:update_project": "rule:cloud_admin or rule:admin_and_matching_target_project_domain_id",
    "identity:delete_project": "rule:cloud_admin or rule:admin_and_matching_target_project_domain_id",

    "admin_and_matching_target_user_domain_id": "rule:admin_required and domain_id:%(target.user.domain_id)s",
    "admin_and_matching_user_domain_id": "rule:admin_required and domain_id:%(user.domain_id)s",
    "identity:get_user": "rule:cloud_admin or rule:admin_and_matching_target_user_domain_id or rule:owner",
    "identity:list_users": "",
    "identity:create_user": "rule:cloud_admin or rule:admin_and_matching_user_domain_id",
    "identity:update_user": "rule:cloud_admin or rule:admin_and_matching_target_user_domain_id",
    "identity:delete_user": "rule:cloud_admin or rule:admin_and_matching_target_user_domain_id",

    "admin_and_matching_target_group_domain_id": "rule:admin_required and domain_id:%(target.group.domain_id)s",
    "admin_and_matching_group_domain_id": "rule:admin_required and domain_id:%(group.domain_id)s",
    "identity:get_group": "rule:cloud_admin or rule:admin_and_matching_target_group_domain_id",
    "identity:list_groups": "rule:cloud_admin or rule:admin_and_matching_domain_id",
    "identity:list_groups_for_user": "rule:owner or rule:cloud_admin or rule:admin_and_matching_target_user_domain_id",
    "identity:create_group": "rule:cloud_admin or rule:admin_and_matching_group_domain_id",
    "identity:update_group": "rule:cloud_admin or rule:admin_and_matching_target_group_domain_id",
    "identity:delete_group": "rule:cloud_admin or rule:admin_and_matching_target_group_domain_id",
    "identity:list_users_in_group": "rule:cloud_admin or rule:admin_and_matching_target_group_domain_id",
    "identity:remove_user_from_group": "rule:cloud_admin or rule:admin_and_matching_target_group_domain_id",
    "identity:check_user_in_group": "rule:cloud_admin or rule:admin_and_matching_target_group_domain_id",
    "identity:add_user_to_group": "rule:cloud_admin or rule:admin_and_matching_target_group_domain_id",

    "identity:get_credential": "rule:admin_required",
    "identity:list_credentials": "rule:admin_required or user_id:%(user_id)s",
    "identity:create_credential": "rule:admin_required",
    "identity:update_credential": "rule:admin_required",
    "identity:delete_credential": "rule:admin_required",

    "identity:ec2_get_credential": "rule:admin_required or (rule:owner and user_id:%(target.credential.user_id)s)",
    "identity:ec2_list_credentials": "rule:admin_required or rule:owner",
    "identity:ec2_create_credential": "rule:admin_required or rule:owner",
    "identity:ec2_delete_credential": "rule:admin_required or (rule:owner and user_id:%(target.credential.user_id)s)",

    "identity:get_role": "rule:admin_required",
    "identity:list_roles": "rule:admin_required",
    "identity:create_role": "rule:cloud_admin",
    "identity:update_role": "rule:cloud_admin",
    "identity:delete_role": "rule:cloud_admin",

    "identity:get_domain_role": "rule:cloud_admin or rule:get_domain_roles",
    "identity:list_domain_roles": "rule:cloud_admin or rule:list_domain_roles",
    "identity:create_domain_role": "rule:cloud_admin or rule:domain_admin_matches_domain_role",
    "identity:update_domain_role": "rule:cloud_admin or rule:domain_admin_matches_target_domain_role",
    "identity:delete_domain_role": "rule:cloud_admin or rule:domain_admin_matches_target_domain_role",
    "domain_admin_matches_domain_role": "rule:admin_required and domain_id:%(role.domain_id)s",
    "get_domain_roles": "rule:domain_admin_matches_target_domain_role or rule:project_admin_matches_target_domain_role",
    "domain_admin_matches_target_domain_role": "rule:admin_required and domain_id:%(target.role.domain_id)s",
    "project_admin_matches_target_domain_role": "rule:admin_required and project_domain_id:%(target.role.domain_id)s",
    "list_domain_roles": "rule:domain_admin_matches_filter_on_list_domain_roles or rule:project_admin_matches_filter_on_list_domain_roles",
    "domain_admin_matches_filter_on_list_domain_roles": "rule:admin_required and domain_id:%(domain_id)s",
    "project_admin_matches_filter_on_list_domain_roles": "rule:admin_required and project_domain_id:%(domain_id)s",
    "admin_and_matching_prior_role_domain_id": "rule:admin_required and domain_id:%(target.prior_role.domain_id)s",
    "implied_role_matches_prior_role_domain_or_global": "(domain_id:%(target.implied_role.domain_id)s or None:%(target.implied_role.domain_id)s)",

    "identity:get_implied_role": "rule:cloud_admin or rule:admin_and_matching_prior_role_domain_id",
    "identity:list_implied_roles": "rule:cloud_admin or rule:admin_and_matching_prior_role_domain_id",
    "identity:create_implied_role": "rule:cloud_admin or (rule:admin_and_matching_prior_role_domain_id and rule:implied_role_matches_prior_role_domain_or_global)",
    "identity:delete_implied_role": "rule:cloud_admin or rule:admin_and_matching_prior_role_domain_id",
    "identity:list_role_inference_rules": "rule:cloud_admin",
    "identity:check_implied_role": "rule:cloud_admin or rule:admin_and_matching_prior_role_domain_id",

    "identity:check_grant": "rule:cloud_admin or rule:domain_admin_for_grants or rule:project_admin_for_grants",
    "identity:list_grants": "rule:cloud_admin or rule:domain_admin_for_list_grants or rule:project_admin_for_list_grants",
    "identity:create_grant": "rule:cloud_admin or rule:domain_admin_for_grants or rule:project_admin_for_grants",
    "identity:revoke_grant": "rule:cloud_admin or rule:domain_admin_for_grants or rule:project_admin_for_grants",
    "domain_admin_for_grants": "rule:domain_admin_for_global_role_grants or rule:domain_admin_for_domain_role_grants",
    "domain_admin_for_global_role_grants": "rule:admin_required and None:%(target.role.domain_id)s and rule:domain_admin_grant_match",
    "domain_admin_for_domain_role_grants": "rule:admin_required and domain_id:%(target.role.domain_id)s and rule:domain_admin_grant_match",
    "domain_admin_grant_match": "domain_id:%(domain_id)s or domain_id:%(target.project.domain_id)s",
    "project_admin_for_grants": "rule:project_admin_for_global_role_grants or rule:project_admin_for_domain_role_grants",
    "project_admin_for_global_role_grants": "rule:admin_required and None:%(target.role.domain_id)s and project_id:%(project_id)s",
    "project_admin_for_domain_role_grants": "rule:admin_required and project_domain_id:%(target.role.domain_id)s and project_id:%(project_id)s",
    "domain_admin_for_list_grants": "rule:admin_required and rule:domain_admin_grant_match",
    "project_admin_for_list_grants": "rule:admin_required and project_id:%(project_id)s",

    "admin_on_domain_filter" : "rule:admin_required and domain_id:%(scope.domain.id)s",
    "admin_on_project_filter" : "rule:admin_required and project_id:%(scope.project.id)s",
    "admin_on_domain_of_project_filter" : "rule:admin_required and domain_id:%(target.project.domain_id)s",
    "identity:list_role_assignments": "rule:cloud_admin or rule:admin_on_domain_filter or rule:admin_on_project_filter",
    "identity:list_role_assignments_for_tree": "rule:cloud_admin or rule:admin_on_domain_of_project_filter",
    "identity:get_policy": "rule:cloud_admin",
    "identity:list_policies": "rule:cloud_admin",
    "identity:create_policy": "rule:cloud_admin",
    "identity:update_policy": "rule:cloud_admin",
    "identity:delete_policy": "rule:cloud_admin",

    "identity:check_token": "rule:admin_or_owner",
    "identity:validate_token": "rule:service_admin_or_owner",
    "identity:validate_token_head": "rule:service_or_admin",
    "identity:revocation_list": "rule:service_or_admin",
    "identity:revoke_token": "rule:admin_or_owner",

    "identity:create_trust": "user_id:%(trust.trustor_user_id)s",
    "identity:list_trusts": "",
    "identity:list_roles_for_trust": "",
    "identity:get_role_for_trust": "",
    "identity:delete_trust": "",
    "identity:get_trust": "",

    "identity:create_consumer": "rule:admin_required",
    "identity:get_consumer": "rule:admin_required",
    "identity:list_consumers": "rule:admin_required",
    "identity:delete_consumer": "rule:admin_required",
    "identity:update_consumer": "rule:admin_required",

    "identity:authorize_request_token": "rule:admin_required",
    "identity:list_access_token_roles": "rule:admin_required",
    "identity:get_access_token_role": "rule:admin_required",
    "identity:list_access_tokens": "rule:admin_required",
    "identity:get_access_token": "rule:admin_required",
    "identity:delete_access_token": "rule:admin_required",

    "identity:list_projects_for_endpoint": "rule:admin_required",
    "identity:add_endpoint_to_project": "rule:admin_required",
    "identity:check_endpoint_in_project": "rule:admin_required",
    "identity:list_endpoints_for_project": "rule:admin_required",
    "identity:remove_endpoint_from_project": "rule:admin_required",

    "identity:create_endpoint_group": "rule:admin_required",
    "identity:list_endpoint_groups": "rule:admin_required",
    "identity:get_endpoint_group": "rule:admin_required",
    "identity:update_endpoint_group": "rule:admin_required",
    "identity:delete_endpoint_group": "rule:admin_required",
    "identity:list_projects_associated_with_endpoint_group": "rule:admin_required",
    "identity:list_endpoints_associated_with_endpoint_group": "rule:admin_required",
    "identity:get_endpoint_group_in_project": "rule:admin_required",
    "identity:list_endpoint_groups_for_project": "rule:admin_required",
    "identity:add_endpoint_group_to_project": "rule:admin_required",
    "identity:remove_endpoint_group_from_project": "rule:admin_required",

    "identity:create_identity_provider": "rule:cloud_admin",
    "identity:list_identity_providers": "rule:cloud_admin",
    "identity:get_identity_provider": "rule:cloud_admin",
    "identity:update_identity_provider": "rule:cloud_admin",
    "identity:delete_identity_provider": "rule:cloud_admin",

    "identity:create_protocol": "rule:cloud_admin",
    "identity:update_protocol": "rule:cloud_admin",
    "identity:get_protocol": "rule:cloud_admin",
    "identity:list_protocols": "rule:cloud_admin",
    "identity:delete_protocol": "rule:cloud_admin",

    "identity:create_mapping": "rule:cloud_admin",
    "identity:get_mapping": "rule:cloud_admin",
    "identity:list_mappings": "rule:cloud_admin",
    "identity:delete_mapping": "rule:cloud_admin",
    "identity:update_mapping": "rule:cloud_admin",

    "identity:create_service_provider": "rule:cloud_admin",
    "identity:list_service_providers": "rule:cloud_admin",
    "identity:get_service_provider": "rule:cloud_admin",
    "identity:update_service_provider": "rule:cloud_admin",
    "identity:delete_service_provider": "rule:cloud_admin",

    "identity:get_auth_catalog": "",
    "identity:get_auth_projects": "",
    "identity:get_auth_domains": "",

    "identity:list_projects_for_user": "",
    "identity:list_domains_for_user": "",

    "identity:list_revoke_events": "rule:service_or_admin",

    "identity:create_policy_association_for_endpoint": "rule:cloud_admin",
    "identity:check_policy_association_for_endpoint": "rule:cloud_admin",
    "identity:delete_policy_association_for_endpoint": "rule:cloud_admin",
    "identity:create_policy_association_for_service": "rule:cloud_admin",
    "identity:check_policy_association_for_service": "rule:cloud_admin",
    "identity:delete_policy_association_for_service": "rule:cloud_admin",
    "identity:create_policy_association_for_region_and_service": "rule:cloud_admin",
    "identity:check_policy_association_for_region_and_service": "rule:cloud_admin",
    "identity:delete_policy_association_for_region_and_service": "rule:cloud_admin",
    "identity:get_policy_for_endpoint": "rule:cloud_admin",
    "identity:list_endpoints_for_policy": "rule:cloud_admin",

    "identity:create_domain_config": "rule:cloud_admin",
    "identity:get_domain_config": "rule:cloud_admin",
    "identity:get_security_compliance_domain_config": "",
    "identity:update_domain_config": "rule:cloud_admin",
    "identity:delete_domain_config": "rule:cloud_admin",
    "identity:get_domain_config_default": "rule:cloud_admin"
  }
  EOS
  end




  def keystone_log_conf; <<~EOS
  [loggers]
  keys=root,access
  [handlers]
  keys=production,file,access_file,devel
  [formatters]
  keys=minimal,normal,debug
  [logger_root]
  level=DEBUG
  handlers=file
  [logger_access]
  level=INFO
  qualname=access
  handlers=access_file
  [handler_production]
  class=handlers.SysLogHandler
  level=ERROR
  formatter=normal
  args=(('localhost', handlers.SYSLOG_UDP_PORT), handlers.SysLogHandler.LOG_USER)
  [handler_file]
  class=handlers.RotatingFileHandler
  level=DEBUG
  formatter=normal
  args=('#{var}/log/keystone/keystone-error.log', 'a', 100000000, 10)
  [handler_access_file]
  class=handlers.RotatingFileHandler
  level=DEBUG
  formatter=minimal
  args=('#{var}/log/keystone/keystone.log', 'a', 100000000, 10)
  [handler_devel]
  class=StreamHandler
  level=NOTSET
  formatter=debug
  args=(sys.stdout,)
  [formatter_minimal]
  format=%(message)s
  [formatter_normal]
  format=(%(name)s): %(asctime)s %(levelname)s %(message)s
  [formatter_debug]
  format=(%(name)s): %(asctime)s %(levelname)s %(module)s %(funcName)s %(message)s
  EOS
  end

  def keystone_conf; <<~EOS
  [DEFAULT]
  list_limit = 20
  debug = true
  use_journal = false
  use_syslog = false
  log_config_append = #{etc}/keystone/logging.conf
  [assignment]
  [auth]
  methods = password,token
  [cache]
  [catalog]
  [cors]
  [cors.subdomain]
  [credential]
  [database]
  connection = mysql+pymysql://root:password@localhost:3306/keystone
  [domain_config]
  [endpoint_filter]
  [endpoint_policy]
  [eventlet_server]
  [federation]
  [fernet_tokens]
  key_repository = #{etc}/keystone/fernet-keys
  [healthcheck]
  [identity]
  domain_configurations_from_database = true
  domain_specific_drivers_enabled = true
  [identity_mapping]
  [ldap]
  [matchmaker_redis]
  [memcache]
  [oauth1]
  [oslo_messaging_amqp]
  [oslo_messaging_kafka]
  [oslo_messaging_notifications]
  [oslo_messaging_rabbit]
  [oslo_messaging_zmq]
  [oslo_middleware]
  [oslo_policy]
  policy_file = #{etc}/keystone/policy.json
  [paste_deploy]
  config_file = #{etc}/keystone/keystone-paste.ini
  [policy]
  [profiler]
  [resource]
  admin_project_name = system
  admin_project_domain_name = Default
  [revoke]
  [role]
  [saml]
  [security_compliance]
  [shadow_users]
  [signing]
  [token]
  provider = fernet
  expiration = 86400
  [tokenless_auth]
  [trust]
  enable_ssl = true
  ssl_certfile = '#{etc}/keystone/keys/keystone-full.crt'
  ssl_keyfile = '#{etc}/keystone/keys/keystone.key'
  EOS
  end

  def post_install
    (var/"log/keystone").mkpath
    (etc/"keystone/fernet-keys").mkpath
    (etc/"keystone/keys").mkpath
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
