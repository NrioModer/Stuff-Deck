--- STEAMODDED HEADER
--- MOD_NAME: Stuff Deck
--- MOD_ID: StuffDeck
--- MOD_AUTHOR: [Nrio]
--- MOD_DESCRIPTION: yes.

----------------------------------------------
------------MOD CODE -------------------------
local tur_def = {
    ["name"]="Turquoise Deck",
    ["text"]={
    	[1]="{C:attention}+2{} hands, {C:red}-2{} discards",
    	[2]="You can spend your hand to discard",
    	[3]="cards when there are no discards"
   }
}

local con_def = {
    ["name"]="Concert Deck",
    ["text"]={
	[1]="{C:attention}X1.5{} to all {C:dark_edition}Edition",
	[2]="Money cannot exceed {C:money}$50"
    }
}

local abs_def = {
    ["name"]="Abstract Deck",
    ["text"]={
	[1]="{C:attention}+1{} hand size",
	[2]="At end of the round, change",
	[3]="suit and rank of cards in hand"
    }
}
	
function SMODS.INIT.MeshDeck()

    local stuffdeck_mod = SMODS.findModByID("StuffDeck")
    local tur_card = SMODS.Sprite:new("tur_d", stuffdeck_mod.path, "turquoise.png", 71, 95, "asset_atli")
    local abs_card = SMODS.Sprite:new("abs_d", stuffdeck_mod.path, "abstract.png", 71, 95, "asset_atli")
    local concert_card = SMODS.Sprite:new("concert_d", stuffdeck_mod.path, "concert.png", 71, 95, "asset_atli")

    abs_card:register()
    tur_card:register()
    concert_card:register()
end
	

local turDeck = SMODS.Deck:new("Turquoise Deck", "tur_d", {tur = true, hands = 2, discards = -2, atlas = "tur_d"}, {x = 0, y = 0}, tur_def)
local absDeck = SMODS.Deck:new("Abstract Deck", "abs_d", {abs = true, hand_size = 1, atlas = "abs_d"}, {x = 0, y = 0}, abs_def)
local concertDeck = SMODS.Deck:new("Concert Deck", "concert_d", {concert = true, atlas = "concert_d"}, {x = 0, y = 0}, con_def)
turDeck:register()
absDeck:register()
concertDeck:register()

--abs effect
local eval_card_ref = eval_card
function eval_card(card, context)
    context = context or {}
    local ret = {}
    if context.cardarea == G.hand and context.end_of_round and not (card.ability.set == 'Joker' or card.ability.set == 'Edition' or card.ability.consumeable or card.ability.set == 'Voucher' or card.ability.set == 'Booster') and G.GAME.starting_params.abs then
	G.E_MANAGER:add_event(Event({trigger = 'after', delay = 0.8,
			func = function()
			    local suit_prefix = pseudorandom_element({'S','H','D','C'})
        		    local rank_suffix = pseudorandom_element({'2','3','4','5','6','7','8','9','T','J','Q','K','A'})
        	            card:set_base(G.P_CARDS[suit_prefix..'_'..rank_suffix])
			    return true
			end
		}))
    end
	
    return eval_card_ref(card, context)
end
--abs effect

