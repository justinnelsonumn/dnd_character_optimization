starting_dexterity = 20
starting_intelligence = 16

calculateAverageDamage = function(attacks, damage, defense){
  effective_hit_chance = (attacks - defense + 21) / 20
  effective_hit_chance = sapply(effective_hit_chance, max, 0.05)
  effective_hit_chance = sapply(effective_hit_chance, min, 0.95)
  
  hits = sum(effective_hit_chance)
  
  average_damage = hits * damage
  
  return(average_damage)
}

calculateBAB = function(character_classes){
  monk_levels = sum(character_classes == "monk", na.rm=T)
  high_levels = sum(character_classes != "monk" & character_classes != "any", na.rm=T)
  BAB = high_levels + monk_levels - 1 - floor((monk_levels - 1)/4)
  
  return(BAB)
}

calculateLevel = function(character_classes){ 
  if(is.null(character_classes)) return(0)
  return(sum(!is.na(character_classes))) 
}

getAvailability = function(avail_classes, class){
  if(is.null(avail_classes[[class]])) { 
    return(0) 
  } else {
    if(is.na(avail_classes[[class]])){
      return(0)
    } else {
      return(avail_classes[[class]])
    }
  }
  
}

calculateClassLevel = function(character_classes, class) { return(sum(character_classes == class, na.rm=T)) }

calculateQualifiedClasses = function(avail_classes, character_classes, character_feats){
  global_classes <<- character_classes # character_classes = global_classes
  global_avail <<- avail_classes # avail_classes = global_avail
  global_feats <<- character_feats # character_feats = global_feats
  
  qual_class = c()
  
  if(getAvailability(avail_classes, "fighter")         > calculateClassLevel(character_classes, "fighter")      ){ qual_class = c(qual_class, "fighter")       }
  if(getAvailability(avail_classes, "monk")            > calculateClassLevel(character_classes, "monk")         ){ qual_class = c(qual_class, "monk")          }
  if(getAvailability(avail_classes, "swashbuckler")    > calculateClassLevel(character_classes, "swashbuckler") ){ qual_class = c(qual_class, "swashbuckler")  }
  if(all(c("Dodge", "CE") %in% character_feats) 
     & sum(c("WF(Kukri)", "WF(Kama)") %in% character_feats) 
     & calculateBAB(character_classes) >= 5
     & getAvailability(avail_classes, "dervish")       > calculateClassLevel(character_classes, "dervish")      ){ qual_class = c(qual_class, "dervish")       }
  if(all(c("WF(Kukri)", "Feint") %in% character_feats)
     & (c("dervish") %in% character_classes || calculateLevel(character_classes) >= 14)
     & getAvailability(avail_classes, "invis_blade")   > calculateClassLevel(character_classes, "invis_blade")  ){ qual_class = c(qual_class, "invis_blade")   }
  if(all(c("WF(Kama)", "Dodge", "Mobility", "WhirlwindAttack", "CE") %in% character_feats)
     & calculateBAB(character_classes) >=5
     & getAvailability(avail_classes, "weapon_master") > calculateClassLevel(character_classes, "weapon_master")){ qual_class = c(qual_class, "weapon_master") }
  
  if(length(unique(character_classes[!is.na(character_classes)])) == 4){ qual_class = qual_class[qual_class %in% character_classes] }
  if(calculateLevel(character_classes) >= 20)                          { qual_class = qual_class[qual_class %in% character_classes] }

  ## 3b20 rule, if we are already about to run into it, I cannot select a new class.
  if(calculateLevel(character_classes) >= 15 & calculateLevel(character_classes) <= 20){ 
    class_table = sapply(3-table(character_classes), max, 0)
    class_table["any"] = 0
    if(calculateLevel(character_classes) + sum(class_table) + 3 >= 21){ 
      qual_class = qual_class[qual_class %in% character_classes]
    }
  }
  
  if(length(qual_class) == 0) return(c("any"))
  return(qual_class)
}

