require 'digest/sha2'

class Lifter
    attr_accessor :name, :weight_class, :total
    def initialize(name, weight_class, total)
        @name = name
        @weight_class = weight_class
        @total = total
    end
end
