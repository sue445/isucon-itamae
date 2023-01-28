# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gem "dotenv"
gem "itamae"
gem "itamae-plugin-recipe-datadog", ">= 0.3.0"
gem "itamae-plugin-recipe-rust"

# c.f. https://github.com/net-ssh/net-ssh/issues/868
gem "net-ssh", ">= 7.0.0"

gem "rake"

group :test do
  # required for `itamae docker`
  # c.f. https://github.com/itamae-kitchen/itamae/blob/v1.12.1/lib/itamae/backend.rb#L307-L311
  gem "docker-api"
end
