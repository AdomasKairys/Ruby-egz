require 'json'
require 'ractor'
require './Lifter.rb'
require './Utils.rb'


lifters = Utils.read_json('Data/IF11_KairysA_LD1_dat2.json')
Ractor.make_shareable(lifters)

NUM = 5

distributor = Ractor.new do 
    loop do
        Ractor.yield Ractor.recieve
    end
end

worker = NUM.times.map{
    Ractor.new distributor do |dist|
        while l = dist.take
            l.generate_hash
            Ractor.yield l
        end
    end
}

(0..10).each{ |i|
    distributor << lifters[i]
}

p = (0..10).map{
    _r, l = Ractor.select(*worker)
    l
}



print p[0].hash