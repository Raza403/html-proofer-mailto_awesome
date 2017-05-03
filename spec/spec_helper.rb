require 'bundler/setup'
require 'vcr'
require 'timecop'
require 'html-proofer'
require_relative '../lib/mail_to_awesome'

FIXTURES_DIR = 'spec/fixtures'

RSpec.configure do |config|
  # Use color in STDOUT
  config.color = true

  # Use color not only in STDOUT but also in pagers and files
  config.tty = true

  # Use the specified formatter
  config.formatter = :documentation # :progress, :html, :textmate

  # Run in a random order
  config.order = :random
end

def capture_stderr(*)
  original_stderr = $stderr
  original_stdout = $stdout
  $stderr = fake_err = StringIO.new
  $stdout = fake_out = StringIO.new unless ENV['VERBOSE']
  begin
    yield
  rescue RuntimeError
  ensure
    $stderr = original_stderr
    $stdout = original_stdout unless ENV['VERBOSE']
  end
  fake_err.string
end

def make_proofer(item, type, opts)
  opts[:log_level] ||= :error
  case type
    when :file
      HTMLProofer.check_file(item, opts)
    when :directory
      HTMLProofer.check_directory(item, opts)
    when :directories
      HTMLProofer.check_directories(item, opts)
    when :links
      HTMLProofer.check_links(item, opts)
  end
end

def run_proofer(item, type, opts = {})
  proofer = make_proofer(item, type, opts)
  cassette_name = make_cassette_name(item, opts)
  VCR.use_cassette(cassette_name, :record => :new_episodes) do
    capture_stderr { proofer.run }
    proofer
  end
end

def make_cassette_name(file, opts)
  filename = if file.is_a? Array
               file.join('_')
             else
               file.split('/')[-2..-1].join('/')
             end
  (filename += opts.inspect) unless opts.empty?
  filename
end

VCR.configure do |config|
  config.cassette_library_dir = "#{FIXTURES_DIR}/vcr_cassettes"
  config.hook_into :typhoeus
end