lastCharacterClass = function(character_classes){ 
  last_class_index = which(is.na(character_classes))[1]-1
  if(is.na(last_class_index)) return(character_classes[length(character_classes)])
  return(character_classes[which(is.na(character_classes))[1]-1]) 
}

calculateFighterLevel = function(character_classes) { return(sum(character_classes == "fighter", na.rm=T)) }
calculateMonkLevel = function(character_classes) { return(sum(character_classes == "monk", na.rm=T)) }
calculateDervishLevel = function(character_classes) { return(sum(character_classes == "dervish", na.rm=T)) }
calculateIBLevel = function(character_classes) { return(sum(character_classes == "invis_blade", na.rm=T)) }
calculateWMLevel = function(character_classes) { return(sum(character_classes == "weapon_master", na.rm=T)) }
calculateSBlevel = function(character_classes) { return(sum(character_classes == "swashbuckler", na.rm=T)) }


prereq_feats = c("CE", "WF(Kukri)", "Feint", "Mobility", "SpringAttack", "WhirlwindAttack")

calculateQualifiedFeats = function(character_classes, character_feats){
  qual_feats = c("TWF", "Dodge", "CE", "PowerfulCharge")
  
  dexterity = starting_dexterity + calculateLevel(character_classes) / 4
  if("GreatDex1" %in% character_feats) dexterity = dexterity + 1
  
  if(calculateBAB(character_classes) >= 1
     & calculateSBlevel(character_classes) == 0) qual_feats = c(qual_feats, c("Weap_Fin"))
  if(calculateBAB(character_classes) >= 1
     & "fighter" %in% character_classes) qual_feats = c(qual_feats, "WF(Kukri)")
  if(calculateBAB(character_classes) >= 1
     & "monk" %in% character_classes) qual_feats = c(qual_feats, "WF(Kama)")
  if("CE" %in% character_feats) qual_feats = c(qual_feats, c("Feint", "Deadly_defense"))
  if(calculateBAB(character_classes) >= 6
     & "TWF" %in% character_feats) qual_feats = c(qual_feats, "ITWF")
  if(calculateBAB(character_classes) >= 11
     & "ITWF" %in% character_feats) qual_feats = c(qual_feats, "GTWF")
  if(calculateLevel(character_classes) >= 21
     & "GTWF" %in% character_feats
     & dexterity >= 25) qual_feats = c(qual_feats, "PTWF")
  if(calculateLevel(character_classes) >= 21) qual_feats = c(qual_feats, c("GreatDex1", "EpicProwess"))
  if(calculateLevel(character_classes) >= 21
     & all(c("EpicProwess", "CE") %in% character_feats)) qual_feats = c(qual_feats, "CombatInsight")
  if(calculateLevel(character_classes) >= 21
     & sum(character_classes == "dervish", na.rm=T) >= 6) qual_feats = c(qual_feats, "EpicCharge")
  if(calculateFighterLevel(character_classes) >= 4
     & "WF(Kama)" %in% character_feats) qual_feats = c(qual_feats, "WS")
  if("Dodge" %in% character_feats) qual_feats = c(qual_feats, "Mobility")
  if(calculateBAB(character_classes) >= 4
     & "Mobility" %in% character_feats) qual_feats = c(qual_feats, "SpringAttack")
  if(calculateBAB(character_classes) >= 4
     & all(c("Dodge", "Mobility", "CE") %in% character_feats)
     & ("SpringAttack" %in% character_feats || calculateDervishLevel(character_classes) >= 3) ) qual_feats = c(qual_feats, "WhirlwindAttack")
  if(calculateFighterLevel(character_classes) >= 8
     & "WF(Kama)" %in% character_feats) qual_feats = c(qual_feats, "GWF")
  if(calculateFighterLevel(character_classes) >= 12
     & all(c("GWF", "WS") %in% character_feats)) qual_feats = c(qual_feats, "GWS")
  if(calculateFighterLevel(character_classes) >= 12) qual_feats = c(qual_feats, "WeaponMastery")
  if(calculateLevel(character_classes) >= 21
     & "GWF" %in% character_feats
     & calculateFighterLevel(character_classes) >= 12) qual_feats = c(qual_feats, "EWF")
  if(calculateLevel(character_classes) >= 21
     & all(c("GWs", "EWF") %in% character_feats)
     & calculateFighterLevel(character_classes) >= 12) qual_feats = c(qual_feats, "EWS")
  if(calculateBAB(character_classes) >= 8) qual_feats = c(qual_feats, "IC")
  qual_feats = qual_feats[!qual_feats %in% character_feats]
  if(length(qual_feats) == 0) return(c("any"))
  return(qual_feats)
}

