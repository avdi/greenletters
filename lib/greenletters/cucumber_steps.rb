require 'cucumber'
require 'shellwords'

module Greenletters
  module CucumberHelpers
    def greenletters_prepare_entry(text)
      text.chomp + "\n"
    end

    def greenletters_massage_pattern(text)
      Regexp.new(Regexp.escape(text.strip.tr_s(" \r\n\t", " ")).gsub('\ ', '\s+'))
    end

    # Override this in your Cucumber setup to customize how processes are
    # constructed.
    def make_greenletters_process(command_line, options = {})
      command = Shellwords.shellwords(command_line)
      options[:logger] = @greenletters_process_log if @greenletters_process_log
      process_args = command + [options]
      Greenletters::Process.new(*process_args)
    end
  end
end

World(Greenletters::CucumberHelpers)

Before do
  @greenletters_process_table = Hash.new {|h,k|
    raise "No such process defined: #{k}"
  }
end

Given /^process activity is logged to "([^\"]*)"$/ do |filename|
  logger = ::Logger.new(open(filename, 'a+'))
  #logger.level = ::Logger::INFO
  logger.level = ::Logger::DEBUG
  @greenletters_process_log = logger
end

Given /^a process (?:"([^\"]*)" )?from command "([^\"]*)"$/ do |name, command|
  name ||= "default"
  @greenletters_process_table[name] = make_greenletters_process(command)
end

Given /^the process(?: "([^\"]*)")? has a timeout of ([0-9.]+) seconds$/ do
  |name, length|
  name ||= :"default"
  @greenletters_process_table[name].timeout = length.to_f
end

Given /^I reply "([^\"]*)" to output "([^\"]*)"(?: from process "([^\"]*)")?$/ do
  |reply, pattern, name|
  name ||= "default"
  pattern = greenletters_massage_pattern(pattern)
  @greenletters_process_table[name].on(:output, pattern) do |process, match_data|
    process << greenletters_prepare_entry(reply)
  end
end

When /^I execute the process(?: "([^\"]*)")?$/ do |name|
  name ||= "default"
  @greenletters_process_table[name].start!
end

When /^I wait for (\d+) bytes from the process(?: "([^\"]*)")?$/ do
  |byte_length, name|
  name ||= "default"
  byte_length = byte_length.to_i
  @greenletters_process_table[name].wait_for(:bytes, byte_length)
end

When /^I wait ([0-9.]+) seconds for output from the process(?: "([^\"]*)")?$/ do
  |seconds, name|
  name ||= "default"
  seconds = seconds.to_i
  @greenletters_process_table[name].wait_for(:timeout, seconds)
end

When /^I discard earlier outputs from the process(?: "([^\"]*)")?$/ do
  |name|
  name ||= "default"
  @greenletters_process_table[name].flush_output_buffer!
end

Then /^I should see the following output(?: from process "([^\"]*)")?:$/ do
  |name, pattern|
  name ||= "default"
  process = @greenletters_process_table[name]
  pattern = greenletters_massage_pattern(pattern)
  process.wait_for(:output, pattern)
end

Then /^I should see all the following outputs(?: from process "([^\"]*)")?:$/ do
  |name, table|

  name ||= "default"
  patterns = table.hashes.map { |hash|
    greenletters_massage_pattern(hash['text'])
  }
  @greenletters_process_table[name].wait_for(:output, patterns, :operation => :all)
end


# Note: you may want to wait for output to be buffered before executing this
# step. E.g. "When I wait on process for 1024 bytes or 0.1 seconds"
Then /^I should not see the following output(?: from process "([^\"]*)")?:$/ do
  |name, pattern|
  name ||= "default"
  pattern = greenletters_massage_pattern(pattern)
  @greenletters_process_table[name].check_until(pattern).should be_nil
end

When /^I enter "([^\"]*)"(?: into process "([^\"]*)")?$/ do
  |input, name|
  name ||= "default"
  @greenletters_process_table[name] << greenletters_prepare_entry(input)
end

Then /^the process(?: "([^\"]*)")? should exit successfully$/ do |name|
  name ||= "default"
  @greenletters_process_table[name].wait_for(:exit, 0)
end
