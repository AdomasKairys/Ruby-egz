require 'json'
require 'ractor'
require './Lifter.rb'
require './Utils.rb'
require 'digest/sha2'

lifters = Utils.read_json('Data/IF11_KairysA_LD1_dat2.json')
lifters.each{ |l| Ractor.make_shareable l.freeze}
lifters.freeze
sha256 = Digest::SHA256
Ractor.make_shareable(sha256.freeze)

NUM = 4
N = 1_000

worker = NUM.times.map{
    Ractor.new sha256 do |sh|
        hash = ""
        while l = Ractor.receive
            string = l.name + l.weight_class.to_s + '%.6f'%l.total.to_s #.6 because that was default with c++
            #sleep 0.01
            N.times do
                hash = Utils.generate_hash(sh, string)
            end
            if hash[0].match /[0-9]/
                Ractor.yield nil
            else
                Ractor.yield [l,hash]
            end
        end
    end
}

result = Ractor.new do
    hashed_lifters=[]
    while l = Ractor.receive
        insert_at = hashed_lifters.bsearch_index { |hl| hl[0].weight_class <= l[0].weight_class }
        if insert_at
            hashed_lifters.insert(insert_at, l)
            next
        end
        hashed_lifters << l
    end
    Ractor.yield hashed_lifters
end

output = Ractor.new do
    file = File.open("out.txt", "w")
    result_arr = Ractor.receive
    result_arr.each { |rarr|
         file.write '| ' + rarr[0].name.ljust(20) + ' | ' + rarr[0].weight_class.to_s.rjust(3) + ' | ' + rarr[0].total.to_s.rjust(5) + ' | ' + rarr[1].ljust(10) + " |\n"
    }
    file.write "Number of results: %d" % result_arr.size
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
        log << "Recevied form main"
        wr << l
        log << "Sent to worker " + wr.to_s
    }
    loop do
        if w
            l = Ractor.receive
            log << "Recevied form main"
            w << l
            log << "Sent to worker " + w.to_s
        end
        if l == nil
            log << "Signal for no more data from main"
            break
        end
        w, resul = Ractor.select *work
        log << "Took from worker " + w.to_s
        if resul
            res << resul
            log << "Sent to results " + res.to_s
        else
            log << "Element filtered out by worker " + w.to_s
        end
    end
    work.delete w
    work.each{
        _r, resul = Ractor.select *work
        log << "Took from worker " + _r.to_s
        work.delete _r
        res << resul
        log << "Sent to results " + res.to_s
    }
    res << nil
    log << "Sent signal for no more data to results " + res.to_s
    out << res.take
    log << "Sent results to output " + out.to_s
    log << nil
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
