# MySQLのバージョンをnodeにセットする

result = run_command("mysql --version")
mysql_full_version = result.stdout.strip

mysql_full_version =~ /Ver (\d+)/
mysql_short_version = Regexp.last_match(1).to_f

node[:mysql] ||= {}
node[:mysql][:full_version] = mysql_full_version

if mysql_full_version.include?("MariaDB")
  mysql_full_version =~ /([\d.]+)-MariaDB/
  mariadb_version = Regexp.last_match(1).to_f

  # MariaDBの場合はMySQLに合わせたバージョンを設定する
  # c.f. https://qiita.com/katzueno/items/e735950c7440f232ef27
  node[:mysql][:short_version] =
    if mariadb_version >= 10.4
      8.0
    elsif mariadb_version >= 10.2
      5.7
    elsif mariadb_version >= 10.1
      5.6
    elsif mariadb_version >= 5.5
      5.5
    else
      5.1
    end

  node[:mysql][:mariadb_version] = mariadb_version
else
  node[:mysql][:short_version] = mysql_short_version
end

include_recipe "./system"
include_recipe "./user"
include_recipe "./mysql"
include_recipe "./datadog"

if node[:newrelic]
  include_recipe "./newrelic"
end

# NOTE: ベンチマークサーバではrubyは不要
unless node[:hostname].include?("bench")
  # NOTE: これが一番重いので他の作業が中断しないように一番最後に実行する
  include_recipe "./ruby"
end
