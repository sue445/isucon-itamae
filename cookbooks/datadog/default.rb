require "dotenv/load"

node[:datadog][:api_key] = ENV["DD_API_KEY"]

include_recipe "datadog::install"
