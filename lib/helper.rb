def enabled_rust_yjit?
  ruby_version = node.dig(:ruby, :version)
  return false unless ruby_version

  enabled_yjit = node.dig(:ruby, :enabled_yjit)
  return false unless enabled_yjit

  return true if ruby_version == "ruby-dev"

  Gem::Version.create(ruby_version) >= Gem::Version.create("3.2.0-dev")
end
