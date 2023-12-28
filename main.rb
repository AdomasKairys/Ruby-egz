require 'json'
require 'ractor'
require './Lifter.rb'
require './Utils.rb'
require 'digest/sha2'

=begin
proccessor: Intel core i3-12100F, 4 cores 3.3 GHz up to 4.3 GHz, 8 threads
single worker with N = 100_000
time: 8.967 s
with 4 workers with N = 100_000
time: 4.896 s
=end
NUM_WOR = 4
N = 100_000

lifters = Utils.read_json('Data/IF11_KairysA_LD1_dat2.json')
Ractor.make_shareable(lifters) #important so that when sending it sends the same object and not a deep copy

worker = NUM_WOR.times.map{
    Ractor.new Digest::SHA256 do |sh|
        hash = ""
        while l = Ractor.receive
            string = l.name + l.weight_class.to_s + '%.6f'%l.total.to_s #.6 because that was default with c++
            #sleep 0.01
            N.times do
                hash = Utils.generate_hash(sh, string)
            end
            unless hash[0].match /[0-9]/
                Ractor.yield [l,hash]
            else
                Ractor.yield nil
            end
        end
    end
}

result = Ractor.new do
    hashed_lifters=[]
    while l = Ractor.receive
        insert_at = hashed_lifters.bsearch_index { |hl|
            hl[0].weight_class < l[0].weight_class || (hl[0].weight_class == l[0].weight_class && hl[0].total <= l[0].total)
        }
        if insert_at #bsearch_index returns nil if the obj needs to be placed at the end
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
    l = nil
    is_finished = false

    #pre populating workers
    work.each{ |wr|
        l = Ractor.receive
        log << "Recevied form main"
        wr << l
        log << "Sent to worker " + wr.to_s
    }
    until work.empty?
        unless is_finished
            l = Ractor.receive
            log << "Recevied form main"
            is_finished = l == nil
        end

        w, resul = Ractor.select *work
        log << "Took from worker " + w.to_s
        if resul
            res << resul
            log << "Sent to results " + res.to_s
        else
            log << "Element filtered out by worker " + w.to_s
        end

        if is_finished
            log << "Worker stopped working " + w.to_s
            work.delete w
        else
            w << l
            log << "Sent to worker " + w.to_s
        end
    end

    res << nil
    log << "Sent signal for no more data to results " + res.to_s
    out << res.take
    log << "Sent results to output " + out.to_s
    log << nil
    out.take
    log.take
    Ractor.yield true
end

if lifters.size < NUM_WOR
    raise "File can't have less entries than workers"
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
