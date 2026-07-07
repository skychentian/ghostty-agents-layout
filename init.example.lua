pcall(function()
  hs.ipc.cliInstall()
end)

local ghosttyAgentsLayout = require("ghostty_agents_layout")

ghosttyAgentsLayout.bindHotkeys()