calculateNumberOfNewFeats = function(character_classes){
  number_of_feats = 0
  if(calculateLevel(character_classes) == 1) number_of_feats = number_of_feats+1
  if(calculateLevel(character_classes) <= 20 & calculateLevel(character_classes) %% 3 == 0) number_of_feats = number_of_feats+1
  if(calculateLevel(character_classes) >  20 & calculateLevel(character_classes) %% 2 == 1) number_of_feats = number_of_feats+1
  if(lastCharacterClass(character_classes) == "fighter" & calculateFighterLevel(character_classes) == 1) number_of_feats = number_of_feats+1
  if(lastCharacterClass(character_classes) == "fighter" & calculateFighterLevel(character_classes) %% 2 == 0) number_of_feats = number_of_feats+1
  return(number_of_feats)
}

calculateAttacks = function(character_classes, character_feats, burst=T){
  BAB = calculateBAB(character_classes)
  attack_bonus = 0
  dexterity = starting_dexterity + calculateLevel(character_classes) / 4
  if("GreatDex1" %in% character_feats) dexterity = dexterity + 1
  main_hand_attacks = c()
  off_hand_attacks = c()
  
  number_of_attacks = max(floor((BAB-1)/5)+1, 1)
  number_off_hand_attacks = 1
  
  if("ITWF" %in% character_feats) number_off_hand_attacks = number_off_hand_attacks + 1
  if("GTWF" %in% character_feats) number_off_hand_attacks = number_off_hand_attacks + 1
  if("PTWF" %in% character_feats) number_off_hand_attacks = number_of_attacks
  
  if(calculateMonkLevel(character_classes) >= 1) {
    number_of_attacks = number_of_attacks + 2
    number_off_hand_attacks = number_off_hand_attacks + 1
  }
  if(calculateMonkLevel(character_classes) >= 11) {
    number_of_attacks = number_of_attacks + 1
    number_off_hand_attacks = number_off_hand_attacks + 1
  }
  
  

  if(calculateMonkLevel(character_classes) <= 4) attack_bonus = attack_bonus - 1
  if(calculateMonkLevel(character_classes) <= 8) attack_bonus = attack_bonus - 1
  
  attack_bonus = attack_bonus + 4 #Enhancement Bonus
  
  if(!("TWF" %in% character_feats)) number_off_hand_attacks = 0
  if("Weap_Fin" %in% character_feats
     || calculateSBlevel(character_classes) >= 1) attack_bonus = attack_bonus + floor((dexterity - 10) / 2)
  if("EpicProwess" %in% character_feats) attack_bonus = attack_bonus + 1
  if("WF(Kama)" %in% character_feats) attack_bonus = attack_bonus + 1
  if("GWF" %in% character_feats) attack_bonus = attack_bonus + 1
  if("EWF" %in% character_feats) attack_bonus = attack_bonus + 2
  if("WeaponMastery" %in% character_feats) attack_bonus = attack_bonus + 2
  if("Deadly_defense" %in% character_feats) attack_bonus = attack_bonus - 3

  if(calculateWMLevel(character_classes) >= 5) attack_bonus = attack_bonus + 1
  if(burst) {
    attack_bonus = attack_bonus + floor(((calculateDervishLevel(character_classes) - 1) / 2) + 1)
    if("EpicCharge" %in% character_feats) attack_bonus = attack_bonus + 4
  }

  top_attack_bonus = BAB + attack_bonus
  
  if(calculateMonkLevel(character_classes) >= 1)  { main_hand_attacks = c(main_hand_attacks, top_attack_bonus); number_of_attacks = number_of_attacks - 1; }
  if(calculateMonkLevel(character_classes) >= 11) { main_hand_attacks = c(main_hand_attacks, top_attack_bonus); number_of_attacks = number_of_attacks - 1; }
  
  if(calculateMonkLevel(character_classes) >= 1 & number_off_hand_attacks > 0)   { off_hand_attacks = c(off_hand_attacks, top_attack_bonus); number_off_hand_attacks = number_off_hand_attacks - 1; }
  if(calculateMonkLevel(character_classes) >= 11 & number_off_hand_attacks > 0)  { off_hand_attacks = c(off_hand_attacks, top_attack_bonus); number_off_hand_attacks = number_off_hand_attacks - 1; }
  
  main_hand_attacks = c(main_hand_attacks, seq(from=top_attack_bonus, to=top_attack_bonus-5*(number_of_attacks-1), by=-5))
  if(number_off_hand_attacks > 0) off_hand_attacks = c(off_hand_attacks, seq(from=top_attack_bonus, to=top_attack_bonus-5*(number_off_hand_attacks-1), by=-5))
  
  attacks = c(main_hand_attacks, off_hand_attacks)
  return(attacks)
}

