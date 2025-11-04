include("shared.lua")

function ENT:Draw()
	self:DrawModel()
end

net.Receive("OpenATMMenu", function()
    local ply = net.ReadEntity()
    local frame = vgui.Create("DFrame")
    frame:SetSize(300, 400)
    frame:SetTitle("ATM Menu")
    frame:Center()
    frame:MakePopup()
    --frame.Paint = function(self,w, h)
    --    draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 0, 120))
    --end

    -- Balance Label
    local balanceLabel = vgui.Create("DLabel", frame)
    balanceLabel:SetPos(20, 40)
    balanceLabel:SetSize(260, 20)

    -- Cash Label
    local cashLabel = vgui.Create("DLabel", frame)
    cashLabel:SetPos(20, 60)
    cashLabel:SetSize(260, 20)
    cashLabel:SetText("Cash: $ ".. ply:getDarkRPVar("money"))


    -- Request balance from server
    net.Start("RequestBalance")
    net.SendToServer()

    -- Update balance label upon receiving server data
    net.Receive("UpdateBalance", function()
        local balance = net.ReadInt(32)
        local interestEnabled = net.ReadBool()  -- Receive the interest status from the server
        balanceLabel:SetText("Balance: $" .. balance .. " (Interest: " .. (interestEnabled and dubz.atm["dubz_atm"].interestRate.."%" or "Disabled") .. ")")
    end)

    -- Common Label and Input (shared for both deposit and withdrawal)
    local amountLabel = vgui.Create("DLabel", frame)
    amountLabel:SetPos(20, 80)
    amountLabel:SetSize(260, 20)
    amountLabel:SetText("Enter Amount:")

    local amountInput = vgui.Create("DTextEntry", frame)
    amountInput:SetPos(20, 100)
    amountInput:SetSize(260, 30)
    amountInput:SetText("0")
    amountInput:SetNumeric(true)  -- Allow only numeric input

    -- Deposit Button
    local depositButton = vgui.Create("DButton", frame)
    depositButton:SetPos(50, 140)
    depositButton:SetSize(200, 40)
    depositButton:SetText("Deposit")
    depositButton.DoClick = function()
        local amount = tonumber(amountInput:GetValue())
        if amount and amount > 0 then
            -- Send a net message with the deposit amount
            net.Start("ATM_Deposit")
            net.WriteInt(amount, 32)
            net.SendToServer()
        else
            chat.AddText(Color(255, 0, 0), "Invalid deposit amount!")
        end
        frame:Close()
    end

    -- Withdraw Button
    local withdrawButton = vgui.Create("DButton", frame)
    withdrawButton:SetPos(50, 200)
    withdrawButton:SetSize(200, 40)
    withdrawButton:SetText("Withdraw")
    withdrawButton.DoClick = function()
        local amount = tonumber(amountInput:GetValue())
        if amount and amount > 0 then
            net.Start("ATM_Withdraw")
            net.WriteInt(amount, 32)
            net.SendToServer()
        else
            chat.AddText(Color(255, 0, 0), "Invalid withdrawal amount!")
        end
        frame:Close()
    end

    -- Toggle Interest Button
    --local toggleInterestButton = vgui.Create("DButton", frame)
    --toggleInterestButton:SetPos(50, 260)
    --toggleInterestButton:SetSize(200, 40)

    -- Set initial button text based on config
    --local interestEnabled = dubz.atm["dubz_atm"].interestEnabled
    --toggleInterestButton:SetText(interestEnabled and "Disable Interest" or "Enable Interest")

    --toggleInterestButton.DoClick = function()
    --    -- Toggle interest on button click
    --    net.Start("ATM_ToggleInterest")
    --    net.SendToServer()
    --end

    -- Close Button (Optional)
    local closeButton = vgui.Create("DButton", frame)
    closeButton:SetPos(50, 310)
    closeButton:SetSize(200, 40)
    closeButton:SetText("Close")
    closeButton.DoClick = function()
        frame:Close()
    end
end)