execute "systemctl daemon-reload" do
  action :nothing
end

service "mysql" do
  action :nothing
end

# FIXME: GitHub ActionsのDockerだとread timeout reached (Docker::Error::TimeoutError)になるためDockerでは再起動を抑制する
enable_mysql_restart = !node[:docker]

# LimitNOFILEが設定されていないとmax_connectionsが増やせないので増やす
%w(mysql mariadb).each do |name|
  file "/lib/systemd/system/#{name}.service" do
    action :edit

    limit_no_file = 65535

    block do |content|
      unless content.include?("LimitNOFILE=")
        content.gsub!(/^\[Service\]/, "[Service]\nLimitNOFILE=#{limit_no_file}")
      end

      content.gsub!(/^LimitNOFILE=.+$/, "LimitNOFILE=#{limit_no_file}")
    end

    only_if "ls /lib/systemd/system/#{name}.service"

    notifies :run, "execute[systemctl daemon-reload]"

    if enable_mysql_restart
      notifies :restart, "service[mysql]"
    end
  end
end

# DatadogからMySQLのログにアクセスできるようにする
# c.f. https://docs.datadoghq.com/ja/integrations/mysql/?tab=host
%w(
  /etc/mysql/conf.d/mysqld_safe_syslog.cnf
  /etc/mysql/mariadb.conf.d/50-mysqld_safe.cnf
).each do |name|
  file name do
    action :delete

    if enable_mysql_restart
      notifies :restart, "service[mysql]"
    end
  end
end

directory "/var/log/mysql/" do
  mode "2755"
end

%w(error slow).each do |name|
  file "/var/log/mysql/#{name}.log" do
    mode "664"
  end
end

total_memory_mb = node[:memory][:total].gsub(/kb$/i, "").to_i / 1024

# 物理メモリの8割
innodb_buffer_pool_size_mb = (total_memory_mb * 0.8).to_i

# innodb_buffer_pool_sizeの1/4程度
innodb_log_file_size_mb = innodb_buffer_pool_size_mb / 4

template "/etc/mysql/conf.d/isucon.cnf" do
  mode  "644"
  owner "root"
  group "root"

  variables(
    slow_query_log_file: node.dig(:mysql, :slow_query_log_file),
    long_query_time: node.dig(:mysql, :long_query_time),
    mysql_short_version: node[:mysql][:short_version],
    innodb_buffer_pool_size_mb: innodb_buffer_pool_size_mb,
    innodb_log_file_size_mb: innodb_log_file_size_mb,
  )

  if enable_mysql_restart
    notifies :restart, "service[mysql]"
  end
end


define :mysql_command, check_command: nil, expected_response: nil do
  check_command = params[:check_command]
  expected_response = params[:expected_response]

  execute %Q(mysql --execute="#{params[:name]}") do
    if check_command && expected_response
      not_if %Q(mysql --execute="#{check_command}" | grep "#{expected_response}")
    end
  end
end

directory "/etc/isucon-itamae/" do
  mode  "755"
  owner "root"
  group "root"
end

#  /etc/isucon-itamae/ にあるsqlファイルを実行する
define :execute_sql_file do
  execute "mysql < /etc/isucon-itamae/#{params[:name]}"
end

# files/etc/isucon-itamae/ にあるsqlファイルをuploadして実行する
define :upload_and_execute_sql_file do
  remote_file "/etc/isucon-itamae/#{params[:name]}" do
    mode  "644"
    owner "root"
    group "root"
  end

  execute_sql_file params[:name]
end

# クエリを実行した結果を取得する
# @param sql
# @return [Array<Array<String>>]
def find_by_sql(sql)
  # FIXME: find_by_sqlはitamaeのレシピ解析時に実行されるため、dry run前にファイルが存在しないとエラーになる
  my_cnf = "/root/.my.cnf"
  run_command("cp /etc/mysql/debian.cnf #{my_cnf} && chown root:root #{my_cnf} && chmod 644 #{my_cnf}")

  result = run_command(%Q(mysql -B -N --execute="#{sql}"))
  stdout = result.stdout.strip

  rows = []
  stdout.each_line do |row|
    rows << row.split("\t")
  end
  rows
end

node[:mysql][:users].each do |user|
  template "/etc/isucon-itamae/create_ussr_#{user[:user]}_#{user[:host]}.sql" do
    source "templates/etc/isucon-itamae/create_user.sql.erb"

    mode  "644"
    owner "root"
    group "root"

    variables(
      user:     user[:user],
      host:     user[:host],
      password: user[:password],
    )
  end

  execute_sql_file "create_ussr_#{user[:user]}_#{user[:host]}.sql"
end

# Datadogで使うmysqlのユーザを作成する
# c.f.
# * https://docs.datadoghq.com/ja/integrations/mysql/
# * https://docs.datadoghq.com/ja/database_monitoring/setup_mysql/selfhosted/
if node[:mysql][:short_version] >= 8.0
  if node[:mysql][:mariadb_version]
    # FIXME: Ubuntu Jammy + MariaDBの場合に「WITH mysql_native_password」が使えないので消す
    upload_and_execute_sql_file "create_datadog_user_mysql_8.0_mariadb.sql"
  else
    upload_and_execute_sql_file "create_datadog_user_mysql_8.0.sql"
  end
else
  upload_and_execute_sql_file "create_datadog_user_mysql_5.7.sql"
end

upload_and_execute_sql_file "create_datadog_schema.sql"
upload_and_execute_sql_file "create_datadog_explain_statement.sql"

isucon_schemas = find_by_sql("SELECT schema_name from information_schema.schemata where schema_name LIKE 'isu%'").flatten
isucon_schemas.each do |schema_name|
  template "/etc/isucon-itamae/create_datadog_explain_statement_by_#{schema_name}.sql" do
    source "templates/etc/isucon-itamae/create_datadog_explain_statement_by_schema.sql.erb"

    mode  "644"
    owner "root"
    group "root"

    variables(
      schema_name: schema_name,
    )
  end

  execute_sql_file "create_datadog_explain_statement_by_#{schema_name}.sql"
end

upload_and_execute_sql_file "create_datadog_enable_events_statements_consumers.sql"
