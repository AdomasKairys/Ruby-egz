require 'json'
require 'ractor'
require './Lifter.rb'
require './Utils.rb'
require 'digest/sha2'

lifters = Utils.read_json('Data/IF11_KairysA_LD1_dat3.json')
lifters.each{ |l| Ractor.make_shareable l.freeze}
lifters.freeze
print lifters.size
sha256 = Digest::SHA256
Ractor.make_shareable(sha256.freeze)

NUM = 1
N = 1_000


worker = NUM.times.map{
    Ractor.new sha256 do |sh|
        hash = ""
        while l = Ractor.receive
            #starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            string = l.name + l.weight_class.to_s + '%.6f'%l.total.to_s #.6 because that was default with c++
            print string + "\n"
            #sleep 0.01
            N.times do
                hash = Lifter.generate_hash(sh, string)
            end
            #ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            #elapsed = ending - starting
            #print elapsed.to_s() +"\n"

            if hash[0].match /[0-9]/
                Ractor.yield nil
            else
                Ractor.yield l
            end
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

output = Ractor.new do
    file = File.open("out.txt", "w")
    result_arr = Ractor.receive
    result_arr.each { |rarr|
        file.write rarr.name + '|' + rarr.weight_class.to_s + '|' + rarr.total.to_s + "\n"
    }
    file.close
    Ractor.yield true
end

logger = Ractor.new do
    file = File.open("log.txt", "w")
    while log = Ractor.receive
        file.write log + "\n"
    end
    file.close
    Ractor.yield true
end



distributor = Ractor.new worker, result, logger, output do |work, res, log, out|
    w = nil
    l = nil
    work.each{ |wr|
        l = Ractor.receive
        wr << l
    }

    print "printing\n"

    loop do
        if w
            l = Ractor.receive
            w << l
        end

        if l == nil
            break
        end

        w, resul = Ractor.select *work
        #print w
        #print "\n"
        if resul
            res << resul
        end
    end

    work.delete w
    work.each{
        _r, resul = Ractor.select *work
        work.delete _r
        res << resul
    }
    res << nil
    out << res.take
    out.take
    Ractor.yield true
end


starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)

lifters.each{ |l|
    distributor << l
}

distributor << nil

distributor.take

ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
elapsed = ending - starting
print elapsed.to_s() +"\n"
#print p
print "\n"