calculateDamage = function(character_classes, character_feats, burst=T){
  damage = 0
  crit_chance = 1
  crit_multiplier = 2
  damage = damage + 7/2 # Kama Base Damage
  damage = damage + 4 # Enhancement Bonust

  if("Deadly_defense" %in% character_feats) damage = damage + 5/2
  if("CombatInsight" %in% character_feats) damage = damage + floor((starting_intelligence - 10) / 2)
  if("WS" %in% character_feats) damage = damage + 1
  if("GWS" %in% character_feats) damage = damage + 1
  if("EWS" %in% character_feats) damage = damage + 4
  if("WeaponMastery" %in% character_feats) damage = damage + 2
  if(calculateSBlevel(character_classes) >= 5) damage = damage + floor((starting_intelligence - 10) / 2)
  if(calculateDervishLevel(character_classes) == 10) damage = damage + 14/2
  if(calculateWMLevel(character_classes) >= 5) crit_multiplier = crit_multiplier + 1
  if(calculateWMLevel(character_classes) >= 7) crit_chance = crit_chance + 2
  if("IC" %in% character_feats) crit_chance = crit_chance * 2
  
  if(burst){
    damage = damage + ((calculateDervishLevel(character_classes) - 1) / 2) + 1
    if("EpicCharge" %in% character_feats
       & "PowerfulCharge" %in% character_feats) damage = damage + 9/2
  }
  
  damage = (crit_multiplier * damage * crit_chance + damage * (20-crit_chance)) / 20
  damage = damage + 6 * floor((calculateIBLevel(character_classes) + 1) / 2)
  # damage = damage + 5/2 # Fire weapon
  
  return(damage)
}

calculateScore = function(damage_per_level){ return(sum(1:30 * damage_per_level, na.rm=T)) }

outputCharacter = function(build, burst_weight=0.5){
  cat("\n\n")
  char_table = table(build$class)
  cat(paste(names(char_table), char_table,  sep=" ", collapse=" / "))
  cat("\n")
  cat(paste(1:30, ": ", build$class, sep="", collapse=", "))
  cat("\n")
  cat(paste(1:length(build$feats), ": ", build$feats, sep="", collapse="\n"))
  cat("\n")
  build.evaluation = evaluateBuild(build, burst_weight)
  cat("best_score: ")
  cat(build.evaluation$score)
  cat("\n\n")
  cat("damage by level|")
  cat(paste(1:30, ": ", build.evaluation$damage, sep="", collapse=", "))
  cat("\n##############################\n")
  cat("burst by level|")
  cat(paste(1:30, ": ", build.evaluation$burst, sep="", collapse=", "))
  cat("\n##############################\n")
  cat("sustain by level|")
  cat(paste(1:30, ": ", build.evaluation$sustain, sep="", collapse=", "))
  cat("\n\n")
}

