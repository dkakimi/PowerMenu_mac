-----------------------------------------------------------------------
-- TeamSpirit Reminder (fake ".NET Framework" error dialog版)
--
-- 起動時、日付が変わった瞬間、スリープ復帰時のいずれでも
-- その日まだTeamSpiritを開いていなければ
-- 画面全体を覆う偽エラーダイアログを表示して操作をブロックする。
--
-- powerMenu.luaとは完全に独立したモジュール。
-----------------------------------------------------------------------

local M = {}

-----------------------------------------------------------------------
-- 設定
-----------------------------------------------------------------------

local TEAMSPIRIT_URL = "https://teamspirit-1227.lightning.force.com/lightning/page/home"

local SAVE_FILE =
    os.getenv("HOME") .. "/.hammerspoon/teamspirit_last_open.txt"

-- ダイアログ本体のサイズ(折りたたみ時 / 詳細展開時)
local DIALOG_W          = 560
local DIALOG_H_COLLAPSED = 175
local DIALOG_H_EXPANDED  = 380

-----------------------------------------------------------------------
-- 内部変数
-----------------------------------------------------------------------

local canvas = nil
local expanded = false
local wakeWatcher = nil

-----------------------------------------------------------------------
-- 今日の日付を取得
-----------------------------------------------------------------------

local function todayString()
    return os.date("%Y-%m-%d")
end

-----------------------------------------------------------------------
-- 保存ファイル読込
-----------------------------------------------------------------------

local function readSavedDate()

    local file = io.open(SAVE_FILE, "r")

    if not file then
        return nil
    end

    local text = file:read("*a")

    file:close()

    if not text then
        return nil
    end

    text = text:gsub("%s+", "")

    if text == "" then
        return nil
    end

    return text

end

-----------------------------------------------------------------------
-- 保存ファイル書込
-----------------------------------------------------------------------

local function saveToday()

    local file = io.open(SAVE_FILE, "w")

    if not file then
        return false
    end

    local ok = file:write(todayString())

    file:close()

    return ok ~= nil

end

-----------------------------------------------------------------------
-- Canvasを閉じる
-----------------------------------------------------------------------

local function closeReminder()

    if canvas then
        canvas:delete()
        canvas = nil
    end

    expanded = false

end

-----------------------------------------------------------------------
-- ブラウザの「今開いているウィンドウID一覧」を取得
-----------------------------------------------------------------------

local function collectWindowIDs(bundleID)

    local ids = {}
    local app = hs.application.get(bundleID)

    if not app then
        return ids
    end

    for _, win in ipairs(app:allWindows()) do
        ids[win:id()] = true
    end

    return ids

end

-----------------------------------------------------------------------
-- TeamSpiritが開いたであろうウィンドウを探して前面化
--
-- 1. まず「URLを開く前には無かった新しいウィンドウ」を探す
--    (これが一番確実: 新規ウィンドウでTeamSpiritが開くケース)
-- 2. 見つからなければ、タイトルに手がかりの文字列が
--    含まれるウィンドウを探す
--    (既存ウィンドウの中に新しいタブとして開くケース)
-----------------------------------------------------------------------

local function focusTeamSpiritWindow(bundleID, beforeIDs)

    local app = hs.application.get(bundleID)

    if not app then
        return false
    end

    -- ① 新しく増えたウィンドウを探す
    for _, win in ipairs(app:allWindows()) do
        if not beforeIDs[win:id()] then
            win:raise()
            win:focus()
            return true
        end
    end

    -- ② タイトルに手がかりがあるウィンドウを探す
    for _, win in ipairs(app:allWindows()) do
        local title = win:title() or ""
        if title:find("TeamSpirit")
            or title:find("teamspirit")
            or title:find("Lightning")
            or title:find("Salesforce")
        then
            win:raise()
            win:focus()
            return true
        end
    end

    return false

end

-----------------------------------------------------------------------
-- TeamSpiritを開く
-----------------------------------------------------------------------

