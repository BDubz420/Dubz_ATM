dubz = dubz or {}

dubz.atm = {
    ["dubz_atm"] = {
        interestEnabled = true,
        interestRate = 0.05,  -- 5% interest rate (optional)
        interestTime = 100  -- Time interval for applying interest (in minutes)
    }
}

--CreateConVar("atm_interest_enabled", "1", FCVAR_REPLICATED, "Toggle ATM interest system (1 = enabled, 0 = disabled)")