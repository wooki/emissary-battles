require 'pp'
require 'logger'
require 'humanize'

# resolve a battle between two armies in Emissary game
# based on combat system of battlemist

BATTLE_FOOTMEN_ROUTE = 6 # enemy units hit in random order
BATTLE_FOOTMEN_KILL = 1.5
BATTLE_ARCHER_ROUTE = 4 # enemy archers hit last, others random
BATTLE_ARCHER_KILL = 1.2
BATTLE_CAVALRY_ROUTE = 7 # enemy cavalry hit first, others random
BATTLE_CAVALRY_KILL = 3.5
BATTLE_SHIP_ROUTE = 6
BATTLE_SHIP_KILL = 1

BATTLE_FOOTMEN_RALLY_CHANCE = 0.05 # 5%
BATTLE_ARCHER_RALLY_CHANCE = 0.04 # 4%
BATTLE_CAVALRY_RALLY_CHANCE = 0.15 # 15%
BATTLE_SHIP_RALLY_CHANCE = 0.25 # 25%

module Emissary
class Battle

	attr_accessor :summary, :weather, :terrain, :advantage, :troops, :routed, :elite, :format, :premature_end, :events

	def initialize(logger=Logger.new(STDOUT), weather=:mild, terrain=:lowland, advantage=nil)

		@logger = logger
		@already_resolved = false # only allow resolve once
		self.weather = weather
		self.terrain = terrain
		self.advantage = advantage
		@premature_end = 0
		@summary = nil
		@events = []

		@troops = Hash.new
		@routed = Hash.new
		@elite = Hash.new

		self.side(:a, 0, 0, 0)
		self.side(:b, 0, 0, 0)
	end

	def premature_end(round)
		@premature_end = round
	end

	# rain, snow, cold, hot, fog
	# weather can effect certain units differently
	# rain, footmen and cavalry penalised
	# snow, footmen and cavalry penalised
	# cold, archers penalised
	# hot, footmen penalised
	# fog, archers penalised - all kill results reduced
	def weather=(weather=nil)
		@weather = weather
	end

	# hill, river, mountain, desert, forest, plains, siege
	# terrain can give an advantage to certain units differently,
	# also to only one side in some instances, and combine with weather
	# hill, footmen and archers advantage - advantage side only
	# river, footmen penalised - disadvantage side only. WITH rain disadvantage is worse
	# mountain, cavalry penalised. footmen advantage - advantage side only
	# desert, advantage to cavalry - advantage side only
	# forest, advantage to archers - advantage side only
	# plains, advantage to cavalry, both sides
	# siege, advantage side is the defender and gets advantage to footmen and archers but disadvantage to cavalry
	def terrain=(terrain=nil)
		@terrain = terrain
	end

	# which side has the advantage of the terrain
	def advantage=(side=nil)
		@advantage = side
	end

	# set a sides elite data for a specific type
	def elite(side, troops, value)
		@elite[side] = Hash.new if !@elite[side]
		@elite[side][troops] = value
	end

	# set up a sea battle
	def fleet(side, ships=0)
		@troops[side] = {
			:ships => ships
		}
		@routed[side] = {
			:ships => 0
		}
	end

	# set up a standard side in a land battle
	def side(side, footmen=0, archers=0, cavalry=0)
		@troops[side] = {
			:footmen => footmen,
			:archers => archers,
			:cavalry => cavalry
		}
		@routed[side] = {
			:footmen => 0,
			:archers => 0,
			:cavalry => 0
		}
	end

	# random number and return result as array [routed, killed]
	def attack(route, kill)
		result = [0, 0]
		roll = rand(0.0..10.0)
		if roll <= kill.to_f
			result[1] = 1
		elsif roll <= route.to_f
			result[0] = 1
		end
		result
	end

	# evaluate multiple attacks
	def attacks(number, route, kill)
		return {:route => 0, :kill => 0} if number <= 0

		all_attacks = Array.new(number) do | i |
			self.attack(route, kill)
		end
		all_attacks = all_attacks.transpose.map {|x| x.reduce(:+)}
		{:route => all_attacks[0], :kill => all_attacks[1]}
	end

	def attack_stats_footman(side=nil)

		base = {:route => BATTLE_FOOTMEN_ROUTE, :kill => BATTLE_FOOTMEN_KILL}

		# special rules for terrain
		if @terrain == :hill and @advantage == side

			base[:route] = base[:route] + 1

		elsif @terrain == :mountain and @advantage == side

			base[:route] = base[:route] + 1
			base[:kill] = base[:kill] + 1

		elsif @terrain == :river and @weather == :rain and @advantage != side

			base[:route] = base[:route] - 2

		elsif @terrain == :river and @advantage != side

			base[:route] = base[:route] - 1

		elsif @terrain == :siege and @advantage == side

			base[:route] = base[:route] + 1
			base[:kill] = base[:kill] + 4

		elsif @terrain == :siege and @advantage != side

			base[:route] = base[:route] - 4

		end

		# special rules for weather (independent of terrain)
		if @weather == :rain

			base[:route] = base[:route] - 1

		elsif @weather == :snow

			base[:route] = base[:route] - 1

		elsif @weather == :hot

			base[:route] = base[:route] - 1

		elsif @weather == :fog

			base[:kill] = base[:kill] - 1

		end

		base
	end

	def attack_stats_archers(side=nil)

		base = {:route => BATTLE_ARCHER_ROUTE, :kill => BATTLE_ARCHER_KILL}

		# special rules for terrain
		if @terrain == :hill and @advantage == side

			base[:route] = base[:route] + 1

		elsif @terrain == :forest and @advantage == side

			base[:kill] = base[:kill] + 1

		elsif @terrain == :siege and @advantage == side

			base[:route] = base[:route] + 1
			base[:kill] = base[:kill] + 4

		elsif @terrain == :siege and @advantage != side

			base[:route] = base[:route] - 4

		end

		# special rules for weather (independent of terrain)
		if @weather == :cold

			base[:route] = base[:route] - 1
			base[:kill] = base[:kill] - 1

		elsif @weather == :fog

			base[:route] = base[:route] - 1
			base[:kill] = base[:kill] - 1

		end

		base
	end

	def attack_stats_cavalry(side=nil)

		base = {:route => BATTLE_CAVALRY_ROUTE, :kill => BATTLE_CAVALRY_KILL}

		# special rules for terrain
		if @terrain == :mountain

			base[:route] = base[:route] - 3
			base[:kill] = base[:kill] - 1

		elsif @terrain == :desert and @advantage == side

			base[:route] = base[:route] + 2

		elsif @terrain == :plains

			base[:route] = base[:route] + 1

		elsif @terrain == :siege

			base[:route] = base[:route] - 6
			base[:kill] = base[:kill] - 3

		end

		# special rules for weather (independent of terrain)
		if @weather == :rain

			base[:route] = base[:route] - 1

		elsif @weather == :snow

			base[:route] = base[:route] - 1

		elsif @weather == :fog

			base[:route] = base[:route] - 1
			base[:kill] = base[:kill] - 1

		end

		base
	end

	def attack_stats_ship(side=nil)

		base = {:route => BATTLE_SHIP_ROUTE, :kill => BATTLE_SHIP_KILL}

		if @weather == :rain
			base[:route] = base[:route] + 1
			base[:kill] = base[:kill] - 1
		elsif @weather == :fog
			base[:route] = base[:route] + 2
			base[:kill] = base[:kill] - 2
		end

		if @advantage == side
			base[:route] = base[:route] + 1
			base[:kill] = base[:kill] + 1
		end

		base
	end

	# get the route/kill numbers for specific side, including terrain, weather and advantage
	def attack_stats(type=:footmen, side=nil)

		if type == :footmen

			stats = self.attack_stats_footman(side)

		elsif type == :archers

			stats = self.attack_stats_archers(side)

		elsif type == :cavalry

			stats = self.attack_stats_cavalry(side)

		elsif type == :ships

			stats = self.attack_stats_ship(side)

		else
			raise "Unkown type: #{type.to_s}"
		end

		if @elite[side] && @elite[side][type]
			stats[:route] = stats[:route] + (stats[:route]*@elite[side][type].to_f)
		end
		stats
	end

	# checks if any of the first choice troops are present and if so picks on
	# randomly, if not then tries with the second
	def choose_target(side, first_choices=[:footmen, :archers, :cavalry, :ships], second_choices=[])

		availible_first_choices = first_choices.map do | choice |
			if @troops[side][choice] > 0
				Array.new(@troops[side][choice], choice)
			else
				nil
			end
		end
		availible_first_choices = [] if !availible_first_choices
		availible_first_choices.flatten!
		availible_first_choices.compact!

		if availible_first_choices.length > 0

			availible_first_choices.sample

		else
			# check if we have any second choices
			availible_second_choices = second_choices.map do | choice |
				if @troops[side][choice] > 0
					Array.new(@troops[side][choice], choice)
				else
					nil
				end
			end
			availible_second_choices = [] if !availible_second_choices
			availible_second_choices.flatten!
			availible_second_choices.compact!
			if availible_second_choices.length > 0

				availible_second_choices.sample

			else
				nil
			end
		end
	end

	def make_attack(type, first_targets, second_targets)

		# calculate the two attacks
		a_stats = self.attack_stats(type, :a)
		a_attack = self.attacks(@troops[:a][type], a_stats[:route], a_stats[:kill])

		b_stats = self.attack_stats(type, :b)
		b_attack = self.attacks(@troops[:b][type], b_stats[:route], b_stats[:kill])

		# prep a line for the summary
		attack_summary = {
			:title => type.to_s.capitalize,
			:a_attack => a_attack,
			:b_attack => b_attack,
			:a_casualties => [],
			:b_casualties => [],
			:a_routed => [],
			:b_routed => []
		}

		# assign routed and casualties, random between footmen and cavalry, archers last
		(1..a_attack[:kill]).each do | i |
			killed = self.choose_target(:b, first_targets, second_targets)
			if killed
				attack_summary[:b_casualties].push(killed)
				@troops[:b][killed] = @troops[:b][killed] - 1
			end
		end
		(1..b_attack[:kill]).each do | i |
			killed = self.choose_target(:a, first_targets, second_targets)
			if killed
				attack_summary[:a_casualties].push(killed)
				@troops[:a][killed] = @troops[:a][killed] - 1
			end
		end
		(1..a_attack[:route]).each do | i |
			routed = self.choose_target(:b, first_targets, second_targets)
			if routed
				attack_summary[:b_routed].push(routed)
				@troops[:b][routed] = @troops[:b][routed] - 1
				@routed[:b][routed] = @routed[:b][routed] + 1
			end
		end
		(1..b_attack[:route]).each do | i |
			routed = self.choose_target(:a, first_targets, second_targets)
			if routed
				attack_summary[:a_routed].push(routed)
				@troops[:a][routed] = @troops[:a][routed] - 1
				@routed[:a][routed] = @routed[:a][routed] + 1
			end
		end

		attack_summary
	end

	def attack_summary_to_events(attack_summary)

    [
      attack_summary[:a_attack][:kill] > 0 || attack_summary[:a_attack][:route] > 0 ? "#{attack_summary[:title]} from side A attacked#{attack_summary[:a_attack][:kill] > 0 ? " killing #{attack_summary[:a_attack][:kill]} regiments" : ""}#{attack_summary[:a_attack][:route] > 0 ? " and routing #{attack_summary[:a_attack][:route]} regiments" : ""} on side B." : nil,
      attack_summary[:b_attack][:kill] > 0 || attack_summary[:b_attack][:route] > 0 ? "#{attack_summary[:title]} from side B attacked#{attack_summary[:b_attack][:kill] > 0 ? " killing #{attack_summary[:b_attack][:kill]} regiments" : ""}#{attack_summary[:b_attack][:route] > 0 ? " and routing #{attack_summary[:b_attack][:route]} regiments" : ""} on side A." : nil,
    ].compact
	end

	# make attacks for both sides of archers
	def archers
		attack = self.make_attack(:archers, [:footmen, :cavalry], [:archers])
		@logger.debug attack
		@events.concat(self.attack_summary_to_events(attack))
	end

	# make attacks for both sides of cavalry
	def cavalry
		attack = self.make_attack(:cavalry, [:cavalry], [:archers, :footmen])
		@logger.debug attack
		@events.concat(self.attack_summary_to_events(attack))
	end

	# make attacks for both sides of footmen
	def footmen
		attack = self.make_attack(:footmen, [:footmen, :cavalry, :archers], [])
		@logger.debug attack
		@events.concat(self.attack_summary_to_events(attack))
	end

	# make attacks for both sides of ships
	def ships
		attack = self.make_attack(:ships, [:ships], [])
		@logger.debug attack
		@events.concat(self.attack_summary_to_events(attack))
	end

	def rally_check(side, type, chance)
		return 0 if !@routed[side][type]

		modified_chance = chance
		if @elite[side] && @elite[side][type]
			modified_chance = chance + (chance * @elite[side][type].to_f)
		end

    count = 0
		(1..@routed[side][type]).each do | i |
			if rand() < modified_chance
				@routed[side][type] = @routed[side][type] - 1
				@troops[side][type] = @troops[side][type] + 1
				count = count + 1
      end
		end
		count
	end

	def rally_summary_to_events(rally_summary)

  		events = []

  		[:a, :b].each do |side|
  			rallied_troops = rally_summary[side].values.sum
  			if rallied_troops > 0
  				unit_types = rally_summary[side].select { |_, count| count > 0 }
  					.map { |type, count| "#{count} regiments of #{type}" }
  					.join(", ")
  				events << "Side #{side.to_s.upcase} rallied #{rallied_troops} regiments, which included #{unit_types}."
  			end
  		end

  		events

	end

	# check all routed units and see if they rejoin
	def rally

		rally_summary = {:title => "Rally"}
		rally_summary[:a] = {
			:footmen => self.rally_check(:a, :footmen, BATTLE_FOOTMEN_RALLY_CHANCE),
			:archers => self.rally_check(:a, :archers, BATTLE_ARCHER_RALLY_CHANCE),
			:cavalry => self.rally_check(:a, :cavalry, BATTLE_CAVALRY_RALLY_CHANCE),
			:ships => self.rally_check(:a, :ships, BATTLE_SHIP_RALLY_CHANCE)
		}
		rally_summary[:b] = {
			:footmen => self.rally_check(:b, :footmen, BATTLE_FOOTMEN_RALLY_CHANCE),
			:archers => self.rally_check(:b, :archers, BATTLE_ARCHER_RALLY_CHANCE),
			:cavalry => self.rally_check(:b, :cavalry, BATTLE_CAVALRY_RALLY_CHANCE),
			:ships => self.rally_check(:b, :ships, BATTLE_SHIP_RALLY_CHANCE)
		}


		@logger.debug rally_summary.pretty_inspect

		@events.concat rally_summary_to_events(rally_summary)

	end

	# run one round of combat, returns :a, :b, :ab for overrun
	def round(i)

		@logger.debug({
			:title => "Round #{i}",
			:troops => @troops,
			:routed => @routed
		}).pretty_inspect

		# default to no overrun each round
		overrun = nil

		if i > 0
			# rally check for all routes units
			self.rally

			# check each side for no remaining footmen (or ships)
			if (@troops[:a][:ships] and @troops[:a][:ships] > 0) or (@troops[:b][:ships] and @troops[:b][:ships] > 0)

				if @troops[:a][:ships] > 0 and @troops[:b][:ships] <= 0
					overrun = :b
				elsif @troops[:b][:ships] > 0 and @troops[:a][:ships] <= 0
					overrun = :a
				end
			else
				if @troops[:a][:footmen] > 0 and @troops[:b][:footmen] <= 0
					overrun = :b
				elsif @troops[:b][:footmen] > 0 and @troops[:a][:footmen] <= 0
					overrun = :a
				elsif @troops[:b][:footmen] <= 0 and @troops[:a][:footmen] <= 0
					overrun = :ab
				end
			end
		end

		if !overrun
			if @troops[:a][:ships] and @troops[:a][:ships] > 0 or @troops[:b][:ships] and @troops[:b][:ships] > 0

				# ships fight
				self.ships

			else
				# archers fire
				self.archers

				# cavalry fight
				self.cavalry

				# footmen fight
				self.footmen
			end
		end

		# return when overrun, so we can stop running rounds
		overrun
	end

	def resolve

		return if @already_resolved

		# remember troops before combat
		@starttroops = Marshal.load(Marshal.dump(@troops))

		# run rounds until one side overrun
		round = 0
		overrun = nil
		while !overrun and (@premature_end == 0 or @premature_end > round) do
			overrun = self.round(round)
			round = round + 1
		end

		# winning side gets one extra combat round - a chance ot get extra casualties
		result_title = "Draw"
		if overrun == :a
				@events << "Side A was routed and fled the battlefield."
				result_title = "Victory for B"
		elsif overrun == :b
			@events << "Side B was routed and fled the battlefield."
				result_title = "Victory for A"
		end

		# add the routed troops back on to the troops,
		# with some desserters
		self.rally_check(:a, :footmen, 0.9)
		self.rally_check(:a, :archers, 0.9)
		self.rally_check(:a, :cavalry, 0.9)
		self.rally_check(:a, :ships, 0.9)
		self.rally_check(:b, :footmen, 0.9)
		self.rally_check(:b, :archers, 0.9)
		self.rally_check(:b, :cavalry, 0.9)
		self.rally_check(:b, :ships, 0.9)

    # any still routed units become mercenaries
    @routed[:a][:footmen] = @routed[:a][:footmen] + @routed[:b][:footmen] if @routed[:a][:footmen]
    @routed[:a][:archers] = @routed[:a][:archers] + @routed[:b][:archers] if @routed[:a][:archers]
    @routed[:a][:cavalry] = @routed[:a][:cavalry] + @routed[:b][:cavalry] if @routed[:a][:cavalry]
		@routed[:a][:ships] = @routed[:a][:ships] + @routed[:b][:ships] if @routed[:a][:ships]

		@summary = {
			:title => result_title,
			:length => round,
			:overrun => overrun,
			:advantage => @advantage,
			:terrain => @terrain,
			:weather => @weather,
			:starttroops => @starttroops,
			:troops => @troops,
			:mercenaries => @routed[:a]
		}

		@logger.debug @summary.pretty_inspect
		@summary
	end

	def ai_prompt(side_a_name, side_b_name, location)
		result = "a draw"
		if @summary[:overrun] == :a
			result = "victory for #{side_b_name}"
		elsif @summary[:overrun] == :b
			result = "victory for #{side_a_name}"
		end

		troop_types = [:footmen, :archers, :cavalry, :ships]
		has_ships = @summary[:starttroops][:a][:ships] != nil && @summary[:starttroops][:b][:ships] != nil &&
		(@summary[:starttroops][:a][:ships] > 0 || @summary[:starttroops][:b][:ships] > 0)

		troop_description = lambda do |side, time|
			troops = troop_types.select { |t| has_ships ? t == :ships : t != :ships }
			troops.map { |t| "#{(@summary[time][side][t]*100).humanize} hundred #{t}" }.join(", ")
		end

		focus = ['strategy', 'heroism', 'weather impact', 'terrain challenges', 'morale', 'casualties and the aftermath'].sample
		perspectives = ['a foot soldier', 'a general', 'a local villager observing', 'a historian', 'a storyteller', 'a gamesmaster'].sample
		tone = ['triumphant', 'somber', 'chaotic', 'awe-inspiring', 'epic', 'tense', 'grim', 'melancholic', 'tragic', 'victorious', 'glorious'].sample

		instructions = <<-TEXT
	Describe a medieval battle between #{side_a_name} and #{side_b_name} that has taken place at #{location}.
	The battle was fought in #{@summary[:terrain]} terrain and the weather was #{@summary[:weather]}.
	Describe the terrain and weather in more detail or not at all if it is not relevant.
	Incorporate sensory details like the sounds of battle, the smell of the battlefield, and the sight of the terrain.
	Highlight the actions and decisions of key characters or leaders on both sides without mentioning their names.
	Use dynamic and varied language to keep the narrative engaging and avoid repetition.
	Focus on the #{focus} and how it influenced the battle's outcome.
	Tell the story from the perspective of #{perspectives}.
	Do not mention this perspective in the description.
	Tell the story with a #{tone} tone.
	Do not use a precise time for the battle but give a sense of when it happened and how long it lasted if possible.
	The army of #{side_a_name} consisted of #{troop_description.call(:a, :starttroops)}.
	The army of #{side_b_name} consisted of #{troop_description.call(:b, :starttroops)}.
	The battle lasted for #{@summary[:length] * 0.5} hours and commenced as follows (with side A being #{side_a_name} and side B being #{side_b_name}):
	#{@events.map { |e| e.to_s }.join("\n")}
	The battle ended with #{result}.
	Highlight where and why the battle ended as it did.
	After the battle the army of #{side_a_name} consisted of #{troop_description.call(:a, :troops)}.
	After the battle the army of #{side_b_name} consisted of #{troop_description.call(:b, :troops)}.
	When referring to the number of troops, it will always be a battle with ships or with land troops, not a mix of both.
	Keep the summary to a maximum of #{50 + (@summary[:length] * 25)} words.
	Include actions or events that reflect the numbers of troops on each side and how that changed from the start and end of the battle.
	TEXT

		instructions.split("\n").join(" ").gsub(/\s+/,' ').strip
	end
end
end