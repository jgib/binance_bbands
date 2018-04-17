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
BUY_PERCENT   = 1                                                 # Percent of price to buy at.
SELL_PERCENT  = 1                                                 # Percent of price to sell at.
TRADE_PERCENT = 1                                                 # Percent of total capital to trade.
PERIOD        = 20                                                # Number of candles used to calculate SMA and BBANDS.
STOP_PERCENT  = 0.015                                             # Percent past the buy price to exit the trade.
STOP_WAIT     = 60 * 60 * 2                                       # Time to wait in seconds after stop condition reached.

#########
# NOTES #
#########

# SMA = Sum of closing prices over n periods / by n
# Middle Band = 20-day simple moving average (SMA)
# Upper  Band = 20-day SMA + (20-day standard deviation of price * 2)
# Lower  Band = 20-day SMA - (20-day standard deviation of price * 2)

# Documentation: https://github.com/binance-exchange/binance-official-api-docs/blob/master/rest-api.md

# Rate Limits:
#   REQUESTS: 1200 / MIN
#     +->       20 / SEC
#   ORDERS:     10 / SEC
#   ORDERS: 100000 / DAY

#   A 429 will be returned by webserver when rate limit is exceeded.
#   Repeated rate limit violations will result in 418 return code and result in IP ban.
#   Other Response Codes:
#    4XX malformed request, client side error.
#    5XX internal errors, server side error.
#    504 API successfully sent message but did not get response within timeout.
#      Request may succeed or fail, status is unknown.

#   API Keys are passed to REST via 'X-MBX-APIKEY' header
#   All timestamps for API are in milliseconds, the default is 5000.
#     This should probably be set to something less.

#   Reference for binance API: https://github.com/jakenberg/binance-ruby

#########
# NOTES #
#########

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
  output = Binance::Api.candlesticks!(interval: "#{INTERVAL}", symbol: "#{SYMBOL}", limit: "#{PERIOD}")
  return(output)
end

def sma(prices)
  debug("Calculating SMA")
  total = 0
  prices.each do |price|
    total = total + price
  end
  output = total / PERIOD
  debug("SMA is #{output}")
  return(output)
end

def std_dev(prices,sma)
  debug("Calculating Standard Deviation")
  distance_to_mean = Array.new
  debug("Calculating distance to mean")
  prices.each do |price|
    distance_to_mean.push((price.to_f - sma) ** 2)
  end
  means_sum = 0
  debug("Summing distances to mean")
  distance_to_mean.each do |dst|
    means_sum = means_sum + dst
  end
  debug("Square root of sum over period")
  output    = Math.sqrt(means_sum / PERIOD)
  debug("Standard Deviation is #{output}")
  return(output)
end

def calc_bbands(candles)
  i = 1
  closing_prices = Array.new
  candles.each do |candle|
    debug("Getting candle #{i}")
    open_time  = candle[0].to_i
    open       = candle[1].to_f
    high       = candle[2].to_f
    low        = candle[3].to_f
    close      = candle[4].to_f
    volume     = candle[5].to_f
    close_time = candle[6].to_i
    num_trades = candle[8].to_i
    closing_prices.push(close)
    i = i + 1
  end
  sma         = sma(closing_prices)
  std_dev     = std_dev(closing_prices,sma)
  middle_band = sma
  debug("Middle Band is #{middle_band}")
  upper_band  = sma + (std_dev * 2)
  debug("Upper Band is #{upper_band}")
  lower_band  = sma - (std_dev * 2)
  debug("Lower Band is #{lower_band}")
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
