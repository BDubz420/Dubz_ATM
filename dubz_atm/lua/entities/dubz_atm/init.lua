AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
include("autorun/dubz_config.lua")

util.AddNetworkString("OpenATMMenu")
util.AddNetworkString("RequestBalance")
util.AddNetworkString("UpdateBalance")
util.AddNetworkString("ATM_Deposit")
util.AddNetworkString("ATM_Withdraw")

function ENT:Hackable()
    return true
end

-- =========================
-- 📁 FILE STORAGE SETUP
-- =========================
if not file.Exists("dubz_atm", "DATA") then
    file.CreateDir("dubz_atm")
end

local function GetPlayerFile(ply)
    return "dubz_atm/" .. ply:SteamID64() .. ".txt"
end

local function SaveAccount(ply, data)
    local path = GetPlayerFile(ply)
    file.Write(path, util.TableToJSON(data, true))
end

-- 🔥 SAFE LOAD + MIGRATION
local function LoadAccount(ply)
    local path = GetPlayerFile(ply)

    if file.Exists(path, "DATA") then
        local data = file.Read(path, "DATA")
        local tbl = util.JSONToTable(data or "")
        return tbl or { balance = 0, history = {} }
    end

    -- MIGRATE FROM PDATA
    local pdataBalance = tonumber(ply:GetPData("bank_balance") or 0) or 0

    local newData = {
        balance = pdataBalance,
        history = {}
    }

    file.Write(path, util.TableToJSON(newData, true))

    print("[Dubz ATM] Migrated " .. ply:Nick() .. " ($" .. pdataBalance .. ")")

    return newData
end

-- =========================
-- 🧾 TRANSACTION LOGGER
-- =========================
local function AddTransaction(ply, acc, data)
    acc.history = acc.history or {}

    table.insert(acc.history, 1, {
        type = data.type,
        amount = data.amount,
        rate = data.rate,
        time = os.time()
    })

    if #acc.history > 25 then
        table.remove(acc.history)
    end
end

-- =========================
-- ENTITY
-- =========================
function ENT:Initialize()
    self:SetModel(self.Model)
    self:SetUseType(SIMPLE_USE)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
end

function ENT:Use(activator)
    if activator:IsPlayer() then
        net.Start("OpenATMMenu")
        net.WriteEntity(activator)
        net.Send(activator)
    end
end

-- =========================
-- LOAD ACCOUNT
-- =========================
hook.Add("PlayerInitialSpawn", "dubz_ATM_LoadAccount", function(ply)
    LoadAccount(ply)
end)

-- =========================
-- BALANCE REQUEST
-- =========================
net.Receive("RequestBalance", function(_, ply)
    local acc = LoadAccount(ply)

    net.Start("UpdateBalance")
    net.WriteInt(acc.balance or 0, 32)
    net.WriteBool(dubz.atm["dubz_atm"].interestEnabled)
    net.WriteTable(acc.history or {})
    net.Send(ply)
end)

-- =========================
-- DEPOSIT
-- =========================
net.Receive("ATM_Deposit", function(_, ply)
    local amount = net.ReadInt(32)

    if amount and amount > 0 then
        local money = ply:getDarkRPVar("money")

        if money >= amount then
            local acc = LoadAccount(ply)

            ply:addMoney(-amount)

            acc.balance = (acc.balance or 0) + amount

            AddTransaction(ply, acc, {
                type = "deposit",
                amount = amount
            })

            SaveAccount(ply, acc)

            ply:ChatPrint("Deposited $" .. amount)
        else
            ply:ChatPrint("Not enough money!")
        end
    end
end)

-- =========================
-- WITHDRAW
-- =========================
net.Receive("ATM_Withdraw", function(_, ply)
    local amount = net.ReadInt(32)

    if amount and amount > 0 then
        local acc = LoadAccount(ply)

        if (acc.balance or 0) >= amount then
            acc.balance = acc.balance - amount

            AddTransaction(ply, acc, {
                type = "withdraw",
                amount = amount
            })

            SaveAccount(ply, acc)

            ply:addMoney(amount)
            ply:ChatPrint("Withdrew $" .. amount)
        else
            ply:ChatPrint("Insufficient funds!")
        end
    end
end)

-- =========================
-- INTEREST SYSTEM
-- =========================
local interestTime = dubz.atm["dubz_atm"].interestTime * 60

timer.Create("ATM_InterestTimer", interestTime, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        local acc = LoadAccount(ply)
        local balance = acc.balance or 0

        if dubz.atm["dubz_atm"].interestEnabled and balance > 0 then
            local minRate = dubz.atm["dubz_atm"].interestMin
            local maxRate = dubz.atm["dubz_atm"].interestMax

            local rate = math.Rand(minRate, maxRate)
            local interest = math.Round(balance * rate)

            acc.balance = balance + interest

            AddTransaction(ply, acc, {
                type = "interest",
                amount = interest,
                rate = rate
            })

            SaveAccount(ply, acc)

            ply:SetNWFloat("ATM_LastInterestRate", rate)

            ply:ChatPrint("Interest (" .. math.Round(rate * 100, 2) .. "%): $" .. interest)
        end
    end
end)

-- =========================
-- ADMIN COMMAND
-- =========================
concommand.Add("clear_bank_balance", function(ply, _, args)
    if not ply:IsAdmin() then return end

    local name = args[1]
    if not name then return end

    for _, target in ipairs(player.GetAll()) do
        if string.find(string.lower(target:Nick()), string.lower(name)) then
            local acc = LoadAccount(target)
            acc.balance = 0
            SaveAccount(target, acc)

            ply:ChatPrint("Cleared " .. target:Nick())
            target:ChatPrint("Your balance was cleared.")
            return
        end
    end
end)