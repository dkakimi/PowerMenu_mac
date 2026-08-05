-- powerMenu.lua
-- Liquid Glass 風スターター版

-----------------------------------------------------------------------
-- TeamSpirit
-----------------------------------------------------------------------
-- TeamSpiritのURLを変更したい場合は、ここだけを書き換えればよい。

local TEAMSPIRIT_URL = "https://teamspirit-1227.lightning.force.com/lightning/page/home"

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

-----------------------------------------------------------------------
-- 退勤確認画面（Shutdown選択時のみ表示）
-----------------------------------------------------------------------
-- Power Menuとは別のCanvas・別のmodalとして管理する。
-- 将来、Restart/Sleepにも同様の確認画面を追加したくなった場合は、
-- このセクションを参考にconfirmCanvas / confirmModeをもう一組
-- 用意するか、汎用化して使い回す形に拡張できる。

local shutdownConfirmMode = hs.hotkey.modal.new()
local confirmCanvas
local confirmVisible = false
-- Power Menuと同じく「項目リスト + 選択インデックス」で管理する。
local confirmItems = {
  {key="T", label="Open TeamSpirit"},
  {key="C", label="Continue"},
}
local confirmSelected = 1

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

-- 退勤打刻確認画面の描画。
-- Power Menuと統一感を持たせるため、背景の見た目（グラデーション・
-- 角丸・シャドウ・フォント）はdraw()と同じ値をそのまま使っている。
local function drawShutdownConfirm()
  if confirmCanvas then confirmCanvas:delete() end
  confirmCanvas = hs.canvas.new(frame())

  confirmCanvas:appendElements({
    -- 背景: Power Menuと同じLiquid Glass風グラデーション + 影
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
    -- タイトル
    {
      type="text",
      frame={x=0,y=18,w="100%",h=30},
      text="退勤打刻",
      textAlignment="center",
      textFont=FONT,
      textSize=22,
      textColor={white=1, alpha=0.95},
    },
    -- 本文
    {
      type="text",
      frame={x=20,y=68,w=320,h=50},
      text="TeamSpiritで\n退勤打刻しましたか？",
      textAlignment="center",
      textFont=FONT,
      textSize=17,
      textColor={white=1, alpha=0.92},
    },
  })

  -- 項目リスト（Open TeamSpirit / Continue）
  -- Power Menuのdraw()と同じ「選択中はハイライトの角丸バーを敷く」
  -- 描画方法をそのまま流用し、見た目の統一感を保っている。
  local y = 150

  for i, v in ipairs(confirmItems) do
    if i == confirmSelected then
      confirmCanvas:appendElements({
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

    confirmCanvas:appendElements({
      {
        type="text",
        frame={x=40,y=y,w=230,h=26},
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

  confirmCanvas:appendElements({
    -- 操作ヘルプ + Esc: 戻る
    {
      type="text",
      frame={x=0,y=242,w="100%",h=18},
      text="↑↓ Select   Enter Execute   Esc Back",
      textAlignment="center",
      textFont=FONT,
      textSize=12,
      textColor={white=0.85, alpha=0.7},
    }
  })

  confirmCanvas:level(hs.canvas.windowLevels.popUpMenu)

  confirmCanvas:behavior({
    hs.canvas.windowBehaviors.canJoinAllSpaces,
    hs.canvas.windowBehaviors.fullScreenAuxiliary,
    hs.canvas.windowBehaviors.stationary,
  })

  confirmCanvas:show()
end

local function hide()
  if canvas then canvas:delete(); canvas=nil end
  visible=false
end

-- 退勤確認画面を閉じる（Power Menuのhide()とは別に管理する）
local function hideShutdownConfirm()
  if confirmCanvas then confirmCanvas:delete(); confirmCanvas=nil end
  confirmVisible=false
end

-- Power Menuを消し、退勤確認画面を表示する
local function showShutdownConfirm()
  hide()
  powerMode:exit()
  confirmVisible = true
  confirmSelected = 1
  drawShutdownConfirm()
  shutdownConfirmMode:enter()
end

-- 確認画面を消し、Power Menuへ戻る（Shutdownが選択された状態のまま）
local function showMenu()
  hideShutdownConfirm()
  shutdownConfirmMode:exit()
  powerMode:enter()
end

-----------------------------------------------------------------------
-- シャットダウン前に全アプリを閉じる処理
-----------------------------------------------------------------------
-- シャットダウン前にアプリをきちんと終了させておくことで、
-- 次回起動時に前回開いていたウィンドウが復元されてしまう現象を
-- 起きにくくするのが目的。

-- 終了させたくない(閉じてはいけない)アプリ名の一覧。
-- Finder やこのHammerspoon自身、システムのUIプロセスなどが対象。
-- 将来、閉じたくないアプリが増えた場合はここに追記すればよい。
local APPS_TO_KEEP_RUNNING = {
  ["Finder"] = true,
  ["Hammerspoon"] = true,
  ["Dock"] = true,
  ["SystemUIServer"] = true,
  ["loginwindow"] = true,
  ["WindowServer"] = true,
  ["ControlCenter"] = true,
  ["NotificationCenter"] = true,
}

-- そのアプリを「閉じる対象」にしてよいかどうかを判定する。
-- kind()==1 は、Dockに表示されるような通常のアプリを指す。
-- メニューバーだけの補助アプリやバックグラウンドプロセスは、
-- 誤って終了させるとトラブルの元になるので対象から除外する。
local function isQuittableApp(app)
  local name = app:name()
  if not name or APPS_TO_KEEP_RUNNING[name] then
    return false
  end
  return app:kind() == 1
end

-- 実行中の通常アプリを、すべて正常終了(Cmd+Qと同じ)させる。
-- app:kill() は「終了してください」というイベントを送るだけなので、
-- 未保存の変更があれば、従来どおり保存確認ダイアログが表示される。
local function quitAllApps()
  for _, app in ipairs(hs.application.runningApplications()) do
    if isQuittableApp(app) then
      app:kill()
    end
  end
end

-- quitAllApps() のあと、アプリが実際に終了し終わるまで少し待ってから
-- onDone() を実行する。
-- 保存確認ダイアログの操作待ちなどで、いつまでも終了しないアプリが
-- あった場合にシャットダウンできなくなるのを防ぐため、
-- 待ち時間には上限(maxWaitSeconds)を設けている。
local function waitForAppsToQuitThen(onDone)
  local maxWaitSeconds = 15   -- これ以上は待たない上限(秒)
  local checkInterval = 0.5   -- 何秒おきに確認するか
  local waited = 0

  local function check()
    local stillRunning = false
    for _, app in ipairs(hs.application.runningApplications()) do
      if isQuittableApp(app) then
        stillRunning = true
        break
      end
    end

    if not stillRunning or waited >= maxWaitSeconds then
      onDone()
    else
      waited = waited + checkInterval
      hs.timer.doAfter(checkInterval, check)
    end
  end

  check()
end

-- ウィンドウ復元(前回開いていたウィンドウを勝手に開き直す動作)を無効化する。
-- ログイン画面側の「ウィンドウを再度開く」設定だけでなく、
-- アプリ自身が持っている「前回のウィンドウを覚えておく」機能
-- (NSQuitAlwaysKeepsWindows)も合わせてオフにしておく。
-- こうすることで、シャットダウンのたびに毎回この状態を保証できる。
local function disableWindowRestore()
  hs.execute("defaults write -g NSQuitAlwaysKeepsWindows -bool false")
  hs.execute("defaults -currentHost write com.apple.loginwindow TALLogoutSavesState -bool false")
end

-- 全アプリを閉じてから、実際にシャットダウンを実行する
local function performShutdown()
  hideShutdownConfirm()
  shutdownConfirmMode:exit()

  disableWindowRestore()
  quitAllApps()
  waitForAppsToQuitThen(function()
    hs.execute([[osascript -e 'tell application "System Events" to shut down']])
  end)
end

-- 既定ブラウザでTeamSpiritを開く（選択したら確認画面は閉じる）
local function openTeamSpirit()
  hideShutdownConfirm()
  shutdownConfirmMode:exit()
  hs.urlevent.openURL(TEAMSPIRIT_URL)
end

-- ↑↓で選択した項目をEnterで実行するためのディスパッチャ。
-- Power Menu側のexecuteCurrent(idx)と同じ役割。
local function executeConfirmSelection(idx)
  if idx==1 then
    openTeamSpirit()
  else
    performShutdown()
  end
end

local function executeCurrent(idx)
  if idx==3 then
    -- Shutdownのみ、即実行せず確認画面へ遷移する
    showShutdownConfirm()
    return
  end

  hide(); powerMode:exit()
  if idx==1 then
    hs.execute([[osascript -e 'tell application "System Events" to restart']])
  elseif idx==2 then
    hs.caffeinate.systemSleep()
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

-----------------------------------------------------------------------
-- 退勤確認画面のキーバインド
-----------------------------------------------------------------------

shutdownConfirmMode:bind({}, "escape", showMenu)
shutdownConfirmMode:bind({}, "up", function()
  confirmSelected = ((confirmSelected-2) % #confirmItems) + 1
  drawShutdownConfirm()
end)
shutdownConfirmMode:bind({}, "down", function()
  confirmSelected = (confirmSelected % #confirmItems) + 1
  drawShutdownConfirm()
end)
shutdownConfirmMode:bind({}, "return", function() executeConfirmSelection(confirmSelected) end)
-- T / C は選択状態に関わらず直接実行できるショートカットとして維持する
shutdownConfirmMode:bind({}, "t", openTeamSpirit)
shutdownConfirmMode:bind({}, "c", performShutdown)