local function openTeamSpirit()

    ---------------------------------------------------
    -- URLを開く前に、今のウィンドウ一覧を記録しておく
    ---------------------------------------------------

    local browserBundleID = hs.urlevent.getDefaultHandler("http")
    local beforeIDs = {}

    if browserBundleID then
        beforeIDs = collectWindowIDs(browserBundleID)
    end

    ---------------------------------------------------
    -- URLを開く
    ---------------------------------------------------

    local ok = pcall(function()
        hs.urlevent.openURL(TEAMSPIRIT_URL)
    end)

    if not ok then
        hs.alert.show("TeamSpiritを開けませんでした")
        return
    end

    ---------------------------------------------------
    -- 開いたTeamSpiritのウィンドウを最前面に持ってくる
    --
    -- hs.urlevent.openURL はURLを開くだけで、
    -- どのウィンドウを前面にするかまでは制御してくれない。
    -- ブラウザに他のウィンドウ(ホーム画面など)が
    -- すでに開いていると、そちらが前面に来てしまうことが
    -- あるため、TeamSpiritのウィンドウを名指しで探して
    -- 前面化する。ページの読み込みに時間がかかることがあるので
    -- 何回か時間差でリトライする。
    ---------------------------------------------------

    if browserBundleID then

        hs.application.launchOrFocusByBundleID(browserBundleID)

        for _, delay in ipairs({ 0.4, 1.0, 1.8, 3.0 }) do
            hs.timer.doAfter(delay, function()
                focusTeamSpiritWindow(browserBundleID, beforeIDs)
            end)
        end

    end

    ---------------------------------------------------
    -- 日付保存
    ---------------------------------------------------

    if not saveToday() then
        hs.alert.show("保存に失敗しました")
        return
    end

    ---------------------------------------------------
    -- 閉じる
    ---------------------------------------------------

    closeReminder()

end

-----------------------------------------------------------------------
-- 描画本体
--
-- expandedフラグに応じてダイアログ全体を作り直す。
-- canvas自体は「画面全体」を覆っており、その上に
-- 中央寄せしたダイアログ風の要素を並べることで
-- 画面操作をブロックしつつ、ダイアログだけ見た目を再現する。
-----------------------------------------------------------------------

