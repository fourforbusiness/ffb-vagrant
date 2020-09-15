fc = Net::HTTP.get(URI.parse("https://gist.githubusercontent.com/tfr-ffb/7e1ac6dcdc7d168e63ecb87601a75821/raw/ffb.bootstrap.rb"))
unless File.file?(".ffb"); FileUtils::mkdir_p(".ffb"); end
File.write(".ffb/ffb.bootstrap.rb", fc)
require_relative ".ffb/ffb.bootstrap.rb"