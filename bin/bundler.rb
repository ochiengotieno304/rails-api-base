def invoked_as_script?
  File.expand_path($0) == File.expand_path(__FILE__)
end

def env_var_version
  ENV['BUNDLER_VERSION']
end

def cli_arg_version
  return unless invoked_as_script? # don't want to hijack other binstubs
  return unless "update".start_with?(ARGV.first || ' ') # must be running `bundle update`
  bundler_version = nil
  update_index = nil
  ARGV.each_with_index do |a, i|
    if update_index && update_index.succ == i && a =~ Gem::Version::ANCHORED_VERSION_PATTERN
      bundler_version = a
    end
    next unless a =~ /\A--bundler(?:[= ](#{Gem::Version::VERSION_PATTERN}))?\z/
    bundler_version = $1 || '>= 0.a'
    update_index = i
  end
  bundler_version
end

def gemfile
  gemfile = ENV['BUNDLE_GEMFILE']
  return gemfile if gemfile && !gemfile.empty?

  File.expand_path('../../Gemfile', __FILE__)
end

def lockfile
  lockfile =
    case File.basename(gemfile)
    when 'gems.rb' then gemfile.sub(/\.rb$/, gemfile)
    else "#{gemfile}.lock"
    end
  File.expand_path(lockfile)
end

def lockfile_version
  return unless File.file?(lockfile)
  lockfile_contents = File.read(lockfile)
  return unless lockfile_contents =~ /\n\nBUNDLED WITH\n\s{2,}(#{Gem::Version::VERSION_PATTERN})\n/
  Regexp.last_match(1)
end

def bundler_version
  @bundler_version ||= begin
    env_var_version || cli_arg_version ||
      lockfile_version || "#{Gem::Requirement.default}.a"
  end
end

def load_bundler!
  ENV['BUNDLE_GEMFILE'] ||= gemfile

  # must dup string for RG < 1.8 compatibility
  activate_bundler(bundler_version.dup)
end

def activate_bundler(bundler_version)
  if Gem::Version.correct?(bundler_version) && Gem::Version.new(bundler_version).release < Gem::Version.new("2.0")
    bundler_version = '< 2'
  end
  gem_error = activation_error_handling do
    gem 'bundler', bundler_version
  end
  return if gem_error.nil?
  require_error = activation_error_handling do
    require 'bundler/version'
  end
  return if require_error.nil? && Gem::Requirement.new(bundler_version).satisfied_by?(Gem::Version.new(Bundler::VERSION))
  warn "Activating bundler (#{bundler_version}) failed:\n#{gem_error.message}\n\nTo install the version of bundler this project requires, run `gem install bundler -v '#{bundler_version}'`"
  exit 42
end

def activation_error_handling
  yield
  nil
rescue StandardError, LoadError => e
  e
end
