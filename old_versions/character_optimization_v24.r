source("feats.r")
source("class.r")

calculateAverageDamage = function(attacks, damage, defense){
  effective_hit_chance = (attacks - defense + 21) / 20
  effective_hit_chance = sapply(effective_hit_chance, max, 0.05)
  effective_hit_chance = sapply(effective_hit_chance, min, 0.95)
  
  hits = sum(effective_hit_chance)
  
  average_damage = hits * damage
  
  return(average_damage)
}
g_classList = function(build){ return(build$class[!is.na(build$class)]) }
g_uniqClassList = function(build){ return(unique(g_classList(build))) }

calculateBAB = function(build){
  BAB = 0
  if(calculateLevel(build) == 0) return(0)
  for(class_n in g_uniqClassList(build)){
    classLevel = g_classLevel(build, class_n)
    if(cls_av[[class_n]][["BAB"]] == "high"){ BAB = BAB + classLevel }
    if(cls_av[[class_n]][["BAB"]] == "medium"){ BAB = BAB + floor(0.75*classLevel) }
    if(cls_av[[class_n]][["BAB"]] == "low"){ BAB = BAB + floor(0.5*class_level) }
  }
  
  return(BAB)
}

calculateLevel = function(build){ 
  if(is.null(build$class)) return(0)
  return(length(g_classList(build)))
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

g_classLevel = function(build, class_n) { 
  return(sum(build$class == class_n, na.rm=T)) 
}
g_classFeats = function(build, class_n, level){
  if(is.null(cls_av[[class_n]][["feats"]])) return(c())
  return(unlist(cls_av[[class_n]][["feats"]][1:g_classLevel(build, class_n)]))
}
g_feats = function(build){ 
  c_feats = c()
  ### Get the feats selected at level up
  c_feats = c(c_feats, unlist(build$feats))

  ### Get class feats
  for(class_n in unique(build$class)){
    c_feats = c(c_feats, g_classFeats(build, class_n, g_classLevel(build, class_n)))
  }
  
  ### Get autogrant feats, these are feats that are prereqs for classes and such
  for(feat_n in c_feats){
    if(!is.null(feats_av[[feat_n]])){
      if(!is.null(feats_av[[feat_n]][["grant"]])){
        c_feats = c(c_feats, feats_av[[feat_n]][["grant"]])
      }
    }
  }
  
  if(length(c_feats) > 0) c_feats = c_feats[!is.na(c_feats)]
  return(c_feats)
}

firstup <- function(x) {
  substr(x, 1, 1) <- toupper(substr(x, 1, 1))
  x
}

hasAllFeats = function(build, feat_n){ return(all(feat_n %in% g_feats(build))) }
hasAnyFeats = function(build, feat_n){ return(any(feat_n %in% g_feats(build))) }

g_classSkills = function(build, class_n){
  if(is.null(cls_av[[class_n]][["class_skills"]])) return(c())
  return(cls_av[[class_n]][["class_skills"]])
}
g_skillMaxes = function(build, skill_n){
  build$class = sapply(build$class[!is.na(build$class)], firstup)
  maxSkill = 3+calculateLevel(build)
  minSkill = floor(maxSkill/2)
  skill = rep(minSkill, length(skill_n))
  for(class_n in unique(build$class)){
    skill[skill_n %in% g_classSkills(build, class_n)] = maxSkill
  }
  return(skill)
}

calculateQualifiedClasses = function(avail_classes, build, preferred_classes=c(), max_level=calculateLevel(build)+1, cooling=0.9, burst_weight=0.25){
  qual_class = c()
  c_feats = g_feats(build)
  
  for(class_n in names(cls_av)){
    if(!is.null(cls_av[[class_n]][["prereq_BAB"]])){ if(cls_av[[class_n]][["prereq_BAB"]] > calculateBAB(build)) next } #BAB Check
    if(!is.null(cls_av[[class_n]][["prereq_feats"]])){ if(!hasAllFeats(build, cls_av[[class_n]][["prereq_feats"]])) next } # prereq Feat Check
    if(!is.null(cls_av[[class_n]][["prereq_skills"]])){ 
      if(!all(g_skillMaxes(build, names(cls_av[[class_n]][["prereq_skills"]])) > cls_av[[class_n]][["prereq_skills"]])) next
    }
    qual_class = c(class_n, qual_class)
  }
  
  class_table = sapply(3-table(build$class), max, 0)
  class_table = class_table[names(class_table) != "any"]
  
  ## If I already have 4 classes, I cannot take any more
  if(length(class_table) == 4)               { qual_class = qual_class[qual_class %in% build$class] }
  ## If I am above level 20, the 3b20 rule will not allow me to take more
  if(calculateLevel(build) >= 20){ qual_class = qual_class[qual_class %in% build$class] }
  
  ## 3b20 rule, if we are already about to run into it, I cannot select a new class.
  if(calculateLevel(build) >= 15 & calculateLevel(build) < 20){ 
    if(calculateLevel(build) + sum(class_table) >= 20){ 
      qual_class = qual_class[qual_class %in% names(which(class_table > 0))]
    }
    if(calculateLevel(build) + sum(class_table) + 3 >= 21){ 
      qual_class = qual_class[qual_class %in% build$class]
    }
  }
  
  ########################################################################################################
  ### Restrict to preferred classes
  ########################################################################################################
  # This is useful for things such as class search.
  if(any(qual_class %in% preferred_classes, na.rm=T)) qual_class = qual_class[qual_class %in% preferred_classes]
  
  ########################################################################################################
  ### Restrict the Branching Factor
  ########################################################################################################
  # classes are problematic in that they greatly add to the branching factor. In order to restrict this
  # I perform a branch cutting algorithm here.
  qual_class = reduceClassBranchFactor(avail_classes, build, qual_class, max_level, cooling, burst_weight)
  
  if(length(qual_class) == 0) return(c("any"))
  return(qual_class)
}


reduceClassBranchFactor = function(avail_classes, build, qualified_classes, max_level=calculateLevel(build)+1, cooling=0.9, burst_weight=0.25, is.final=T){
  if(length(qualified_classes) == 0) { build$class[calculateLevel(build)+1:max_level] = "any" }
  if(calculateLevel(build) >= max_level) { return(qualified_classes) }  
  
  scores = list()
  builds = list()
  for(class_n in qualified_classes){
    branch_build = createBranchBuild(avail_classes, build, qualified_classes, max_level, cooling, class_n)
    branch_build = populateFeats(avail_classes, branch_build, cooling)
    scores[class_n] = evaluateBuild(branch_build, burst_weight, level=30)$score
    builds[[class_n]] = branch_build
  }
  reduced_list = names(which(scores >= cooling * max(unlist(scores))))
  return(reduced_list)
}

resetBuild = function(){
  build = createPrefixBuild(windmaster_char, 15, F)
  return(build)
}

createBranchBuild = function(avail_classes, branch_build, qualified_classes, max_level=calculateLevel(build)+1, cooling=0.9, class_n="any"){
  available_levels = getAvailability(avail_classes, class_n) - g_classLevel(branch_build, class_n) 
  max_ind = min(calculateLevel(branch_build) + available_levels, max_level)
  branch_build$class[(calculateLevel(branch_build)+1):max_ind] = class_n
  
  if(calculateLevel(branch_build) < max_level){
    branch_build = createBranchBuild(avail_classes, 
                                     branch_build, 
                                     qualified_classes[qualified_classes != class_n], 
                                     max_level,
                                     cooling,
                                     class_n)
  }
  return(branch_build)
}

#############################################
### PopulateFeats: return build
###############################################
# Sometimes I have a build that does not have feats
# This function populates the feat list, with greedy optimization
populateFeats = function(avail_classes, build, cooling=0.9){
  
  for(i in 1:calculateLevel(build)){
    level_build = createPrefixBuild(build, calculateLevel(build) - i, F)
    number_of_feats = calculateNumberOfNewFeats(level_build)
    if(number_of_feats$total > 0){ # There should be a feat at this level
      if(length(build$feats) < i){ # But if there isn't, we need to add some ... optimally
        level_build = levelFeat(level_build, avail_classes)
        best_score = evaluateBuild(level_build)$score
        best_build = level_build
        
        while(length(unlist(level_build$potential_feats)) > 0){
          level_build = delevel(level_build, avail_classes, cooling)
          score = evaluateBuild(level_build)$score
          if(score > best_score){
            best_score = score
            best_build = level_build
          }
        }
        build$feats[[i]] = best_build$feats[[i]]
      }
    }
    
  }
  return(build)
}

lastCharacterClass = function(build){ 
  last_class_index = which(is.na(build$class))[1]-1
  if(is.na(last_class_index)) return(build$class[length(build$class)])
  return(build$class[which(is.na(build$class))[1]-1]) 
}

g_stats = function(build, stats){
  base_stats = build$stats
  for(feat_n in g_feats(build)){
    for(stat_n in names(base_stats)){
      if(is.null(feats_av[[feat_n]][[paste("plus", stat_n, sep="")]])) next
      base_stats[[stat_n]] = base_stats[[stat_n]] + feats_av[[feat_n]][[paste("plus", stat_n, sep="")]]
    }
  }
  
  if(!is.null(build$stat_increase)){ base_stats[[build$stat_increase]] = base_stats[[build$stat_increase]] + floor(calculateLevel(build) / 4) }
  
  return(unlist(base_stats[stats]))
}

g_featsInFeatType = function(feat_type){
  feat_list = c()
  for(feat_n in names(feats_av)){
    if( is.null(feats_av[[feat_n]][["feat_type"]])        ) next
    if( !feat_type %in% feats_av[[feat_n]][["feat_type"]] ) next
    feat_list = c(feat_list, feat_n)
  }
  return(feat_list)
}

calculateQualifiedFeats = function(build, feat_type){
  qual_feats = c()
  
  available_feats = g_featsInFeatType(feat_type)
  available_feats = available_feats[!available_feats %in% g_feats(build)]
  for(feat_n in g_featsInFeatType(feat_type)){
    if( !is.null(feats_av[[feat_n]][["prereq_level"]])  ){ if(feats_av[[feat_n]][["prereq_level"]] > calculateLevel(build)) next } # Level Check
    if( !is.null(feats_av[[feat_n]][["prereq_BAB"]])    ){ if(feats_av[[feat_n]][["prereq_BAB"]] > calculateBAB(build)) next } # BAB Check
    if( !is.null(feats_av[[feat_n]][["prereq_stat"]])   ){
      if(!all(g_stats(build, names(feats_av[[feat_n]][["prereq_stat"]])) > feats_av[[feat_n]][["prereq_stat"]])) next
    }
    if( !is.null(feats_av[[feat_n]][["prereq_feats"]])  ){ if(!hasAllFeats(build, feats_av[[feat_n]][["prereq_feats"]])) next } # prereq Feat Check
    if( !is.null(feats_av[[feat_n]][["prereq_skills"]]) ){ 
      if(!all(g_skillMaxes(build, names(feats_av[[feat_n]][["prereq_skills"]])) > feats_av[[feat_n]][["prereq_skills"]])) next
    }
    if( !is.null(feats_av[[feat_n]][["prereq_class"]])  ){
      prereq_classes_met = T
      for(class_n in names(feats_av[[feat_n]][["prereq_class"]])){
        if(g_classLevel(build, class_n) < feats_av[[feat_n]][["prereq_class"]][[class_n]]) prereq_classes_met = F
      }
      if(!prereq_classes_met) next
    }
    qual_feats = c(qual_feats, feat_n)
  }
  
  qual_feats = qual_feats[!qual_feats %in% g_feats(build)]
  if(length(qual_feats) == 0) return(c("any"))
  return(qual_feats)
}

calculateNumberOfNewFeats = function(build){
  number_of_feats = 0
  fighter_feats = 0
  if(calculateLevel(build) == 1) number_of_feats = number_of_feats+1
  if(calculateLevel(build) <= 20 & calculateLevel(build) %% 3 == 0) number_of_feats = number_of_feats+1
  if(calculateLevel(build) >  20 & calculateLevel(build) %% 2 == 1) number_of_feats = number_of_feats+1
  if(lastCharacterClass(build) == "Fighter" & g_classLevel(build, "Fighter") == 1) fighter_feats = fighter_feats+1
  if(lastCharacterClass(build) == "Fighter" & g_classLevel(build, "Fighter") %% 2 == 0) fighter_feats = fighter_feats+1
  return(list(total=number_of_feats+fighter_feats,
              regular=number_of_feats,
              fighter=fighter_feats))
}

calculateAttacks = function(build, burst=T){
  
  BAB = calculateBAB(build)
  attack_bonus = 0
  
  main_hand_attacks = c()
  off_hand_attacks = c()
  
  num_attacks_main = max(floor((BAB-1)/5)+1, 1)
  num_attacks_off = 0
  
  attack_bonus = attack_bonus + 4 #Enhancement Bonus
  attack_bonus = attack_bonus + g_stat_mod(build, "Strength")
  
  for(feat_n in unique(g_feats(build))){
    if(!is.null(feats_av[[feat_n]][["attack_bonus"]])){
      attack_bonus = attack_bonus + feats_av[[feat_n]][["attack_bonus"]](build, burst)
    }
    if(!is.null(feats_av[[feat_n]][["num_attacks_main"]])){
      num_attacks_main = num_attacks_main + feats_av[[feat_n]][["num_attacks_main"]](build, burst)
    }
    if(!is.null(feats_av[[feat_n]][["num_attacks_off"]])){
      num_attacks_off = num_attacks_off + feats_av[[feat_n]][["num_attacks_off"]](build, burst)
    }
  }
  
  # Special Code for Perfect Two Weapon Fighting
  if(hasAllFeats(build, "Perfect Two-Weapon Fighting")){
    num_attacks_off = num_attacks_main
  }
  
  # Special Code for Flurry of Blows
  if(g_classLevel(build, "monk") <= 4) attack_bonus = attack_bonus - 1
  if(g_classLevel(build, "monk") <= 8) attack_bonus = attack_bonus - 1
  if(hasAllFeats(build, "Flurry of Blows")) {
    main_hand_attacks = c(main_hand_attacks, BAB+attack_bonus)
    num_attacks_off = num_attacks_off + 1
  }
  if(hasAllFeats(build, "Greater Flurry")) {
    main_hand_attacks = c(main_hand_attacks, BAB+attack_bonus)
    num_attacks_off = num_attacks_off + 1
  }
  
  # Special Code for (not) two weapon fighting
  if(!hasAllFeats(build, "Two-Weapon Fighting")){
    num_attacks_off = 0
  }
  
  top_attack_bonus = BAB + attack_bonus
  
  main_hand_attacks = c(main_hand_attacks, seq(from=top_attack_bonus, to=top_attack_bonus-5*(num_attacks_main-1), by=-5))
  if(num_attacks_off > 0) off_hand_attacks = c(off_hand_attacks, seq(from=top_attack_bonus, to=top_attack_bonus-5*(num_attacks_off-1), by=-5))
  
  attacks = c(main_hand_attacks, off_hand_attacks)
  return(attacks)
}

g_stat_mod = function(build, stat){
  return(floor((g_stats(build, stat) - 10) / 2))
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

levelClass = function(build, avail_classes, preferred_classes=c(), max_level=calculateLevel(build)+1, cooling=0.9, burst_weight=0.25){
  cur_lv = calculateLevel(build)
  if(length(build$potential_classes) < cur_lv+1){
    build$potential_classes[[cur_lv+1]] = calculateQualifiedClasses(avail_classes, build, preferred_classes, max_level, cooling, burst_weight)
  }
  class_index = sample(1:length( build$potential_classes[[cur_lv+1]] ), 1)
  class_name = build$potential_classes[[cur_lv+1]][class_index]
  build$class[cur_lv+1] = class_name
  build$potential_classes[[cur_lv+1]] = build$potential_classes[[cur_lv+1]][-1 * class_index]
  return(build)
}

selectFeat = function(build, number, feat_type="Regular"){
  cur_lv = calculateLevel(build)
  if(length(build$potential_feats) < cur_lv){
    build$potential_feats[[cur_lv]] = list()
  } else if(is.null(build$potential_feats[[cur_lv]])){
    build$potential_feats[[cur_lv]] = list()
  }
  if(length(build$potential_feats[[cur_lv]]) < number){
    build$potential_feats[[cur_lv]][[number]] = calculateQualifiedFeats(build, feat_type) 
  }
  if(number == 1) {
    build$feats[[cur_lv]] = rep(NA, 3)
    build$feat_types[[cur_lv]] = rep(NA, 3)
  }
  
  feat_ind = sample(1:length( build$potential_feats[[cur_lv]][[number]] ), 1)
  feat_name = build$potential_feats[[cur_lv]][[number]][feat_ind]
  build$feats[[cur_lv]][number] = feat_name
  build$potential_feats[[cur_lv]][[number]] = build$potential_feats[[cur_lv]][[number]][-1 * feat_ind]
  build$feat_types[[cur_lv]][[number]] = feat_type
  
  return(build)
}

levelFeat = function(build, avail_classes, preferred_classes=c(), max_level=calculateLevel(build)+1, cooling=0.9){
  number_new_feats = calculateNumberOfNewFeats(build)
  if(number_new_feats$total > 0){
    feat_types = c(rep("Fighter", number_new_feats$fighter), rep("Regular", number_new_feats$regular))
    for(i in 1:number_new_feats$total){
      build = selectFeat(build, i, feat_types[i])
    }
    
    
    # min_feats_tc = 1
    # max_feats_tc = 0
    # 
    # ###
    # # Fighter Feats
    # ###
    # min_feats_tc = min_feats_tc + max_feats_tc
    # max_feats_tc = max_feats_tc + number_new_feats$fighter
    # if(number_new_feats$fighter > 0){ for(i in min_feats_tc:max_feats_tc){ build = selectFeat(build, i, "Fighter") } }
    # 
    # ###
    # # Regular Feats
    # ###
    # min_feats_tc = min_feats_tc + max_feats_tc
    # max_feats_tc = max_feats_tc + number_new_feats$regular
    # if(number_new_feats$regular > 0){ for(i in min_feats_tc:max_feats_tc){ build = selectFeat(build, i, "Regular") } }
  } else {
    build$potential_feats[[calculateLevel(build)]] = list()
  }
  return(build)
}

levelup = function(build, avail_classes, preferred_classes=c(), max_level=calculateLevel(build)+1, cooling=0.9){
  build = levelClass(build, avail_classes, preferred_classes, max_level, cooling)
  build = levelFeat(build, avail_classes, preferred_classes, max_level, cooling)
  return(build)
}

delevel = function(build, avail_classes, cooling){
  while(calculateLevel(build) > 0){
    if(length(build$potential_feats) < calculateLevel(build)){ # There was no feat at this level, defeat
      build$class[calculateLevel(build)]             = NA
    } else {
      number_new_feats = calculateNumberOfNewFeats(build)
      
      if(number_new_feats$total > 0){
        for(i in number_new_feats$total:1){ # set empty potential feat lists to null
          if(length(build$potential_feats[[calculateLevel(build)]]) != 0){
            if(length(build$potential_feats[[calculateLevel(build)]][[i]]) == 0){ 
              build$potential_feats[[calculateLevel(build)]][i] = NULL
            } else {
              break
            }
          }
        }
      }
      
      if(length(build$potential_feats[[calculateLevel(build)]]) == 0){ # if there are no more feats for this level
        build$feats[[calculateLevel(build)]]           = NULL
        build$potential_feats[[calculateLevel(build)]] = NULL
        build$class[calculateLevel(build)]             = NA
      } else {
        #  build$feat_types[[calculateLevel(build)]][i])
        feat_types = c(rep("Fighter", number_new_feats$fighter), rep("Regular", number_new_feats$regular))
        for(i in length(build$potential_feats[[calculateLevel(build)]]):number_new_feats$total){ build = selectFeat(build, i, feat_types[i]) } # Relevel
        return(build)
      }
    }
    
    # If the code made it this far, I need to figure out if there are more classes to take, if so level up and break
    if(length(build$potential_classes) >= calculateLevel(build)+1){ # Well, there's something there
      if(length(build$potential_classes[[calculateLevel(build)+1]]) >= 1){ # Is there a class to take
        build = levelup(build, avail_classes, cooling=cooling)
        return(build)
      } else { # No class to take, set potential classes to NULL and delevel again
        if(length(build$potential_classes) >= calculateLevel(build)+1){
          build$potential_classes[[calculateLevel(build)+1]] = NULL
        }
      }
    }
  }
  return(build)
}

prereq_feats = c("Dodge", "Combat Expertise", "Weapon Focus (Kukri)", "Feint")

prereq_bonus = function(feats){
  number_of_prereq_feats = length(which(feats %in% prereq_feats))
  return(number_of_prereq_feats * 0.001)
}

multiclassPenalty = function(classes){
  class_names = names(table(classes))
  if(is.null(class_names)) return(0)
  return(sum(!is.na(class_names))* 0.001)
}

g_aveDamageDice = function(dice, sides){ return((dice + dice*sides)/2) }

calculateDamage = function(build, burst=T){
  damage = 0
  crit_chance = 1
  crit_chance_multiplier = 1
  crit_multiplier = 2
  postCrit_damage = 0
  
  damage = damage + g_aveDamageDice(1, 6) # Kama Base Damage
  damage = damage + 4 # Enhancement Bonus
  damage = damage + g_stat_mod(build, "Strength")
  
  for(feat_n in unique(g_feats(build))){
    if(!is.null(feats_av[[feat_n]][["damage"]])){
      damage = damage + feats_av[[feat_n]][["damage"]](build, burst)
    }
    if(!is.null(feats_av[[feat_n]][["postCrit_damage"]])){
      postCrit_damage = postCrit_damage + feats_av[[feat_n]][["postCrit_damage"]](build, burst)
    }
    if(!is.null(feats_av[[feat_n]][["crit_chance"]])){
      crit_chance = crit_chance + feats_av[[feat_n]][["crit_chance"]](build, burst)
    }
    if(!is.null(feats_av[[feat_n]][["crit_chance_multiplier"]])){
      crit_chance_multiplier = crit_chance_multiplier * feats_av[[feat_n]][["crit_chance_multiplier"]](build, burst)
    }
    if(!is.null(feats_av[[feat_n]][["crit_multiplier"]])){
      crit_multiplier = crit_multiplier + feats_av[[feat_n]][["crit_multiplier"]](build, burst)
    }
  }

  crit_damage = (damage * crit_chance * crit_chance_multiplier * crit_multiplier) / 20
  noncrit_damage = (damage * (20-crit_chance)) / 20
  total_damage = crit_damage + noncrit_damage + postCrit_damage
  
  return(damage)
}

evaluateBuild = function(build, burst_weight=0.5, level=30, max_level=30){
  
  damage_per_level = rep(0, 30)
  burst_per_level  = rep(0, 30)
  susta_per_level  = rep(0, 30)
  
  level_build = createPrefixBuild(build, calculateLevel(build) - level, F)
  for(i in 1:max_level){
    cur_level_build = createPrefixBuild(level_build, calculateLevel(level_build) - i, F)
    damage_rolls_burst = calculateDamage(cur_level_build, TRUE)
    damage_rolls_susta = calculateDamage(cur_level_build, FALSE)
    attack_rolls_burst = calculateAttacks(cur_level_build, TRUE)
    attack_rolls_susta = calculateAttacks(cur_level_build, FALSE)
    
    defense = i + 10
    
    damage_dealt_burst = calculateAverageDamage(attack_rolls_burst, damage_rolls_burst, defense)
    damage_dealt_susta = calculateAverageDamage(attack_rolls_susta, damage_rolls_susta, defense)
    
    damage_dealt       = damage_dealt_burst*burst_weight + damage_dealt_susta*(1-burst_weight)
    
    damage_per_level[i] = damage_dealt
    burst_per_level[i]  = damage_dealt_burst
    susta_per_level[i]  = damage_dealt_susta
  }
  
  score = calculateScore(damage_per_level) - multiclassPenalty(build$class[1:level]) + prereq_bonus(unlist(build$feats[1:level]))
  
  return(list(damage = damage_per_level,
              burst = burst_per_level,
              sustain = susta_per_level,
              score = score))
}



build_character = function(avail_classes, max_level = 30, level_warp = 1, burst_weight=0.5, is.final=T, prefix_build = blank_prefix_build, monoclass_depth=5, cooling=1, report=T, preferred_classes=c()){
  builds_analyzed = 0
  
  best_build = blank_prefix_build
  best_score = 0
  
  
  
  if(max_level > calculateLevel(prefix_build) + level_warp){
    build = build_character(avail_classes, 
                            max_level=max_level-1, 
                            level_warp = level_warp, 
                            burst_weight = burst_weight, 
                            is.final=F, 
                            prefix_build=prefix_build, 
                            monoclass_depth = monoclass_depth, 
                            report=report, 
                            cooling=cooling,
                            preferred_classes=preferred_classes)
  } else {
    build = prefix_build
  }
  if(max_level - level_warp <= 0){ return(build) }
  
  start = T
  max_level_reached = F
  while(length(build$potential_classes) != 0 || start){
    start = F
    
    ################################################################
    # Level up the character to 30 so I can properly assess damage
    ##################################################################
    while(calculateLevel(build) < max_level){
      if( max_level_reached & calculateLevel(build) > 0) {
        if(evaluateBuild(build)$score <= (cooling * evaluateBuild(best_build, level=calculateLevel(build))$score) ) { break; }
      }
      
      build = levelup(build, avail_classes, preferred_classes, max_level, cooling)
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
    if(calculateLevel(build) == max_level){
      
      max_level_reached = T
      builds_analyzed = builds_analyzed + 1
      if(report) { if(builds_analyzed %% 1000 == 0) cat("builds_analyzed:", builds_analyzed, "\n") }
      build.evaluation = evaluateBuild(build, burst_weight)
      
      if(build.evaluation$score > best_score){
        best_build = build
        best_score = build.evaluation$score
        if(report) cat("score:", best_score, "\n")
      }
    }
    
    ##########################################
    # Delevel
    ##########################################
    build = delevel(build, avail_classes, cooling)
    
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
  # if(level_warp+1 <= monoclass_depth){
  #   for(class_n in names(which(avail_classes > 0))){
  #     # Also make sure I have levels of the class left. If I don't have them here then there is no use going back.
  #     if(g_classLevel(best_build, class_n) > getAvailability(avail_classes, class_n)) { break }
  # 
  #     ##########################################
  #     # Start descending
  #     ##########################################
  #     for(i in (level_warp+1):monoclass_depth){
  #       class_build = createPrefixBuild(best_build, i, F)
  # 
  #       # Again, make sure the class can be taken and make sure I have enough class levels available to cover.
  #       if(any(calculateQualifiedClasses(avail_classes, class_build, cooling=0) == "any")){ break }
  #       if(g_classLevel(class_build, class_n) + i > getAvailability(avail_classes, class_n))  { break }
  # 
  #       class_build = build_character(avail_classes,
  #                                     max_level = max_level,
  #                                     level_warp = level_warp,
  #                                     burst_weight = burst_weight,
  #                                     prefix_build = class_build,
  #                                     monoclass_depth = 0,
  #                                     report=F,
  #                                     cooling=cooling,
  #                                     preferred_classes=c(preferred_classes, class_n))
  # 
  #       builds_analyzed = builds_analyzed + 1
  #       if(report) { if(builds_analyzed %% 1000 == 0) cat("builds_analyzed:", builds_analyzed, "\n") }
  #       build.evaluation = evaluateBuild(class_build, burst_weight)
  #       if(build.evaluation$score > best_score){
  #         print("Class search found a new build!")
  #         best_build = class_build
  #         best_score = build.evaluation$score
  #         if(report) cat("score:", best_score, "\n")
  #       }
  #     }
  #   }
  # }
  
  if(report) cat(calculateLevel(best_build), ":", best_build$class[!is.na(best_build$class)], "\n")
  
  #cat("level:", calculateLevel(best_build), "level_warp:", level_warp, "prefix_level:", calculateLevel(best_build) - level_warp,"\n")
  best_build = createPrefixBuild(best_build, level_warp, is.final)
  
  return(best_build)
}

createPrefixBuild = function(build, levels_to_lose, is.final){
  build$potential_classes = lapply(build$potential_classes, function(x) x = character(0))
  build$potential_feats   = lapply(build$potential_feats, function(x) x = list())
  
  if(calculateLevel(build) > levels_to_lose & !is.final & levels_to_lose != 0){
    blankRange = (calculateLevel(build) - levels_to_lose + 1):30
    
    build$feats[blankRange] = NULL
    build$potential_feats[blankRange] = NULL
    build$potential_classes[blankRange] = NULL
    build$class[blankRange] = NA
  }
  
  return(build)
}

blank_prefix_build = list(class = rep(NA, 30),
                          feats = list(),
                          feat_types = list(),
                          potential_classes = list(),
                          potential_feats = list(),
                          weapon = "Kama",
                          stats=list("Strength"=10,
                                     "Dexterity"=20,
                                     "Constitution"=10,
                                     "Intelligence"=16,
                                     "Wisdom"=10,
                                     "Charisma"=8),
                          stat_increase="Dexterity")
is.final = T
max_level = 30
level_warp = 2
burst_weight= 0.25
monoclass_depth = 0
cooling = 0.9
avail_classes = list("Monk"=30, "Dervish"=10, "Invisible Blade"=5, "Fighter"=30, "Swashbuckler"=5)
windmaster_char = build_character(avail_classes,
                                  max_level = max_level,
                                  level_warp = level_warp,
                                  burst_weight = burst_weight,
                                  monoclass_depth = monoclass_depth,
                                  cooling = cooling)
outputCharacter(windmaster_char)