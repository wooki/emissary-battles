# Very Simple Battle Resolver
Starting with two definitions of armies work how who wins.

Import some utils.
```
require 'pp'
require 'logger'
require 'very-simple-battle-resolver'
```

Setup some logging.
```
logger = Logger.new STDOUT
logger.level = Logger::WARN
# logger.level = Logger::INFO
```

Allow rerunning with the same results.
```
SEED = Random.new_seed
puts "SEED: #{SEED}"
Random.srand(SEED)
```

Create a new battle and set-up the parameters.
```
b = Battle.new(logger)

# set one side to have the advantage
b.advantage = :a

# set terrain
# b.weather = :mild
# b.weather = :rain
# b.weather = :cold
b.weather = :snow
# b.weather = :hot
# b.weather = :fog


# set terrain being fought in
b.terrain = :hill
# b.terrain = :mountain
# b.terrain = :river
# b.terrain = :siege
# b.terrain = :forest
# b.terrain = :desert

# setup two sides
b.side(:a, footmen=800, archers=1000, cavalry=300)
b.side(:b, footmen=1000, archers=1400, cavalry=400)

# optionally set one type of troops to be elite on either side
# and set the elite bonux
# e.g. side b has archers who are 10% better than normal.
b.elite(:b, :archers, 0.1)

# fleet battles use fleet method instead of side
# b.fleet(:a, 12)
# b.fleet(:b, 12)
# b.elite(:b, :ships, 0.1)

# can set a maximum number of rounds to fight, useful
# for righting a siege that will be broken after x turns
# b.premature_end(3)

# run the battle and print the result
pp b.resolve
```

An example return
```
# :title=>"Victory for B",
#  :length=>4,
#  :overrun=>:a,
#  :troops=>
#   {:a=>{:footmen=>7, :archers=>7, :cavalry=>2},
#    :b=>{:footmen=>7, :archers=>13, :cavalry=>2}},
#  :mercenaries=>{:footmen=>1, :archers=>0, :cavalry=>0}}
```
