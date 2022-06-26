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
  "zlib1g-dev",
  "libncurses5-dev",
  "libffi-dev",
  "libgdbm6",
  "libgdbm-dev",
  "libdb-dev",

  # 3.2.0-devビルド時に「configure: error: cannot run /bin/bash tool/config.sub」が出るため
  # c.f. https://github.com/rubyomr-preview/rubyomr-preview/issues/22#issuecomment-268372174
  "git",
  "ruby",
].each do |name|
  package name
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

install_options = ""
check_command = ""
force_option = ""

# force_installが有効な場合には毎回必ずビルドを実行する
if node[:ruby][:force_install]
  force_option = "-f"
else
  if Gem::Version.create(node[:ruby][:version]) >= Gem::Version.create("3.2.0-dev") && node[:ruby][:enabled_yjit]
    # c.f.
    # * https://github.com/ruby/ruby/blob/504728307069d49994541c91769bc90444a4fce5/.github/workflows/yjit-ubuntu.yml#L45-L46
    install_options << "RUBY_CONFIGURE_OPTS=--enable-yjit RUSTC='rustc +#{node[:rust][:version]}' PATH=/home/isucon/.cargo/bin:$PATH "

    # NOTE: Ruby 3.2.0以降でenabled_yjitが有効な場合ではYJITを有効にしてビルドしてるかもチェックする
    # c.f. https://koic.hatenablog.com/entry/building-rust-yjit
    check_command = "#{ruby_binary} --yjit -e 'p RubyVM::YJIT.enabled?' | grep 'true'"
  else
    check_command = "ls #{ruby_binary}"
  end
end

execute "#{install_options}#{node[:xbuild][:path]}/ruby-install #{force_option} #{node[:ruby][:version]} #{ruby_install_path}" do
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