levelClass = function(build, avail_classes){
  cur_lv = calculateLevel(build$class)
  if(length(build$potential_classes) < cur_lv+1){
    build$potential_classes[[cur_lv+1]] = calculateQualifiedClasses(avail_classes, build$class, unlist(build$feats))
  }
  
  #build$potential_classes[[cur_lv+1]] = calculateQualifiedClasses(avail_classes, build)
  class_index = sample(1:length( build$potential_classes[[cur_lv+1]] ), 1)
  class_name = build$potential_classes[[cur_lv+1]][class_index]
  build$class[cur_lv+1] = class_name
  build$potential_classes[[cur_lv+1]] = build$potential_classes[[cur_lv+1]][-1 * class_index]
  return(build)
}

selectFeat = function(build, number){
  cur_lv = calculateLevel(build$class)
  if(length(build$potential_feats) < cur_lv){
    build$potential_feats[[cur_lv]] = list()
  }
  if(length(build$potential_feats[[cur_lv]]) < number){
    build$potential_feats[[cur_lv]][[number]] = calculateQualifiedFeats(build$class, unlist(build$feats)) 
  }
  if(number == 1) build$feats[[cur_lv]] = rep(NA, 3)
  
  feat_ind = sample(1:length( build$potential_feats[[cur_lv]][[number]] ), 1)
  feat_name = build$potential_feats[[cur_lv]][[number]][feat_ind]
  build$feats[[cur_lv]][number] = feat_name
  build$potential_feats[[cur_lv]][[number]] = build$potential_feats[[cur_lv]][[number]][-1 * feat_ind]
  
  return(build)
}

levelup = function(build, avail_classes){
  build = levelClass(build, avail_classes)
  number_new_feats = calculateNumberOfNewFeats(build$class)
  if(number_new_feats > 0){
    for(i in 1:number_new_feats){ build = selectFeat(build, i) }
  } else {
    build$potential_feats[[calculateLevel(build$class)]] = list()
  }
  
  return(build)
}

delevel = function(build, avail_classes){
  while(calculateLevel(build$class) > 0){
    if(length(build$potential_feats) < calculateLevel(build$class)){ # There was no feat at this level, defeat
      build$class[calculateLevel(build$class)]             = NA
    } else {
      number_new_feats = calculateNumberOfNewFeats(build$class)
      
      if(number_new_feats > 0){
        for(i in number_new_feats:1){ # set empty potential feat lists to null
          if(length(build$potential_feats[[calculateLevel(build$class)]]) != 0){
            if(length(build$potential_feats[[calculateLevel(build$class)]][[i]]) == 0){ 
              build$potential_feats[[calculateLevel(build$class)]][i] = NULL
            } else {
              break
            }
          }
        }
      }
      
      if(length(build$potential_feats[[calculateLevel(build$class)]]) == 0){ # if there are no more feats for this level
        build$feats[[calculateLevel(build$class)]]           = NULL
        build$potential_feats[[calculateLevel(build$class)]] = NULL
        build$class[calculateLevel(build$class)]             = NA
      } else {
        for(i in length(build$potential_feats[[calculateLevel(build$class)]]):number_new_feats){ build = selectFeat(build, i) } # Relevel
        return(build)
      }
    }
    
    # If the code made it this far, I need to figure out if there are more classes to take, if so level up and break
    if(length(build$potential_classes) >= calculateLevel(build$class)+1){ # Well, there's something there
      if(length(build$potential_classes[[calculateLevel(build$class)+1]]) >= 1){ # Is there a class to take
        build = levelup(build, avail_classes)
        return(build)
      } else { # No class to take, set potential classes to NULL and delevel again
        if(length(build$potential_classes) >= calculateLevel(build$class)+1){
          build$potential_classes[[calculateLevel(build$class)+1]] = NULL
        }
      }
    }
  }
  return(build)
}

multiclassPenalty = function(classes){
  class_names = names(table(classes))
  if(is.null(class_names)) return(0)
  return(sum(!is.na(class_names))* 0.001)
}

