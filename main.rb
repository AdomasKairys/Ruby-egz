require 'json'
require 'ractor'
require './Lifter.rb'
require './Utils.rb'

lifters = Utils.read_json('Data/IF11_KairysA_LD1_dat2.json')
lifters.each{ |l| Ractor.make_shareable l.freeze}

NUM = 4
N = 100_000

worker = NUM.times.map{
    Ractor.new do
        while l = Ractor.receive.dup
            N.times.each{
                l.generate_hash
            }
            Ractor.yield l
        end
    end
}

result = Ractor.new do
    r=[]
    while l = Ractor.receive
        r << l
    end
    Ractor.yield r
end

distributor = Ractor.new worker, result do |work, res|
    w = nil
    l = nil

    for index in 0..NUM-1
        l = Ractor.receive
        work[index] << l
    end

    loop do
        if w
            l = Ractor.receive
            w << l
        end

        if l == nil
            work.delete w
            break
        end
        w, resul = Ractor.select *work
        print w
        print "\n"
        res << resul
    end

    work.each{
        _r, resul = Ractor.select *work
        res << resul
    }
    res << nil

    Ractor.yield res.take
end


starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
lifters.each{ |l|
    distributor << l
}
distributor << nil
p = distributor.take
ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
elapsed = ending - starting
print elapsed.to_s() +"\n"
#print p
print "\n"