local function render()

    if not canvas then
        return
    end

    local screenFrame = canvas:frame()

    local dialogH = expanded and DIALOG_H_EXPANDED or DIALOG_H_COLLAPSED
    local dialogX = (screenFrame.w - DIALOG_W) / 2
    local dialogY = (screenFrame.h - dialogH) / 2

    -------------------------------------------------------------------
    -- 要素はいったんテーブルに積んでから、最後に一括で
    -- canvas:replaceElements() に渡す
    -- (canvas[n] への直接代入や、空テーブルでの
    --  replaceElements({}) 呼び出しは「要素定義が不正」という
    --  エラーの原因になるため使わない)
    -------------------------------------------------------------------

    local elements = {}

    -------------------------------------------------------------------
    -- 画面全体を覆う透明オーバーレイ
    -- (ここをクリックしても何も起きない = 他アプリの操作をブロック)
    -------------------------------------------------------------------

    table.insert(elements, {
        id = "overlay",
        type = "rectangle",
        action = "fill",
        fillColor = { red = 0, green = 0, blue = 0, alpha = 0.001 },
        frame = { x = 0, y = 0, w = screenFrame.w, h = screenFrame.h },
        trackMouseDown = true,
        trackMouseUp = true,
    })

    -------------------------------------------------------------------
    -- ダイアログ外枠(影)
    -------------------------------------------------------------------

    table.insert(elements, {
        type = "rectangle",
        action = "fill",
        fillColor = { red = 0, green = 0, blue = 0, alpha = 0.35 },
        frame = { x = dialogX + 4, y = dialogY + 4, w = DIALOG_W, h = dialogH },
    })

    -------------------------------------------------------------------
    -- ダイアログ本体(白背景 + 灰枠)
    -------------------------------------------------------------------

    table.insert(elements, {
        type = "rectangle",
        action = "strokeAndFill",
        fillColor = { red = 0.93, green = 0.93, blue = 0.93, alpha = 1 },
        strokeColor = { white = 0.35, alpha = 1 },
        strokeWidth = 1,
        frame = { x = dialogX, y = dialogY, w = DIALOG_W, h = dialogH },
    })

    -------------------------------------------------------------------
    -- タイトルバー(XPクラシック風グラデーション)
    -------------------------------------------------------------------

    table.insert(elements, {
        type = "rectangle",
        action = "fill",
        fillGradient = "linear",
        fillGradientColors = {
            { red = 0.03, green = 0.11, blue = 0.42, alpha = 1 },
            { red = 0.40, green = 0.62, blue = 0.93, alpha = 1 },
        },
        fillGradientAngle = 0,
        frame = { x = dialogX, y = dialogY, w = DIALOG_W, h = 26 },
    })

    -------------------------------------------------------------------
    -- タイトルバー文字
    -------------------------------------------------------------------

    table.insert(elements, {
        type = "text",
        text = "Microsoft .NET Framework",
        textSize = 13,
        textColor = { white = 1 },
        textFont = "Hiragino Sans",
        frame = { x = dialogX + 10, y = dialogY + 4, w = DIALOG_W - 60, h = 20 },
    })

    -------------------------------------------------------------------
    -- タイトルバー右上の閉じるボタン(押すとTeamSpiritを開く)
    -------------------------------------------------------------------

    table.insert(elements, {
        id = "btn_titlebar_close",
        type = "rectangle",
        action = "fill",
        fillColor = { red = 0.82, green = 0.15, blue = 0.15, alpha = 1 },
        frame = { x = dialogX + DIALOG_W - 24, y = dialogY + 4, w = 18, h = 18 },
        trackMouseDown = true,
        trackMouseUp = true,
    })

    table.insert(elements, {
        type = "text",
        text = "×",
        textSize = 15,
        textColor = { white = 1 },
        textAlignment = "center",
        frame = { x = dialogX + DIALOG_W - 24, y = dialogY + 1, w = 18, h = 18 },
    })

    -------------------------------------------------------------------
    -- エラーアイコン(赤丸に×)
    -------------------------------------------------------------------

    table.insert(elements, {
        type = "circle",
        action = "fill",
        fillColor = { red = 0.85, green = 0.10, blue = 0.10, alpha = 1 },
        center = { x = dialogX + 45, y = dialogY + 60 },
        radius = 20,
    })

    table.insert(elements, {
        type = "text",
        text = "×",
        textSize = 26,
        textColor = { white = 1 },
        textAlignment = "center",
        textFont = "Helvetica-Bold",
        frame = { x = dialogX + 45 - 14, y = dialogY + 60 - 20, w = 28, h = 34 },
    })

    -------------------------------------------------------------------
    -- 本文
    -------------------------------------------------------------------

    table.insert(elements, {
        type = "text",
        text =
            "アプリケーションのコンポーネントで、本日の出勤打刻が行われていないこと" ..
            "を検知しました。[続行]をクリックすると、TeamSpiritを起動し出勤打刻を行" ..
            "います。打刻が完了するまで、この画面は繰り返し表示されます。",
        textSize = 12,
        textColor = { white = 0.1 },
        textFont = "Hiragino Sans",
        frame = { x = dialogX + 80, y = dialogY + 36, w = DIALOG_W - 100, h = 62 },
    })

    -------------------------------------------------------------------
    -- 区切り線
    -------------------------------------------------------------------

    table.insert(elements, {
        type = "rectangle",
        action = "fill",
        fillColor = { white = 0.6, alpha = 1 },
        frame = { x = dialogX + 10, y = dialogY + dialogH - 71, w = DIALOG_W - 20, h = 1 },
    })

    -------------------------------------------------------------------
    -- インデックスエラー本文(下段の実際のメッセージ)
    -------------------------------------------------------------------

    table.insert(elements, {
        type = "text",
        text = "本日の出勤打刻が完了していません。",
        textSize = 12,
        textColor = { white = 0.1 },
        textFont = "Hiragino Sans",
        frame = { x = dialogX + 10, y = dialogY + dialogH - 65, w = DIALOG_W - 20, h = 20 },
    })

    -------------------------------------------------------------------
    -- 「詳細」トグル
    -------------------------------------------------------------------

    table.insert(elements, {
        id = "detail_toggle",
        type = "text",
        text = (expanded and "▼ 詳細(D)" or "▶ 詳細(D)"),
        textSize = 12,
        textColor = { red = 0.1, green = 0.2, blue = 0.6, alpha = 1 },
        frame = { x = dialogX + 10, y = dialogY + dialogH - 34, w = 100, h = 20 },
        trackMouseDown = true,
        trackMouseUp = true,
    })

    -------------------------------------------------------------------
    -- 「続行(C)」ボタン
    -------------------------------------------------------------------

    table.insert(elements, {
        id = "btn_continue",
        type = "rectangle",
        action = "strokeAndFill",
        fillGradient = "linear",
        fillGradientColors = {
            { white = 1, alpha = 1 },
            { white = 0.85, alpha = 1 },
        },
        fillGradientAngle = 90,
        strokeColor = { white = 0.4, alpha = 1 },
        strokeWidth = 1,
        roundedRectRadii = { xRadius = 4, yRadius = 4 },
        frame = { x = dialogX + DIALOG_W - 280, y = dialogY + dialogH - 38, w = 100, h = 26 },
        trackMouseDown = true,
        trackMouseUp = true,
    })

    table.insert(elements, {
        type = "text",
        text = "出勤する(C)",
        textSize = 12,
        textColor = { white = 0.05 },
        textAlignment = "center",
        frame = { x = dialogX + DIALOG_W - 280, y = dialogY + dialogH - 34, w = 100, h = 20 },
    })

    -------------------------------------------------------------------
    -- 「終了(O)」ボタン
    -------------------------------------------------------------------

    table.insert(elements, {
        id = "btn_exit",
        type = "rectangle",
        action = "strokeAndFill",
        fillGradient = "linear",
        fillGradientColors = {
            { white = 1, alpha = 1 },
            { white = 0.85, alpha = 1 },
        },
        fillGradientAngle = 90,
        strokeColor = { white = 0.4, alpha = 1 },
        strokeWidth = 1,
        roundedRectRadii = { xRadius = 4, yRadius = 4 },
        frame = { x = dialogX + DIALOG_W - 170, y = dialogY + dialogH - 38, w = 160, h = 26 },
        trackMouseDown = true,
        trackMouseUp = true,
    })

    table.insert(elements, {
        type = "text",
        text = "TeamSpiritを開く(O)",
        textSize = 12,
        textColor = { white = 0.05 },
        textAlignment = "center",
        frame = { x = dialogX + DIALOG_W - 170, y = dialogY + dialogH - 34, w = 160, h = 20 },
    })

    -------------------------------------------------------------------
    -- 詳細展開時のスタックトレース風テキスト
    -------------------------------------------------------------------

    if expanded then

        table.insert(elements, {
            type = "rectangle",
            action = "strokeAndFill",
            fillColor = { white = 1, alpha = 1 },
            strokeColor = { white = 0.6, alpha = 1 },
            strokeWidth = 1,
            frame = { x = dialogX + 10, y = dialogY + 140, w = DIALOG_W - 20, h = dialogH - 180 },
        })

        table.insert(elements, {
            type = "text",
            text =
                "************** 例外テキスト **************\n" ..
                "System.IndexOutOfRangeException: TeamSpiritに本日まだ打刻していません。\n" ..
                "   場所 TeamSpiritReminder.Check.今日の予定() 行 22\n" ..
                "   場所 TeamSpiritReminder.Main.Start() 行 7\n\n" ..
                "対処方法: [続行]または[終了]を押してTeamSpiritを開いてください。",
            textSize = 10,
            textColor = { white = 0.15 },
            textFont = "Menlo",
            frame = { x = dialogX + 16, y = dialogY + 146, w = DIALOG_W - 32, h = dialogH - 190 },
        })

    end

    -------------------------------------------------------------------
    -- 一括反映(非空の配列なので assignElement のエラーにならない)
    -------------------------------------------------------------------

    canvas:replaceElements(elements)