evaluateBuild = function(build, burst_weight=0.5){
  
  damage_per_level = rep(0, 30)
  burst_per_level  = rep(0, 30)
  susta_per_level  = rep(0, 30)
  
  for(i in 1:30){
    damage_rolls_burst = calculateDamage(build$class[1:i],  unlist(build$feats[1:i]), TRUE)
    damage_rolls_susta = calculateDamage(build$class[1:i],  unlist(build$feats[1:i]), FALSE)
    attack_rolls_burst = calculateAttacks(build$class[1:i], unlist(build$feats[1:i]), TRUE)
    attack_rolls_susta = calculateAttacks(build$class[1:i], unlist(build$feats[1:i]), FALSE)
    
    defense = i + 10
    
    damage_dealt_burst = calculateAverageDamage(attack_rolls_burst, damage_rolls_burst, defense)
    damage_dealt_susta = calculateAverageDamage(attack_rolls_susta, damage_rolls_susta, defense)
    
    damage_dealt       = damage_dealt_burst*burst_weight + damage_dealt_susta*(1-burst_weight)
    
    damage_per_level[i] = damage_dealt
    burst_per_level[i]  = damage_dealt_burst
    susta_per_level[i]  = damage_dealt_susta
  }
  
  score = calculateScore(damage_per_level) - multiclassPenalty(build$class)

  return(list(damage = damage_per_level,
              burst = burst_per_level,
              sustain = susta_per_level,
              score = score))
}

global_build = list()
blank_prefix_build = list(class = rep(NA, 30),
                          feats = list(),
                          potential_classes = list(),
                          potential_feats = list())
build_character = function(avail_classes, max_level = 30, level_warp = 1, burst_weight=0.5, is.final=T, prefix_build = blank_prefix_build, monoclass_depth=5){
  #if(is.final) ptm = proc.time()
  builds_analyzed = 0
  
  best_build = blank_prefix_build
  best_score = 0
  
  if(max_level > calculateLevel(prefix_build$class) + level_warp){
    build = build_character(avail_classes, max_level=max_level-1, level_warp = level_warp, burst_weight = burst_weight, is.final=F, prefix_build=prefix_build, monoclass_depth = monoclass_depth)
  } else {
    build = prefix_build
  }

  start = T
  while(length(build$potential_classes) != 0 || start){
    start = F
    
    ################################################################
    # Level up the character to 30 so I can properly assess damage
    ##################################################################
    while(calculateLevel(build$class) < max_level){
      # if(calculateLevel(build$class) >= 15 & calculateLevel(build$class) <= 20){ 
      #   class_table = sapply(3-table(build$class), max, 0)
      #   class_table["any"] = 0
      #   if(calculateLevel(build$class) + sum(class_table) >= 21){ 
      #     break;
      #   }
      # }
      
      build = levelup(build, avail_classes)
    }
    
    ##########################################
    # Debug Messages
    ##########################################
    # print(builds_analyzed)
    # cat(build$class[!is.na(build$class)], "\n")
    # if(builds_analyzed %% 10 == 0){ cat(build$class[!is.na(build$class)], "\n")}
    
    ##########################################
    # Assess
    ##########################################
    if(calculateLevel(build$class) == max_level){
      builds_analyzed = builds_analyzed + 1
      build.evaluation = evaluateBuild(build, burst_weight)
      if(build.evaluation$score > best_score){
        best_build = build
        cat(best_build$class[!is.na(best_build$class)], "\n")
        best_score = build.evaluation$score
      }
    }
    
    ##########################################
    # Delevel
    ##########################################
    build = delevel(build, avail_classes)
    
  }
  
  #################################################
  # Monoclass Search
  #
  ### This is the second chain of the search. Instead of using a greedy approach to restrict the search space
  ### I am restriction the search space based on only looking at a single class. This should allow for a much
  ### deeper search. This is a good search to do because many class features require many class levels
  ### in order to function.
  #
  ### It is possible that the best build comes from this "deep" search instead of the shallow level warp search.
  ### Note, I will still level warp afterwards, however the next shallow search should easily find the new
  ### local maxima.
  #################################################
  if(level_warp+1 <= monoclass_depth){
    for(class_n in names(which(avail_classes > 0))){
      avail_builds_class = list()
      avail_builds_class[[class_n]] = avail_classes[[class_n]]
      
      # Before we do anything expensive, make sure the class can be taken. If it can't be taken now, it couldn't be taken earlier.
      # Also make sure I have levels of the class left. If I don't have them here then there is no use going back.
      if(calculateQualifiedClasses(avail_builds_class, best_build$class, unlist(best_build$feats)) == "any"){ break }
      if(calculateClassLevel(best_build$class, class_n) > getAvailability(avail_builds_class, class_n)) { break }
      
      ##########################################
      # Start descending
      ##########################################
      for(i in (level_warp+1):monoclass_depth){
        class_build = createPrefixBuild(best_build, i, F)
        
        # Again, make sure the class can be taken and make sure I have enough class levels available to cover.
        if(calculateQualifiedClasses(avail_builds_class, class_build$class, unlist(class_build$feats)) == "any"){ break }
        if(calculateClassLevel(class_build$class, class_n) + i > getAvailability(avail_builds_class, class_n))  { break }
        
        class_build = build_character(avail_builds_class, max_level = max_level, level_warp = level_warp, burst_weight = burst_weight, prefix_build = class_build, monoclass_depth = 0)

        builds_analyzed = builds_analyzed + 1
        build.evaluation = evaluateBuild(class_build, burst_weight)
        if(build.evaluation$score > best_score){
          print("Class search found a new build!")
          best_build = class_build
          cat(best_build$class[!is.na(best_build$class)], "\n")
          best_score = build.evaluation$score
        }
      }
    }
  }

  
  #cat("level:", calculateLevel(best_build$class), "level_warp:", level_warp, "prefix_level:", calculateLevel(best_build$class) - level_warp,"\n")
  best_build = createPrefixBuild(best_build, level_warp, is.final)
  
  #if(is.final) outputCharacter(best_build)
  #if(is.final) print(proc.time() - ptm)
  return(best_build)
}
  
