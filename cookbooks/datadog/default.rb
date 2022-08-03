node.reverse_merge!(
  datadog: {
    enabled: false,
    mysql: {
      dbm: false
    },
    integrations: {}
  }
)

if node[:datadog][:enabled]
  include_recipe "./enabled"
else
  include_recipe "./disabled"
end

service "datadog-agent" do
  action :nothing
end

directory "/etc/datadog-agent/" do
  mode "755"
end

template "/etc/datadog-agent/datadog.yaml" do
  mode "644"

  if node[:datadog][:enabled]
    notifies :restart, "service[datadog-agent]"
  end
end

%w(
  fluentd.d
  mysql.d
  nginx.d
  process.d
  puma.d
  redisdb.d
).each do |name|
  directory "/etc/datadog-agent/conf.d/#{name}/" do
    mode "755"
  end

  template "/etc/datadog-agent/conf.d/#{name}/conf.yaml" do
    mode "644"

    if node[:datadog][:enabled]
      notifies :restart, "service[datadog-agent]"
    end
  end
end

include_recipe "./datadog_sidekiq"
