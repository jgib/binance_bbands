#!/usr/bin/env ruby

require 'pp'
require 'json'
require 'date'
require 'io/console'
require 'binance-ruby'

# Get decryption password
system("clear")
print "Decryption Passphrase: "
pass = STDIN.noecho(&:gets).chomp
puts ""

ROUND         = 6                                                 # Ammount to round currency decimals.
DEBUG         = true                                              # Toggle debug output.
ERROR         = "2> /dev/null"                                    # Blackhole error output.
HOME          = "/home/admin/ruby/"                               # Home directory of keys file.
GPG           = "/usr/bin/gpg"                                    # Path to gpg.
KEYS          = "#{HOME}keys.gpg"                                 # Path and filename of encrypted keys file.
DECRYPT       = "#{GPG} --passphrase #{pass} -d #{KEYS} #{ERROR}" # Decryption command.
SYMBOL        = "BTCUSDT"                                         # Currency pair.
INTERVAL      = "5m"                                              # Candlestick intervals.  Options are: 1m, 3m, 5m, 15m, 30m, 1h, 2h, 4h, 6h, 8h, 12h, 1d, 3d, 1w, 1M
BUY_PERCENT   = 1
SELL_PERCENT  = 1
TRADE_PERCENT = 1

def get_timestamp()
  time  = Time.now.to_s
  epoch = Time.now.to_f.round(4)
  return("#{time} ::: #{epoch}")
end

def debug(text)
  if DEBUG == true
    time = get_timestamp
    puts "#{time} ::: #{text}"
  end
end

def wait(seconds)
  debug("Waiting #{seconds} seconds...")
  sleep(seconds)
end

def decrypt()
  output   = Array.new
  debug("Starting decryption of #{KEYS}")
  raw_data = JSON.parse(`#{DECRYPT}`)
  raw_data.each do |array|
    if    (array[0] == "API Key")
      debug("Captured API Key")
      output[0] = array[1]
    elsif (array[0] == "Secret Key")
      debug("Captured Secret Key")
      output[1] = array[1]
    end
  end
  debug("Decryption of #{KEYS} finished")
  return(output)
end

def get_candles()
  debug("Getting candlestick data")
  output = Binance::Api.candlesticks!(interval: "#{INTERVAL}", symbol: "#{SYMBOL}")
  return(output)
end

def calc_bbands(candles)
  i = 1
  candles.each do |candle|
    debug("Getting candle #{i}")
    open_time  = candle[0]
    open       = candle[1]
    high       = candle[2]
    low        = candle[3]
    close      = candle[4]
    volume     = candle[5]
    close_time = candle[6]
    num_trades = candle[8]
    i = i + 1
  end
end


def main()
  keys       = decrypt()
  debug("Getting API Key")
  api_key    = keys[0]
  debug("Getting Secret Key")
  secret_key = keys[1]
  debug("Loading API Key")
  Binance::Api::Configuration.api_key    = api_key
  Binance::Api::Configuration.secret_key = secret_key
  calc_bbands(get_candles())
  wait(10)

end

main()
