require_relative "../lib/helper"

@available_cookbooks =
  if ENV["COOKBOOK"] && !ENV["COOKBOOK"].empty?
    ENV["COOKBOOK"].split(",")
  else
    []
  end

def include_cookbook?(cookbook_name)
  # COOKBOOKが空の場合は全てincludeする
  return true if @available_cookbooks.empty?

  # COOKBOOKが指定されていたらそのcookbookのみをincludeする
  @available_cookbooks.include?(cookbook_name)
end

# NOTE: initializeで色々初期化してるのでCOOKBOOKの有無に関わらずここは必ず実行する
include_recipe "initialize"

[
  "system",
  "service",
  "user",
].each do |cookbook_name|
  if include_cookbook?(cookbook_name)
    include_recipe cookbook_name
  end
end

# NOTE: ベンチマークサーバでは以降は不要
return if node[:hostname].include?("bench")

[
  "mysql",
  "nginx",
  "fluentd",
  "datadog",

  # NOTE: これが一番重いので他の作業が中断しないように一番最後に実行する
  "ruby",
].each do |cookbook_name|
  if include_cookbook?(cookbook_name)
    include_recipe cookbook_name
  end
end
