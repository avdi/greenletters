# This demo interacts with the classic Collossal Cave Adventure game. To install
# the game on Debian-based systems (Ubuntu, etc), execute:
#
#   sudo apt-get install bsdgames
#
$:.unshift(File.expand_path('../lib', File.dirname(__FILE__)))
require 'greenletters'
require 'logger'

logger = ::Logger.new($stdout)
logger.level = ::Logger::INFO
# logger.level = ::Logger::DEBUG
adv = Greenletters::Process.new("adventure",
   :logger     => logger,
   :transcript => $stdout)
adv.on(:output, /welcome to adventure/i) do |process, match_data|
  adv << "no\n"
end

puts "Starting aadventure..."
adv.start!
adv.wait_for(:output, /you are standing at the end of a road/i)
adv << "east\n"
adv.wait_for(:output, /inside a building/i)
adv << "quit\n"
adv.wait_for(:output, /really want to quit/i)
adv << "yes\n"
adv.wait_for(:exit)
puts "Adventure has exited."

