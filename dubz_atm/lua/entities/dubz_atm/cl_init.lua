include("shared.lua")

function ENT:Draw()
    self:DrawModel()
end

net.Receive("OpenATMMenu", function()
    local ply = net.ReadEntity()

    local frame = vgui.Create("DFrame")
    frame:SetSize(360, 460)
    frame:SetTitle("ATM Menu")
    frame:Center()
    frame:MakePopup()

    local padding = 20
    local fullWidth = frame:GetWide() - (padding * 2)

    -- Balance
    local balanceLabel = vgui.Create("DLabel", frame)
    balanceLabel:SetPos(padding, 40)
    balanceLabel:SetSize(fullWidth, 20)

    -- Cash
    local cashLabel = vgui.Create("DLabel", frame)
    cashLabel:SetPos(padding, 60)
    cashLabel:SetSize(fullWidth, 20)
    cashLabel:SetText("Cash: $" .. ply:getDarkRPVar("money"))

    -- Request data
    net.Start("RequestBalance")
    net.SendToServer()

    -- Amount input
    local amountInput = vgui.Create("DTextEntry", frame)
    amountInput:SetPos(padding, 100)
    amountInput:SetSize(fullWidth, 30)
    amountInput:SetNumeric(true)
    amountInput:SetPlaceholderText( "How much would you like to move?" )

    -- Deposit button (FULL WIDTH)
    local deposit = vgui.Create("DButton", frame)
    deposit:SetPos(padding, 140)
    deposit:SetSize(fullWidth, 35)
    deposit:SetText("Deposit")

    -- Withdraw button (FULL WIDTH)
    local withdraw = vgui.Create("DButton", frame)
    withdraw:SetPos(padding, 185)
    withdraw:SetSize(fullWidth, 35)
    withdraw:SetText("Withdraw")

    -- =========================
    -- 📋 TRANSACTIONS LIST
    -- =========================

    local historyList = vgui.Create("DListView", frame)
    historyList:SetPos(padding, 235)
    historyList:SetSize(fullWidth, 180)

    historyList:AddColumn("Time")
    historyList:AddColumn("Type")
    historyList:AddColumn("Amount")

    -- =========================
    -- BUTTON LOGIC
    -- =========================

    deposit.DoClick = function()
        local amt = tonumber(amountInput:GetValue())
        if amt and amt > 0 then
            net.Start("ATM_Deposit")
            net.WriteInt(amt, 32)
            net.SendToServer()
        end
        frame:Close()
    end

    withdraw.DoClick = function()
        local amt = tonumber(amountInput:GetValue())
        if amt and amt > 0 then
            net.Start("ATM_Withdraw")
            net.WriteInt(amt, 32)
            net.SendToServer()
        end
        frame:Close()
    end

    -- =========================
    -- RECEIVE DATA
    -- =========================

    net.Receive("UpdateBalance", function()
        local balance = net.ReadInt(32)
        net.ReadBool() -- interest enabled (unused here)
        local history = net.ReadTable()

        local rate = LocalPlayer():GetNWFloat("ATM_LastInterestRate", 0)

        balanceLabel:SetText("Balance: $" .. balance ..
            " (Last Interest: " .. math.Round(rate * 100, 2) .. "%)")

        historyList:Clear()

        for _, entry in ipairs(history or {}) do
            local time = os.date("%m/%d %H:%M", entry.time or os.time())
            local typeText = ""
            local amountText = ""

            if entry.type == "deposit" then
                typeText = "Deposit"
                amountText = "+$" .. entry.amount
            elseif entry.type == "withdraw" then
                typeText = "Withdraw"
                amountText = "-$" .. entry.amount
            elseif entry.type == "interest" then
                typeText = "Interest (" .. math.Round((entry.rate or 0) * 100, 2) .. "%)"
                amountText = "+$" .. entry.amount
            end

            historyList:AddLine(time, typeText, amountText)
        end
    end)
end)