--mesh effect
G.FUNCS.instead_of_playing_discard_cards_from_highlighted = function(e, hook)
    stop_use()
    G.CONTROLLER.interrupt.focus = true
    G.CONTROLLER:save_cardarea_focus('hand')

    for k, v in ipairs(G.playing_cards) do
        v.ability.forced_selection = nil
    end

    if G.CONTROLLER.focused.target and G.CONTROLLER.focused.target.area == G.hand then G.card_area_focus_reset = {area = G.hand, rank = G.CONTROLLER.focused.target.rank} end
    local highlighted_count = math.min(#G.hand.highlighted, G.discard.config.card_limit - #G.play.cards)
    if highlighted_count > 0 then 
        update_hand_text({immediate = true, nopulse = true, delay = 0}, {mult = 0, chips = 0, level = '', handname = ''})
        table.sort(G.hand.highlighted, function(a,b) return a.T.x < b.T.x end)
        inc_career_stat('c_cards_discarded', highlighted_count)
        for j = 1, #G.jokers.cards do
            G.jokers.cards[j]:calculate_joker({pre_discard = true, full_hand = G.hand.highlighted, hook = hook})
        end
        local cards = {}
        local destroyed_cards = {}
        for i=1, highlighted_count do
            G.hand.highlighted[i]:calculate_seal({discard = true})
            local removed = false
            for j = 1, #G.jokers.cards do
                local eval = nil
                eval = G.jokers.cards[j]:calculate_joker({discard = true, other_card =  G.hand.highlighted[i], full_hand = G.hand.highlighted})
                if eval then
                    if eval.remove then removed = true end
                    card_eval_status_text(G.jokers.cards[j], 'jokers', nil, 1, nil, eval)
                end
            end
            table.insert(cards, G.hand.highlighted[i])
            if removed then
                destroyed_cards[#destroyed_cards + 1] = G.hand.highlighted[i]
                if G.hand.highlighted[i].ability.name == 'Glass Card' then 
                    G.hand.highlighted[i]:shatter()
                else
                    G.hand.highlighted[i]:start_dissolve()
                end
            else 
                G.hand.highlighted[i].ability.discarded = true
                draw_card(G.hand, G.discard, i*100/highlighted_count, 'down', false, G.hand.highlighted[i])
            end
        end

        if destroyed_cards[1] then 
            for j=1, #G.jokers.cards do
                eval_card(G.jokers.cards[j], {cardarea = G.jokers, remove_playing_cards = true, removed = destroyed_cards})
            end
        end

        G.GAME.round_scores.cards_discarded.amt = G.GAME.round_scores.cards_discarded.amt + #cards
        check_for_unlock({type = 'discard_custom', cards = cards})
        if not hook then
            if G.GAME.modifiers.discard_cost then
                ease_dollars(-G.GAME.modifiers.discard_cost)
            end
            ease_hands_played(-1)
            G.GAME.current_round.discards_used = G.GAME.current_round.discards_used + 1
            G.STATE = G.STATES.DRAW_TO_HAND
            G.E_MANAGER:add_event(Event({
                trigger = 'immediate',
                func = function()
                    G.STATE_COMPLETE = false
                    return true
                end
            }))
        end
    end
end

G.FUNCS.can_discard = function(e)
    if G.GAME.current_round.discards_left <= 0 or #G.hand.highlighted <= 0 then
	if G.GAME.current_round.hands_left >= 2 and #G.hand.highlighted > 0 and G.GAME.starting_params.tur then
		e.config.colour = G.C.PURPLE
        	e.config.button = 'instead_of_playing_discard_cards_from_highlighted'
	else
		e.config.colour = G.C.UI.BACKGROUND_INACTIVE
       	 	e.config.button = nil
	end
    else
        e.config.colour = G.C.RED
        e.config.button = 'discard_cards_from_highlighted'
    end
end
--mesh effect

--concert effect
local updateref = Card.update
function Card.update(dt)
    if G.GAME.dollars > 50 and G.GAME.starting_params.concert then
	G.GAME.dollars = 50
    end
    updateref(dt)
end

local set_editionref = Card.set_edition
function Card.set_edition(self, edition, immediate, silent)
    set_editionref(self, edition, immediate, silent)
    if not edition or not G.GAME.starting_params.concert then return end
    if edition.negative and self.added_to_deck then
        if self.ability.consumeable then
            G.consumeables.config.card_limit = G.consumeables.config.card_limit + 0.5
        else
            G.jokers.config.card_limit = G.jokers.config.card_limit + 0.5
        end
    end
end

local add_to_deckref = Card.add_to_deck
function Card.add_to_deck(self, from_debuff)
    if not self.added_to_deck then
        if self.edition and self.edition.negative and not from_debuff and G.GAME.starting_params.concert then
            if self.ability.consumeable then
	        G.consumeables.config.card_limit = G.consumeables.config.card_limit + 0.5
            else
	    	G.jokers.config.card_limit = G.jokers.config.card_limit + 0.5
            end
        end
    end
    add_to_deckref(self, from_debuff)
end

local remove_from_deckref = Card.remove_from_deck
function Card.remove_from_deck(self, from_debuff)
    if self.added_to_deck then
        if self.edition and self.edition.negative and not from_debuff and G.jokers and G.GAME.starting_params.concert then
            if self.ability.consumeable then
            	G.consumeables.config.card_limit = G.consumeables.config.card_limit - 0.5
            else
            	G.jokers.config.card_limit = G.jokers.config.card_limit - 0.5
            end
        end
    end
    remove_from_deckref(self, from_debuff)
end
--concert effect

local Backapply_to_runRef = Back.apply_to_run
function Back.apply_to_run(self)
	Backapply_to_runRef(self)
	
	if self.effect.config.abs then
		G.GAME.starting_params.abs = self.effect.config.abs
	end
	if self.effect.config.tur then
		G.GAME.starting_params.tur = self.effect.config.tur
	end
	if self.effect.config.concert then
		G.GAME.starting_params.concert = self.effect.config.concert
		G.P_CENTERS.e_foil.config.extra = 75
        	G.P_CENTERS.e_holo.config.extra = 15
       		G.P_CENTERS.e_polychrome.config.extra = 2.25
        	G.P_CENTERS.e_negative.config.extra = 1.5
	else
		G.P_CENTERS.e_foil.config.extra = 50
        	G.P_CENTERS.e_holo.config.extra = 10
       		G.P_CENTERS.e_polychrome.config.extra = 1.5
        	G.P_CENTERS.e_negative.config.extra = 1

	end
end

----------------------------------------------
------------MOD CODE END----------------------