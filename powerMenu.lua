-- powerMenu.lua
-- Liquid Glass 風スターター版

local powerMode = hs.hotkey.modal.new()
local canvas
local visible = false
local items = {
  {key="R", label="Restart"},
  {key="S", label="Sleep"},
  {key="U", label="Shutdown"},
  {key="L", label="Lock"},
}
local selected = 1

local CORNER_RADIUS = 26
-- ".AppleSystemUIFont" はSF系フォントを指す非公式な指定方法として
-- コミュニティのサンプルでよく使われていますが、環境によっては
-- 期待通り表示されないことがあります。うまくいかない場合は
-- "Helvetica Neue" 等に変更してください。
local FONT = ".AppleSystemUIFont"

local function frame()
  local f = hs.screen.mainScreen():fullFrame()
  return {x=f.x+f.w/2-180,y=f.y+f.h/2-140,w=360,h=280}
end

local function draw()
  if canvas then canvas:delete() end
  canvas = hs.canvas.new(frame())

  canvas:appendElements({
    -- 背景: ダークガラス風グラデーション + 影
    {
      type="rectangle",
      action="fill",
      roundedRectRadii={xRadius=CORNER_RADIUS,yRadius=CORNER_RADIUS},
      fillGradient="linear",
      fillGradientColors={
        {white=0.16, alpha=0.86},
        {white=0.04, alpha=0.94},
      },
      fillGradientAngle=115,
      withShadow=true,
      shadow={
        blurRadius=30,
        color={alpha=0.55, white=0},
        offset={h=-8, w=0},
      },
    },
    {
      type="rectangle",
      action="stroke",
      roundedRectRadii={xRadius=CORNER_RADIUS,yRadius=CORNER_RADIUS},
      strokeColor={white=1, alpha=0.20},
      strokeWidth=1,
    },
    {
      type="text",
      frame={x=0,y=18,w="100%",h=30},
      text="Power Menu",
      textAlignment="center",
      textFont=FONT,
      textSize=22,
      textColor={white=1, alpha=0.95},
    }
  })

  local y = 70

  for i, v in ipairs(items) do
    if i == selected then
      canvas:appendElements({
        {
          type="rectangle",
          action="fill",
          frame={x=20,y=y-6,w=320,h=38},
          roundedRectRadii={xRadius=12,yRadius=12},
          fillGradient="linear",
          fillGradientColors={
            {white=1, alpha=0.22},
            {white=1, alpha=0.09},
          },
          fillGradientAngle=90,
          strokeColor={white=1, alpha=0.25},
          strokeWidth=0.75,
          withShadow=true,
          shadow={blurRadius=10, color={alpha=0.35,white=0}, offset={h=-2,w=0}},
        }
      })
    end

    -- 左：機能名
    canvas:appendElements({
      {
        type="text",
        frame={x=40,y=y,w=180,h=26},
        text=v.label,
        textFont=FONT,
        textSize=19,
        textColor={white=1, alpha=0.95},
      },
      {
        type="text",
        frame={x=250,y=y,w=50,h=26},
        text=v.key,
        textAlignment="right",
        textFont=FONT,
        textSize=16,
        textColor={white=0.75, alpha=0.9},
      }
    })

    y = y + 42
  end

  canvas:appendElements({
    {
      type="text",
      frame={x=0,y=242,w="100%",h=18},
      text="↑↓ Select   Enter Execute   Esc / ⌥X Cancel",
      textAlignment="center",
      textFont=FONT,
      textSize=12,
      textColor={white=0.85, alpha=0.7},
    }
  })

  canvas:level(hs.canvas.windowLevels.popUpMenu)

    canvas:behavior({
    hs.canvas.windowBehaviors.canJoinAllSpaces,
    hs.canvas.windowBehaviors.fullScreenAuxiliary,
    hs.canvas.windowBehaviors.stationary,
})

  canvas:show()
end

local function hide()
  if canvas then canvas:delete(); canvas=nil end
  visible=false
end

local function executeCurrent(idx)
  hide(); powerMode:exit()
  if idx==1 then
    hs.execute([[osascript -e 'tell application "System Events" to restart']])
  elseif idx==2 then
    hs.caffeinate.systemSleep()
  elseif idx==3 then
    hs.execute([[osascript -e 'tell application "System Events" to shut down']])
  else
    hs.caffeinate.lockScreen()
  end
end

function powerMode:entered()
  visible=true
  draw()
end

function powerMode:exited()
  hide()
end

hs.hotkey.bind({"alt"},"x",function()
  if visible then
    hide(); powerMode:exit()
  else
    powerMode:enter()
  end
end)

powerMode:bind({}, "escape", function() hide(); powerMode:exit() end)
powerMode:bind({}, "up", function() selected=((selected-2)%#items)+1; draw() end)
powerMode:bind({}, "down", function() selected=(selected%#items)+1; draw() end)
powerMode:bind({}, "return", function() executeCurrent(selected) end)
powerMode:bind({}, "r", function() executeCurrent(1) end)
powerMode:bind({}, "s", function() executeCurrent(2) end)
powerMode:bind({}, "u", function() executeCurrent(3) end)
powerMode:bind({}, "l", function() executeCurrent(4) end)