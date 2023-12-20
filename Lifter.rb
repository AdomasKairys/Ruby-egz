require 'digest'

class Lifter 
    attr_accessor :name, :weight_class, :total, :hash
    def initialize(name, weight_class, total)
        @name = name
        @weight_class = weight_class
        @total = total
        @hash = ""
    end
    def generate_hash()
        @hash = Digest::SHA256.hexdigest @name + @weight_class.to_s + total.to_s
    end
end