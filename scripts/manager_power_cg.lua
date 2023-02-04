--
-- Please see the license.txt file included with this distribution for
-- attribution and copyright information.
--

local getPCPowerActionOriginal;
local evalActionOriginal;
local performActionOriginal;
local registerDefaultPowerMenuOriginal;
local onDefaultPowerMenuSelectionOriginal;
local resetIntriguePowersOriginal;

function onInit()
	getPCPowerActionOriginal = PowerManager.getPCPowerAction;
	PowerManager.getPCPowerAction = getPCPowerAction;

	evalActionOriginal = PowerManager.evalAction;
	PowerManager.evalAction = evalAction;

	performActionOriginal = PowerManager.performAction;
	PowerManager.performAction = performAction;

	registerDefaultPowerMenuOriginal = PowerManagerCore.registerDefaultPowerMenu;
	PowerManagerCore.registerDefaultPowerMenu = registerDefaultPowerMenu;

	onDefaultPowerMenuSelectionOriginal = PowerManagerCore.onDefaultPowerMenuSelection;
	PowerManagerCore.onDefaultPowerMenuSelection = onDefaultPowerMenuSelection;

	if PowerManagerKw then
		resetIntriguePowersOriginal = PowerManagerKw.resetIntriguePowers;
		PowerManagerKw.resetIntriguePowers = resetIntriguePowers;
	end

	local tResourceActionHandlers = {
		fnGetButtonIcons = getActionButtonIcons,
		fnGetText = getActionText,
		fnGetTooltip = getActionTooltip,
		fnPerform = PowerManager5E.performAction,
	};
	PowerActionManagerCore.registerActionType("resource", tResourceActionHandlers);
end

function getPCPowerAction(nodeAction, sSubRoll)
	local rAction, rActor = getPCPowerActionOriginal(nodeAction, sSubRoll);

	if rAction and rAction.type == "resource" then
		rAction.resource  = DB.getValue(nodeAction, "resource", "");
		rAction.operation = DB.getValue(nodeAction, "operation", "");
		rAction.all = DB.getValue(nodeAction, "all", 0) == 1;
		if not rAction.all then
			rAction.modifier = DB.getValue(nodeAction, "modifier", 0);
			if rAction.operation == "gain" then
				rAction.dice = DB.getValue(nodeAction, "dice", {});
				rAction.stat = DB.getValue(nodeAction, "stat", "");
				rAction.statmult = DB.getValue(nodeAction, "statmult", 1);
			else
				rAction.variable = DB.getValue(nodeAction, "variable", 0) == 1;
				if rAction.variable then
					rAction.min = DB.getValue(nodeAction, "min", 1);
					rAction.max = DB.getValue(nodeAction, "max", 1);
					rAction.increment = DB.getValue(nodeAction, "increment", 1);
				end
			end
		end
	end

	return rAction, rActor
end

function getPCPowerResourceActionText(nodeAction)
	local text = "";
	local rAction, rActor = PowerManager.getPCPowerAction(nodeAction);
	if rAction and rAction.type == "resource" then
		PowerManager.evalAction(rActor, nodeAction.getChild("..."), rAction);

		local sValue;
		if rAction.all then
			sValue = Interface.getString("resource_action_text_all");
		elseif not rAction.variable then
			sValue = StringManager.convertDiceToString(rAction.dice, rAction.modifier);
		else
			if rAction.max > rAction.min then
				sValue = string.format(Interface.getString("resource_action_text_full_range"), rAction.modifier, rAction.min, rAction.max);
			else
				sValue = string.format(Interface.getString("resource_action_text_half_range"), rAction.modifier, rAction.min);
			end
		end

		if rAction.operation == "" then
			local nCurrent = ResourceManager.getCurrentResource(rActor, rAction.resource);
			if nCurrent >= (rAction.modifier or 0) then
				text = string.format(Interface.getString("resource_action_text_spend"), sValue, rAction.resource);
			else
				text = string.format(Interface.getString("resource_action_text_insufficient"), rAction.resource, rAction.modifier, nCurrent);
			end
		else
			text = string.format(Interface.getString("resource_action_text_gain"), sValue, rAction.resource);
		end
	end
	return text;
end

function evalAction(rActor, nodePower, rAction)
	evalActionOriginal(rActor, nodePower, rAction);

	if rAction.type == "resource" then
		if (rAction.stat or "") ~= "" then
			if rAction.stat == "base" then
				if not aPowerGroup then
					aPowerGroup = PowerManager.getPowerGroupRecord(rActor, nodePower);
				end
				if aPowerGroup then
					local nAbilityBonus = ActorManager5E.getAbilityBonus(rActor, aPowerGroup.sStat);
					local nMult = rAction.statmult or 1;
					if nAbilityBonus > 0 and nMult ~= 1 then
						nAbilityBonus = math.floor(nMult * nAbilityBonus);
					end
					rAction.modifier = rAction.modifier + nAbilityBonus;
					rAction.stat = aPowerGroup.sStat;
				end
			else
				local nAbilityBonus = ActorManager5E.getAbilityBonus(rActor, rAction.stat);
				local nMult = rAction.statmult or 1;
				if nAbilityBonus > 0 and nMult ~= 1 then
					nAbilityBonus = math.floor(nMult * nAbilityBonus);
				end
				rAction.modifier = rAction.modifier + nAbilityBonus;
			end
		end
	end
end

function performAction(draginfo, rActor, rAction, nodePower)
	if not rActor or not rAction then
		return false;
	end

	if rAction.type == "resource" then
		evalAction(rActor, nodePower, rAction);
		local rRoll = ActionResource.getRoll(rActor, rAction);
		if rRoll then
			ActionsManager.performMultiAction(draginfo, rActor, rRoll.sType, {rRoll});
		end
	else
		return performActionOriginal(draginfo, rActor, rAction, nodePower);
	end
end

function registerDefaultPowerMenu(w)
	registerDefaultPowerMenuOriginal(w);

	if w.windowlist.isReadOnly() then
		return;
	end

	local aTypes = PowerActionManagerCore.getSortedActionTypes();
	if #aTypes >= 6 then
		w.registerMenuItem(Interface.getString("power_menu_extraactions"), "pointer", 3, 1);
	end
	for index = 6, math.min(#aTypes, 9) do
		local sType = aTypes[index];
		w.registerMenuItem(Interface.getString("power_menu_action_add_" .. sType), "radial_power_action_" .. sType, 3, 1, index - 5);
	end
end

function onDefaultPowerMenuSelection(w, selection, subselection, tertiaryselection)
	onDefaultPowerMenuSelectionOriginal(w, selection, subselection);
	if selection == 3 and subselection == 1 then
		local tTypes = PowerActionManagerCore.getSortedActionTypes();
		local sType = tTypes[tertiaryselection + 5];
		if sType then
			PowerManagerCore.createPowerAction(w, sType);
		end
	end
end

function getActionButtonIcons(node, tData)
	if tData.sType == "resource" then
		return "button_action_resource", "button_action_resource_down";
	end
	return "", "";
end

function getActionText(node, tData)
	if tData.sType == "resource" then
		return getPCPowerResourceActionText(node);
	end
	return "";
end

function getActionTooltip(node, tData)
	if tData.sType == "resource" then
		local sResource = getPCPowerResourceActionText(node);
		return string.format("%s: %s", Interface.getString("power_tooltip_resource"), sResource);
	end
	return "";
end

function resetIntriguePowers(nodeCaster)
	resetIntriguePowersOriginal(nodeCaster);
	ResourceManager.calculateResourcePeriod(ActionsManager.resolveActor(nodeCaster), "Intrigue");
end