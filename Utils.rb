require 'json'
require './Lifter.rb'

class Utils
    class << self
        def read_json(path)
            file = File.read(path)
            data = JSON.parse(file)
            data['wlifter'].map { |wl| Lifter.new(wl['name'], wl['weightClass'], wl['total']) }
        end
    end
end