dubz = dubz or {}

dubz.atm = {
    ["dubz_atm"] = {
        interestEnabled = true,
        interestMin = 0.01,
        interestMax = 0.05,
        interestTime = 240
    }
}

dubz.atm.hacking = {
    time = 60,
    minPayout = 200,
    maxPayout = 1000,
    useRealAccounts = false,

    minPolice = 0,
    policeTeams = {TEAM_POLICE, TEAM_CHIEF, TEAM_MAYOR, TEAM_POLICEM, TEAM_SWATL, TEAM_SWATS, TEAM_SWAT},

    policeReward = 500,
    moneyStacks = 1,

    sounds = {
        place = "weapons/slam/mine_mode.wav",
        start = "buttons/button14.wav",
        loop = "ambient/machines/combine_terminal_loop1.wav",
        success = "buttons/button3.wav",
        fail = "ambient/explosions/explode_4.wav"
    }
}