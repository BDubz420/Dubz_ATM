if SERVER then
    AddCSLuaFile()
end

SWEP.PrintName = "ATM Hacker"
SWEP.Author = "Dubz"
SWEP.Category = "Dubz ATM"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.ViewModel = "models/weapons/v_slam.mdl"
SWEP.WorldModel = "models/weapons/w_slam.mdl"
SWEP.HoldType = "slam"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary = SWEP.Primary

-- =========================
-- 🔧 POLICE HELPERS
-- =========================
local function IsPolice(ply)
    for _, t in ipairs(dubz.atm.hacking.policeTeams or {}) do
        if ply:Team() == t then return true end
    end
    return false
end

local function CountPolice()
    local c = 0
    for _, ply in ipairs(player.GetAll()) do
        if IsPolice(ply) then c = c + 1 end
    end
    return c
end

-- =========================
-- 💥 HACK ENTITY
-- =========================
local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_gmodentity"

function ENT:Initialize()
    if CLIENT then return end

    self:SetModel("models/weapons/w_slam.mdl")
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)

    self.HackEnd = CurTime() + dubz.atm.hacking.time

    self:EmitSound(dubz.atm.hacking.sounds.start)

    -- loop sound
    self.LoopSound = CreateSound(self, dubz.atm.hacking.sounds.loop)
    self.LoopSound:Play()
end

function ENT:SetATM(atm, owner)
    self.ATM = atm
    self.Owner = owner
end

function ENT:Think()
    if CLIENT then return end

    -- sparks
    local effect = EffectData()
    effect:SetOrigin(self:GetPos())
    util.Effect("sparks", effect)

    if CurTime() >= self.HackEnd then
        self:CompleteHack()
        return
    end

    self:NextThink(CurTime() + 0.5)
    return true
end

function ENT:CompleteHack()
    if not IsValid(self.Owner) then return end

    local cfg = dubz.atm.hacking

    local payout = math.random(cfg.minPayout, cfg.maxPayout)

    -- 💰 real account drain
    if cfg.useRealAccounts then
        local victim = table.Random(player.GetAll())
        if victim and victim ~= self.Owner then
            local acc = LoadAccount(victim)
            local stolen = math.min(acc.balance or 0, payout)
            acc.balance = acc.balance - stolen
            SaveAccount(victim, acc)
            payout = stolen
        end
    end

    local perStack = math.floor(payout / cfg.moneyStacks)

    for i = 1, cfg.moneyStacks do
        local money = ents.Create("spawned_money")
        money:SetPos(self:GetPos() + self:GetRight() * 12 + Vector(0, 0, i * 2))
        money:Setamount(perStack)
        money:Spawn()
    end

    self:EmitSound(cfg.sounds.success)

    self.Owner:ChatPrint("Hack successful! $" .. payout)

    self:Remove()
end

function ENT:OnTakeDamage(dmg)
    if CLIENT then return end

    local attacker = dmg:GetAttacker()
    if not IsValid(attacker) then return end

    if attacker:IsPlayer() and IsPolice(attacker) then
        attacker:addMoney(dubz.atm.hacking.policeReward)
        attacker:ChatPrint("You stopped the ATM hack!")

        local effect = EffectData()
        effect:SetOrigin(self:GetPos())
        util.Effect("Explosion", effect)

        self:EmitSound(dubz.atm.hacking.sounds.fail)

        self:Remove()
    end
end

function ENT:OnRemove()
    if CLIENT then return end

    if self.LoopSound then
        self.LoopSound:Stop()
    end

    if IsValid(self.ATM) then
        self.ATM.HackActive = false
    end
end

scripted_ents.Register(ENT, "dubz_atm_hack_device")

-- =========================
-- 🎬 AIM + ANIMATION SYSTEM
-- =========================
function SWEP:ValidAim()
    local trace = self.Owner:GetEyeTrace()

    if not IsValid(trace.Entity) then return false end
    if trace.Entity:GetClass() ~= "dubz_atm" then return false end
    if trace.Entity.HackActive then return false end

    if trace.HitPos:Distance(self.Owner:GetShootPos()) > 100 then
        return false
    end

    return true
end

function SWEP:Think()
    if self:GetNextPrimaryFire() > CurTime() then return end

    if self:ValidAim() then
        if not self.Aiming then
            self.Aiming = true
            self:SendWeaponAnim(ACT_SLAM_THROW_TO_TRIPMINE_ND)
        end
    else
        if self.Aiming then
            self.Aiming = false
            self:SendWeaponAnim(ACT_SLAM_TRIPMINE_TO_THROW_ND)
        end
    end
end

-- =========================
-- 🔫 PRIMARY ATTACK
-- =========================
function SWEP:PrimaryAttack()
    if CLIENT then return end

    local ply = self:GetOwner()
    local trace = ply:GetEyeTrace()
    local atm = trace.Entity

    if not self:ValidAim() then return end

    if CountPolice() < dubz.atm.hacking.minPolice then
        ply:ChatPrint("Not enough police online!")
        return
    end

    self:SendWeaponAnim(ACT_SLAM_TRIPMINE_ATTACH)
    ply:SetAnimation(PLAYER_ATTACK1)

    timer.Simple(0.3, function()
        if not IsValid(ply) then return end

        local ent = ents.Create("dubz_atm_hack_device")

        local ang = trace.HitNormal:Angle()
        ang:RotateAroundAxis(ang:Right(), 90)
        ang:RotateAroundAxis(ang:Up(), 90)

        ent:SetPos(trace.HitPos + trace.HitNormal * 2)
        ent:SetAngles(ang)
        ent:SetParent(atm)

        ent:Spawn()
        ent:SetATM(atm, ply)

        atm.HackActive = true

        ent:EmitSound(dubz.atm.hacking.sounds.place)

        -- 🚔 alert
        for _, v in ipairs(player.GetAll()) do
            if IsPolice(v) then
                v:ChatPrint("⚠ ATM HACK IN PROGRESS!")
            end
        end

        ply:StripWeapon(self:GetClass())
    end)
end