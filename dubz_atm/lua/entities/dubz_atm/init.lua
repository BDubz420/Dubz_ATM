AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
include("autorun/dubz_config.lua")

util.AddNetworkString("OpenATMMenu")
util.AddNetworkString("RequestBalance")
util.AddNetworkString("UpdateBalance")
util.AddNetworkString("ATM_Deposit")
util.AddNetworkString("ATM_Withdraw")
util.AddNetworkString("ATM_ToggleInterest")

-- Initialize entity
function ENT:Initialize()
    self:SetModel(self.Model)
    self:SetUseType( SIMPLE_USE )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
end

-- Define the behavior when a player interacts with the ATM
function ENT:Use(activator, caller)
    -- Check if the activator is a player
    if activator:IsPlayer() then
        net.Start("OpenATMMenu")
        net.WriteEntity(activator)
        net.Send(activator)  -- Open the ATM menu for the player who interacted with it
    end
end

-- Initialize player bank data
hook.Add("PlayerInitialSpawn", "dubz_ATM_InitializeBank", function(ply)
    if not ply:GetPData("bank_balance") then
        ply:SetPData("bank_balance", 0)
    end
end)

-- Request balance from server
net.Receive("RequestBalance", function(len, ply)
    local balance = tonumber(ply:GetPData("bank_balance"))
    net.Start("UpdateBalance")
    net.WriteInt(balance, 32)
    net.WriteBool(dubz.atm["dubz_atm"].interestEnabled)
    net.Send(ply)
end)

-- Deposit command (server-side)
net.Receive("ATM_Deposit", function(len, ply)
    local amount = net.ReadInt(32)

    -- Check if the player has enough money to deposit
    if IsValid(ply) and amount and amount > 0 then


        local plyMoney = ply:getDarkRPVar("money")  -- Get player's balance
        if plyMoney >= amount then
            -- Deduct money from the player's wallet
            ply:addMoney(-amount)  -- Subtract the deposit amount
            -- Optionally, store this amount in the ATM (e.g., in a variable)

            -- ATMBalance = ATMBalance + amount  -- Update the ATM balance
            local currentBalance = tonumber(ply:GetPData("bank_balance"))
            ply:SetPData("bank_balance", currentBalance + amount)

            -- Confirm the deposit
            ply:ChatPrint("You have deposited $" .. amount)
        else
            -- Notify the player about insufficient funds
            ply:ChatPrint("You don't have enough money to deposit!")
        end
    else
        ply:ChatPrint("Invalid deposit amount!")
    end
end)

-- Withdraw command (server-side)
net.Receive("ATM_Withdraw", function(len, ply)
    local amount = net.ReadInt(32)
    if amount and amount > 0 then
        local currentBalance = tonumber(ply:GetPData("bank_balance"))
        if currentBalance >= amount then
            ply:SetPData("bank_balance", currentBalance - amount)
            ply:addMoney(amount)  -- Adds money to the player's wallet
            ply:ChatPrint("Withdrew $" .. amount)
        else
            ply:ChatPrint("Insufficient funds!")
        end
    else
        ply:ChatPrint("Invalid withdrawal amount!")
    end
end)

-- Toggle interest system
net.Receive("ATM_ToggleInterest", function(len, ply)
    local currentState = dubz.atm["dubz_atm"].interestEnabled
    RunConsoleCommand("atm_interest_enabled", not currentState)
end)

local interestTime = dubz.atm["dubz_atm"].interestTime * 60  -- Convert minutes to seconds
-- Apply interest every configured time interval
timer.Create("ATM_InterestTimer", interestTime, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if ply:GetPData("bank_balance") then
            local balance = tonumber(ply:GetPData("bank_balance"))
            -- Ensure the interest system is enabled
            if dubz.atm["dubz_atm"].interestEnabled then
                if balance <= 0 then
                    ply:ChatPrint("No Interest was applied! Your balance is: $" .. balance)
                else

                    local interest = math.Round(balance * dubz.atm["dubz_atm"].interestRate)  -- Calculate interest
                    ply:SetPData("bank_balance", balance + interest)  -- Apply the interest to the bank balance
                    ply:ChatPrint("Interest applied! New balance: $" .. math.Round(balance + interest, 2))
                end
            end
        end
    end
end)

-- Command to clear a player's bank balance by partial name
concommand.Add("clear_bank_balance", function(ply, cmd, args)
    if not ply:IsAdmin() then  -- Check if the player is an admin
        ply:ChatPrint("You do not have permission to use this command.")
        return
    end

    local partialName = args[1]  -- Get the partial name from the arguments

    if not partialName then
        ply:ChatPrint("You must provide a player's partial name.")
        return
    end

    local matchingPlayers = {}

    -- Loop through all players and check if their name contains the partial name
    for _, target in ipairs(player.GetAll()) do
        if string.find(string.lower(target:Nick()), string.lower(partialName)) then
            table.insert(matchingPlayers, target)
        end
    end

    -- Check if no player was found
    if #matchingPlayers == 0 then
        ply:ChatPrint("No players found with the name '" .. partialName .. "'.")
        return
    end

    -- If more than one player is found, notify the admin and don't proceed
    if #matchingPlayers > 1 then
        ply:ChatPrint("Multiple players found with the name '" .. partialName .. "'. Please be more specific.")
        return
    end

    -- Clear the bank balance of the found player
    local targetPlayer = matchingPlayers[1]
    targetPlayer:SetPData("bank_balance", 0)

    -- Notify the admin and the target player
    ply:ChatPrint("Cleared " .. targetPlayer:Nick() .. "'s bank balance.")
    targetPlayer:ChatPrint("Your bank balance has been cleared by an admin.")
end)