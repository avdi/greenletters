require 'cucumber'

module Greenletters
  module CucumberHelpers
    def greenletters_prepare_entry(text)
      text.chomp + "\n"
    end
    def greenletters_massage_pattern(text)
      Regexp.new(Regexp.escape(text.strip.tr_s(" \r\n\t", " ")).gsub('\ ', '\s+'))
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
  logger = ::Logger.new(open(filename, 'w+'))
  #logger.level = ::Logger::INFO
  logger.level = ::Logger::DEBUG
  @greenletters_process_log = logger
end

Given /^a process (?:"([^\"]*)" )?from command "([^\"]*)"$/ do |name, command|
  name ||= "default"
  options = {
  }
  options[:logger] = @greenletters_process_log if @greenletters_process_log
  @greenletters_process_table[name] = Greenletters::Process.new(command, options)
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

Then /^I should see the following output(?: from process "([^\"]*)")?:$/ do
  |name, pattern|
  name ||= "default"
  pattern = greenletters_massage_pattern(pattern)
  @greenletters_process_table[name].wait_for(:output, pattern)
end

When /^I enter "([^\"]*)"(?: into process "([^\"]*)")?$/ do
  |input, name|
  name ||= "default"
  @greenletters_process_table[name] << greenletters_prepare_entry(input)
end

Then /^the process(?: "([^\"]*)")? should exit succesfully$/ do |name|
  name ||= "default"
  @greenletters_process_table[name].wait_for(:exit, 0)
end