end

-----------------------------------------------------------------------
-- ボタン押下判定
-----------------------------------------------------------------------

local function mouseCallback(_, message, id)

    if message ~= "mouseUp" then
        return
    end

    if id == "btn_continue" or id == "btn_exit" or id == "btn_titlebar_close" then
        -- どのボタンを押してもTeamSpiritを開く(逃げ道を作らない)
        openTeamSpirit()

    elseif id == "detail_toggle" then
        expanded = not expanded
        render()

    end
    -- id == "overlay" のときは何もしない(操作ブロック用)

end

-----------------------------------------------------------------------
-- リマインダー表示
-----------------------------------------------------------------------

local function showReminder()

    local screen = hs.screen.mainScreen()
    local frame = screen:fullFrame()

    -------------------------------------------------------------------
    -- 画面全体を覆う巨大なcanvasを作成
    -- (これにより裏のアプリを操作できなくする)
    -------------------------------------------------------------------

    canvas = hs.canvas.new({
        x = frame.x,
        y = frame.y,
        w = frame.w,
        h = frame.h,
    })

    canvas:mouseCallback(mouseCallback)

    render()

    -------------------------------------------------------------------
    -- 最前面・全スペースに表示し、操作をブロックする
    -------------------------------------------------------------------

    canvas:level(hs.canvas.windowLevels.screenSaver)

    canvas:behavior({
        "canJoinAllSpaces",
        "stationary",
    })

    canvas:show()

end

-----------------------------------------------------------------------
-- 表示すべきかどうかの判定
-----------------------------------------------------------------------

local function shouldShow()

    local saved = readSavedDate()

    if not saved then
        return true
    end

    return saved ~= todayString()

end

-----------------------------------------------------------------------
-- 「必要なら表示する」チェック
--
-- 起動時・日付またぎポーリング・スリープ復帰、いずれもこれを呼ぶ。
-- すでにダイアログが出ている場合は何もしない
-- (二重にcanvasを作らないようにするため)。
-----------------------------------------------------------------------

local function checkAndShow()

    if canvas then
        return
    end

    if shouldShow() then
        showReminder()
    end

end

-----------------------------------------------------------------------
-- 初期化
--
-- 1. 起動時に一度チェック
-- 2. スリープ復帰・画面ロック解除のたびにチェック
--    (スリープしたまま日付が変わり、翌日PCを開けた瞬間に検知する)
-----------------------------------------------------------------------

local function start()

    checkAndShow()

    wakeWatcher = hs.caffeinate.watcher.new(function(event)
        if event == hs.caffeinate.watcher.systemDidWake
            or event == hs.caffeinate.watcher.screensDidWake
            or event == hs.caffeinate.watcher.screensDidUnlock
        then
            checkAndShow()
        end
    end)

    wakeWatcher:start()

end

-----------------------------------------------------------------------

start()

return M