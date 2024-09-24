# Emissary Battles
Starting with two definitions of armies work how who wins.

Test on the command line
```
emissary-battle-demo
```

Import some utils.
```
require 'pp'
require 'logger'
require 'emissary-battles'
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
b = Emissary::Battle.new(logger)

# b.format = :json

# set one side to have the advantage
# b.advantage = :a

# set terrain
# b.weather = :mild
# b.weather = :rain
# b.weather = :cold
# b.weather = :snow
# b.weather = :hot
# b.weather = :fog


# set terrain being fought in
# b.terrain = :hill
# b.terrain = :mountain
# b.terrain = :river
# b.terrain = :siege
# b.terrain = :forest
# b.terrain = :desert

# setup two sides
b.side(:a, footmen=rand(5..10), archers=rand(5..10), cavalry=rand(5..10))
b.side(:b, footmen=rand(5..10), archers=rand(5..10), cavalry=rand(5..10))

# optionally set one type of troops to be elite on either side
# and set the elite bonux
# e.g. side b has archers who are 10% better than normal.
# b.elite(:b, :archers, 0.1)

# fleet battles use fleet method instead of side
# b.fleet(:a, 12)
# b.fleet(:b, 12)
# b.elite(:b, :ships, 0.1)

# can set a maximum number of rounds to fight, useful
# for righting a siege that will be broken after x turns
# b.premature_end(3)

# run the battle and print the result
b.resolve

puts "AI PROMPT"
puts b.ai_prompt "the Lanisters", "The Starks", "Oxcross"

puts "-"* 50
puts "STARTING TROOPS"
pp b.summary[:starttroops]
puts "-"* 50
puts "END TROOPS"
pp b.summary[:troops]
puts "-"* 50
puts b.summary[:title]
puts "-"* 50
```
