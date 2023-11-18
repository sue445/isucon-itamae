require_relative "../../lib/helper"

home_dir = "/home/isucon"

node.reverse_merge!(
  gem: {
    install: [],
  },
  xbuild: {
    path: "/home/isucon/xbuild",
  }
)

git node[:xbuild][:path] do
  repository "https://github.com/tagomoris/xbuild.git"
  user       "isucon"
end

# .c.f. https://github.com/rbenv/ruby-build/wiki#ubuntudebianmint
[
  "autoconf",
  "bison",
  "build-essential",
  "libssl-dev",
  "libyaml-dev",
  "libreadline6-dev",
  "rustc",
  "zlib1g-dev",
  "libncurses5-dev",
  "libffi-dev",
  "libgdbm-dev",
  "libdb-dev",

  # 3.2.0-devビルド時に「configure: error: cannot run /bin/bash tool/config.sub」が出るため
  # c.f. https://github.com/rubyomr-preview/rubyomr-preview/issues/22#issuecomment-268372174
  "git",
  "ruby",
].each do |name|
  package name
end

case node[:platform]
when "ubuntu"
  if node[:platform_version] >= '20.04'
    package "libgdbm6"
  else
    package "libgdbm5"
  end
end

%w(
  /home/isucon/local/ruby
  /home/isucon/local/ruby/bin
  /home/isucon/local/ruby/versions
).each do |path|
  directory path do
    mode  "775"
    owner "isucon"
    group "isucon"
  end
end

# nodeでruby.versionの指定が無い場合はここで終わり
return unless node.dig(:ruby, :version)

ruby_install_path = "#{home_dir}/local/ruby/versions/#{node[:ruby][:version]}"
ruby_binary = "#{ruby_install_path}/bin/ruby"

check_command = ""

if enabled_rust_yjit?
  # NOTE: Ruby 3.2.0以降でenabled_yjitが有効な場合ではYJITを有効にしてビルドしてるかもチェックする
  # c.f. https://koic.hatenablog.com/entry/building-rust-yjit
  check_command = "#{ruby_binary} --yjit -e 'p RubyVM::YJIT.enabled?' | grep 'true'"
else
  check_command = "ls #{ruby_binary}"
end

# force_installが有効な場合には毎回必ずビルドを実行したいのでcheck_commandを消しつつruby-installにforceオプションもつける
force_option = ""
if node[:ruby][:force_install]
  force_option = "-f"
  check_command = ""
end

execute "#{node[:xbuild][:path]}/ruby-install #{force_option} #{node[:ruby][:version]} #{ruby_install_path}" do
  user "isucon"

  unless check_command.empty?
    not_if check_command
  end
end

node[:gem][:install].each do |gem_name, gem_version|
  gem_package gem_name do
    gem_binary "#{ruby_install_path}/bin/gem"
    options    "--no-doc"
    user       "isucon"

    if gem_version
      version gem_version
    end
  end
end