createPrefixBuild = function(build, levels_to_lose, is.final){
  build$potential_classes = lapply(build$potential_classes, function(x) x = character(0))
  build$potential_feats   = lapply(build$potential_feats, function(x) x = list())

  if(calculateLevel(build$class) > levels_to_lose & !is.final){
    blankRange = (calculateLevel(build$class) - levels_to_lose + 1):30

    build$feats[blankRange] = NULL
    build$potential_feats[blankRange] = NULL
    build$potential_classes[blankRange] = NULL
    build$class[blankRange] = NA
  }
  
  return(build)
}

is.final = T
max_level = 30
level_warp = 0
burst_weight= 0.25
monoclass_depth = 5
# avail_classes = list("monk"=30)
avail_classes = list("monk"=14, "dervish"=10, "invis_blade"=5, "fighter"=30, "weapon_master"=0, "swashbuckler"=5)
windmaster_char = build_character(avail_classes, max_level = max_level, level_warp = level_warp, burst_weight = burst_weight, monoclass_depth = monoclass_depth)
# 
# avail_classes_all = list("monk"=30, "dervish"=10, "invis_blade"=5, "fighter"=30, "weapon_master"=0, "swashbuckler"=5)
# avail_classes_monk = list("monk"=30)
# avail_classes_fighter = list("monk"=0, "dervish"=0, "invis_blade"=0, "fighter"=30, "weapon_master"=0, "swashbuckler"=0)
# windmaster_10 = build_character(avail_classes_monk,  max_level = 10, level_warp = 4, burst_weight = burst_weight)
# windmaster_20 = build_character(avail_classes_all, max_level = 20, level_warp = 1, burst_weight = burst_weight, prefix_build = windmaster_10)
# windmaster_30 = build_character(avail_classes_all,  max_level = 30, level_warp = 1, burst_weight = burst_weight, prefix_build = windmaster_20)
# 
outputCharacter(windmaster_char)