-- JUAN'S HUB | COMPACT v2.4.10
-- 8 BALL DUELS | Key details in Key tab | Delta / Luau
-- Note: engine integration is source-version dependent; verify in a private match.

local P=game:GetService('Players').LocalPlayer
local U=game:GetService('UserInputService')
local R=game:GetService('RunService')
local Core=game:GetService('CoreGui')
local Tween=game:GetService('TweenService')
-- CLIENT-ONLY DEMO KEY LIST. These values are visible in the script and are NOT secure.
-- The four timed keys are tracked only while this script instance is running.
local KEYS={
 ['JUAN-12H-A7K9']={duration=12*60*60,deviceLimit=10},
 ['JUAN-12H-B4M2']={duration=12*60*60},
 ['JUAN-12H-C8P5']={duration=12*60*60},
 ['JUAN-12H-D3R6']={duration=12*60*60},
 ['JUAN-UNLIMITED-X9Q2']={duration=nil},
}
local keySessions={}
-- Separate owner-panel password. Change this before sharing the script.
-- WARNING: client-side credentials are visible in the Lua source and are not secure.
local OWNER_KEY='JUAN-OWNER-7VQ2-K9MX'
local generatedKeys={}
local expireActiveKey -- forward declaration used by the Owner panel
local activeKey,activeExpiry=nil,nil
local function expiredMessage() return 'Key is expired, please purchase or get a new key!' end

-- Local persistence: keeps generated keys, revocations and first-use expiry
-- across script restarts on this device, when the executor supports file APIs.
-- This is NOT a shared server and cannot sync keys across devices.
local Http=game:GetService('HttpService')
local KEY_STORE='JuansHub_KeyStore_v1.json'
local function saveKeyStore()
 if type(writefile)~='function' then return false end
 local payload={generatedKeys=generatedKeys,keySessions=keySessions}
 local ok,data=pcall(function() return Http:JSONEncode(payload) end)
 if not ok then return false end
 return pcall(writefile,KEY_STORE,data)
end
local function loadKeyStore()
 if type(readfile)~='function' then return false end
 local ok,raw=pcall(function()
  if type(isfile)=='function' and not isfile(KEY_STORE) then return nil end
  return readfile(KEY_STORE)
 end)
 if not ok or type(raw)~='string' or raw=='' then return false end
 local decodedOk,data=pcall(function() return Http:JSONDecode(raw) end)
 if not decodedOk or type(data)~='table' then return false end
 if type(data.generatedKeys)=='table' then
  for k,v in pairs(data.generatedKeys) do
   if type(k)=='string' and type(v)=='table' then
    generatedKeys[k]=v
    if not v.revoked then KEYS[k]={duration=v.duration,deviceLimit=v.deviceLimit,generated=true} end
   end
  end
 end
 if type(data.keySessions)=='table' then
  for k,v in pairs(data.keySessions) do
   if type(k)=='string' and type(v)=='table' then keySessions[k]=v end
  end
 end
 return true
end
loadKeyStore()
local URL='https://nokeyscript.com/script/8-ball-script-autoplay/6747/raw/'
local C={bg=Color3.fromRGB(12,15,24),panel=Color3.fromRGB(20,26,39),card=Color3.fromRGB(29,38,55),blue=Color3.fromRGB(45,125,255),green=Color3.fromRGB(40,255,110),white=Color3.new(1,1,1),muted=Color3.fromRGB(145,160,185)}
local S={auto=false,lines=false,pockets=false,lowPerf=false,dark=false,curve=false,ringSize=24,ringColor=C.green,lineThickness=2,targetFPS=60}
local alive,engine=true,nil
local history={}
local function make(k,p,props)
 local o=Instance.new(k);for a,b in pairs(props or {}) do o[a]=b end;o.Parent=p;return o
end
local function round(o,r) make('UICorner',o,{CornerRadius=UDim.new(0,r or 7)}) end
local function label(p,t,pos,size,col,bold)
 return make('TextLabel',p,{Text=t,Position=pos,Size=size,BackgroundTransparency=1,TextColor3=col or C.white,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,TextSize=12,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left})
end
local function button(p,t,pos,size)
 local b=make('TextButton',p,{Text=t,Position=pos,Size=size,BackgroundColor3=C.card,TextColor3=C.white,Font=Enum.Font.GothamBold,TextSize=11,AutoButtonColor=false,BorderSizePixel=0})
 round(b,9)
 local stroke=make('UIStroke',b,{Color=Color3.fromRGB(74,105,160),Transparency=.48,Thickness=1})
 local grad=make('UIGradient',b,{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(42,58,88)),ColorSequenceKeypoint.new(1,Color3.fromRGB(25,34,53))}),Rotation=90})
 b.MouseEnter:Connect(function()
  if b.Parent then
   local target=b:GetAttribute('ToggleButton') and (b:GetAttribute('ToggleOn') and Color3.fromRGB(65,150,255) or Color3.fromRGB(48,83,139)) or Color3.fromRGB(48,83,139)
   Tween:Create(b,TweenInfo.new(.12),{BackgroundColor3=target}):Play();stroke.Transparency=.12
  end
 end)
 b.MouseLeave:Connect(function()
  if b.Parent then
   local target=b:GetAttribute('ToggleButton') and (b:GetAttribute('ToggleOn') and C.blue or C.card) or C.card
   Tween:Create(b,TweenInfo.new(.16),{BackgroundColor3=target}):Play();stroke.Transparency=b:GetAttribute('ToggleOn') and .12 or .48
  end
 end)
 return b
end
local gui=make('ScreenGui',nil,{Name='JuansHub',ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=10001,ZIndexBehavior=Enum.ZIndexBehavior.Global,Enabled=true})
-- Attach to the normal visible PlayerGui first. Some mobile executors return
-- a valid gethui() container that accepts children but does not render them.
local guiParented=false
local function tryGuiParent(parent)
 if not parent then return false end
 local ok=pcall(function()
  gui.Parent=parent
  gui.Enabled=true
 end)
 return ok and gui.Parent==parent
end
local playerGui=nil
pcall(function() playerGui=P:WaitForChild('PlayerGui',8) end)
if playerGui then guiParented=tryGuiParent(playerGui) end
if not guiParented and type(gethui)=='function' then
 local ok,parent=pcall(gethui)
 if ok and parent then guiParented=tryGuiParent(parent) end
end
if not guiParented then guiParented=tryGuiParent(Core) end
if not guiParented then
 warn("JUAN'S HUB: unable to parent ScreenGui to PlayerGui, gethui, or CoreGui.")
 pcall(function()
  game:GetService('StarterGui'):SetCore('SendNotification',{Title="JUAN'S HUB",Text='Could not display the hub UI. Check Delta GUI permissions.',Duration=8})
 end)
 error("JUAN'S HUB could not attach its ScreenGui.")
end
local function window(sz,pos)
 local f=make('Frame',gui,{Size=sz,Position=pos,BackgroundColor3=C.bg});round(f);make('UIStroke',f,{Color=C.blue,Transparency=.35})
 local v=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800,600)
 make('UIScale',f,{Scale=math.clamp(math.min((v.X-24)/440,(v.Y-24)/350),.65,1)});return f
end
-- Access screen
local access=window(UDim2.fromOffset(360,220),UDim2.new(.5,-180,.5,-110));access.Visible=true
label(access,"JUAN'S HUB",UDim2.fromOffset(18,10),UDim2.new(0,220,0,30),C.white,true).TextSize=18
label(access,'8 BALL DUELS  •  COMPACT 2.4.10',UDim2.fromOffset(18,42),UDim2.new(0,240,0,20),C.blue,true)
local accessAccent=make('Frame',access,{Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,4),BackgroundColor3=C.blue,BorderSizePixel=0});round(accessAccent,8)
make('UIGradient',accessAccent,{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(35,105,255)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(0,220,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(125,75,255))})})
local accessTag=label(access,'●  PRIVATE TABLE ACCESS',UDim2.fromOffset(18,64),UDim2.new(1,-36,0,18),C.green,true);accessTag.TextSize=9
local key=make('TextBox',access,{Position=UDim2.fromOffset(18,88),Size=UDim2.new(1,-36,0,38),BackgroundColor3=C.card,Text='',PlaceholderText='Enter your access key...',TextColor3=C.white,PlaceholderColor3=C.muted,Font=Enum.Font.GothamMedium,TextSize=13,ClearTextOnFocus=false});round(key,9)
make('UIStroke',key,{Color=Color3.fromRGB(65,100,155),Transparency=.2,Thickness=1})
local unlock=button(access,'✦  UNLOCK JUAN’S HUB  ✦',UDim2.fromOffset(18,137),UDim2.new(1,-36,0,36));unlock.BackgroundColor3=C.blue;unlock.TextSize=12
make('UIGradient',unlock,{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(35,105,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(0,190,235))})})
make('UIStroke',unlock,{Color=Color3.fromRGB(130,190,255),Transparency=.35,Thickness=1})
local msg=label(access,'Waiting for key  •  Press Enter to continue',UDim2.fromOffset(18,180),UDim2.new(1,-36,0,18),C.muted);msg.TextSize=10
-- Decorative billiard-ball badges
for i,v in ipairs({{txt='8',col=Color3.fromRGB(18,18,24)},{txt='9',col=Color3.fromRGB(245,205,35)},{txt='1',col=Color3.fromRGB(245,205,35)}}) do
 local ball=make('Frame',access,{Size=UDim2.fromOffset(22,22),Position=UDim2.new(1,-(18+i*27),0,12),BackgroundColor3=v.col,BorderSizePixel=0});round(ball,100)
 make('UIStroke',ball,{Color=Color3.fromRGB(230,235,245),Transparency=.35,Thickness=1})
 local number=label(ball,v.txt,UDim2.fromScale(0,0),UDim2.fromScale(1,1),v.txt=='8' and C.white or Color3.fromRGB(30,35,45),true);number.TextXAlignment=Enum.TextXAlignment.Center;number.TextYAlignment=Enum.TextYAlignment.Center;number.TextSize=11
end
-- Loading
local load=window(UDim2.fromOffset(330,150),UDim2.new(.5,-165,.5,-75));load.Visible=false
label(load,"JUAN'S HUB",UDim2.fromOffset(18,10),UDim2.new(1,-36,0,28),C.white,true)
local stage=label(load,'Preparing...',UDim2.fromOffset(18,43),UDim2.new(1,-36,0,22),C.muted)
local track=make('Frame',load,{Position=UDim2.fromOffset(18,76),Size=UDim2.new(1,-36,0,12),BackgroundColor3=C.card});round(track)
local fill=make('Frame',track,{Size=UDim2.new(0,0,1,0),BackgroundColor3=C.blue});round(fill)
local pct=label(load,'0%',UDim2.fromOffset(18,98),UDim2.new(1,-36,0,22))
local function progress(n,t) fill.Size=UDim2.new(n/100,0,1,0);pct.Text=n..'%';stage.Text=t end
-- Main window
local main=window(UDim2.fromOffset(440,350),UDim2.new(.5,-220,.5,-175));main.Visible=false
make('UIGradient',main,{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(16,25,43)),ColorSequenceKeypoint.new(1,Color3.fromRGB(8,12,22))}),Rotation=35})
make('UIStroke',main,{Color=Color3.fromRGB(62,139,255),Transparency=.18,Thickness=1.5})
local head=make('Frame',main,{Size=UDim2.new(1,0,0,48),BackgroundColor3=C.panel,BorderSizePixel=0});round(head)
make('UIGradient',head,{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(31,75,135)),ColorSequenceKeypoint.new(.55,Color3.fromRGB(25,43,72)),ColorSequenceKeypoint.new(1,Color3.fromRGB(67,39,105))}),Rotation=0})
make('Frame',head,{Position=UDim2.new(0,0,1,-2),Size=UDim2.new(1,0,0,2),BackgroundColor3=Color3.fromRGB(65,165,255),BorderSizePixel=0})
label(head,"JUAN'S HUB",UDim2.fromOffset(14,4),UDim2.new(0,175,0,25),C.white,true).TextSize=16
label(head,'8 BALL DUELS | 2.4.10',UDim2.fromOffset(15,27),UDim2.new(0,175,0,16),C.blue,true).TextSize=9
local fpsCounter=label(head,'FPS: 0 / 60',UDim2.new(1,-150,0,14),UDim2.fromOffset(82,20),C.green,true);fpsCounter.TextSize=11
local mini=button(head,'-',UDim2.new(1,-67,0,9),UDim2.fromOffset(27,27));local close=button(head,'X',UDim2.new(1,-35,0,9),UDim2.fromOffset(27,27))
local side=make('Frame',main,{Position=UDim2.fromOffset(9,57),Size=UDim2.new(0,112,1,-66),BackgroundColor3=Color3.fromRGB(17,27,44),BorderSizePixel=0});round(side);make('UIStroke',side,{Color=Color3.fromRGB(55,93,150),Transparency=.55})
local content=make('Frame',main,{Position=UDim2.fromOffset(130,57),Size=UDim2.new(1,-139,1,-66),BackgroundColor3=Color3.fromRGB(17,25,40),ClipsDescendants=true,BorderSizePixel=0});round(content);make('UIStroke',content,{Color=Color3.fromRGB(55,93,150),Transparency=.58})
local pages={}
local function page(n)
 local f=make('ScrollingFrame',content,{Name=n,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()})
 make('UIListLayout',f,{Padding=UDim.new(0,6)});make('UIPadding',f,{PaddingTop=UDim.new(0,9),PaddingLeft=UDim.new(0,9),PaddingRight=UDim.new(0,9)});pages[n]=f;return f
end
local home=page('Home');local gameplay=page('Gameplay');local visuals=page('Visuals');local practice=page('Practice');local settings=page('Settings');local logs=page('Update Logs');local keyPage=page('Key');local ownerPage=page('Owner')
local function heading(p,t)
 local wrap=make('Frame',p,{Size=UDim2.new(1,0,0,32),BackgroundColor3=Color3.fromRGB(27,48,79),BorderSizePixel=0,LayoutOrder=1})
 round(wrap,8)
 make('UIStroke',wrap,{Color=Color3.fromRGB(58,132,255),Transparency=.48,Thickness=1})
 make('UIGradient',wrap,{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(35,83,145)),ColorSequenceKeypoint.new(1,Color3.fromRGB(32,42,69))}),Rotation=0})
 local x=label(wrap,'✦  '..t,UDim2.fromOffset(10,0),UDim2.new(1,-18,1,0),C.white,true);x.TextSize=13
end
local function note(p,t,n)
 local x=label(p,t,UDim2.new(),UDim2.new(1,0,0,27),C.muted);x.LayoutOrder=n
 x.BackgroundTransparency=.78;x.BackgroundColor3=Color3.fromRGB(34,45,65);round(x,6)
 return x
end
local function action(p,t,n,fn) local b=button(p,t,UDim2.new(),UDim2.new(1,0,0,34));b.LayoutOrder=n;b.Activated:Connect(fn);return b end
local function setEngine(k,v) if engine and engine.State then engine.State[k]=v end end
local curveButton,curveAppliedHud
local curveSpin=Vector2.new(0.62,0)
local function applyCurveToCurrent(on)
 local st=engine and engine.State
 local c=st and st.current
 if not c or type(c.Hud)~='table' then return false end
 c.Hud.Spin=on and curveSpin or Vector2.zero
 curveAppliedHud=on and c.Hud or nil
 st.previewKey=nil
 if st.job and st.job.kind=='trace' then st.job=nil end
 return true
end
local function applyTheme(on)
 local bg=on and Color3.fromRGB(12,15,24) or Color3.fromRGB(239,243,250)
 local panel=on and Color3.fromRGB(20,26,39) or Color3.fromRGB(218,226,238)
 local card=on and Color3.fromRGB(29,38,55) or Color3.fromRGB(250,252,255)
 local fg=on and Color3.new(1,1,1) or Color3.fromRGB(25,34,49)
 for _,o in ipairs(gui:GetDescendants()) do
  if o:IsA('Frame') or o:IsA('ScrollingFrame') then
   if o==main or o==access or o==load then o.BackgroundColor3=bg elseif o==side or o==content or o==head then o.BackgroundColor3=panel elseif o:IsA('Frame') and o.BackgroundTransparency<1 then o.BackgroundColor3=card end
  elseif o:IsA('TextLabel') or o:IsA('TextButton') or o:IsA('TextBox') then
   if o~=unlock then o.TextColor3=fg end
  end
 end
end
local function paintToggle(b,on)
 b:SetAttribute('ToggleButton',true)
 b:SetAttribute('ToggleOn',on)
 b.BackgroundColor3=on and C.blue or C.card
 local st=b:FindFirstChildOfClass('UIStroke')
 if st then st.Color=on and Color3.fromRGB(130,190,255) or Color3.fromRGB(74,105,160);st.Transparency=on and .12 or .48 end
end
local function toggle(p,t,n,field)
 local b; b=action(p,t..(S[field] and ' [ON]' or ' [OFF]'),n,function()
  S[field]=not S[field];local on=S[field]
  b.Text=t..(on and ' [ON]' or ' [OFF]');paintToggle(b,on);setEngine(field,on)
  if field=='auto' and on then
   if S.curve then
    S.curve=false
    if curveButton then curveButton.Text='CUE CURVING [OFF]';paintToggle(curveButton,false) end
    applyCurveToCurrent(false)
   end
   if engine and engine.State then engine.State.requestPlan=true end
  end
  if field=='dark' then applyTheme(on) end
 end)
 paintToggle(b,S[field]);return b
end
-- Home
heading(home,'WELCOME BACK');note(home,'Physics-based 8 Ball Duels control center.',2)
local status=label(home,'ENGINE: WAITING',UDim2.new(),UDim2.new(1,0,0,25),C.muted,true);status.LayoutOrder=3
local perf=label(home,'PERFORMANCE: READY',UDim2.new(),UDim2.new(1,0,0,24),C.green,true);perf.LayoutOrder=4
local featureText=label(home,'Autoplay OFF | Trajectory OFF | Pocket ON',UDim2.new(),UDim2.new(1,0,0,35),C.muted);featureText.LayoutOrder=5
-- Gameplay
heading(gameplay,'GAMEPLAY');toggle(gameplay,'AUTOPLAY',2,'auto')
local hist
local function addHistory(t) table.insert(history,1,t);while #history>10 do table.remove(history) end;if hist then hist.Text=table.concat(history,'\n') end end
curveButton=action(gameplay,'CUE CURVING [OFF]',3,function()
 if S.auto then addHistory('Turn Autoplay off to use manual cue curving.');return end
 S.curve=not S.curve
 curveButton.Text='CUE CURVING '..(S.curve and '[ON]' or '[OFF]')
 paintToggle(curveButton,S.curve)
 local applied=applyCurveToCurrent(S.curve)
 addHistory(S.curve and (applied and 'Cue curving enabled: native side spin applied.' or 'Cue curving enabled; waiting for an active table.') or 'Cue curving disabled; spin reset.')
end)
paintToggle(curveButton,false)
action(gameplay,'FIND BEST SHOT',4,function() if engine and engine.Plan then local ok=pcall(engine.Plan);addHistory(ok and 'Shot calculation requested' or 'Shot calculation failed') end end)
note(gameplay,'Cue Curving applies native side spin to manual shots. Autoplay uses its own simulated shot spin.',5)
note(gameplay,'Find Best Shot requests a fresh physics search.',6)
note(gameplay,'Mobile fast planner: fewer candidates, full physics checks, quicker shot animation.',7)
-- Dropdowns
local function dropdown(p,title,opts,default,fn,order)
 local row=make('Frame',p,{Size=UDim2.new(1,0,0,36),BackgroundTransparency=1,LayoutOrder=order,ZIndex=5})
 local l=label(row,title,UDim2.new(),UDim2.new(.42,0,1,0),C.white,true);l.TextSize=10;l.ZIndex=6
 local b=button(row,opts[default].name,UDim2.new(.43,0,0,2),UDim2.new(.57,0,0,32));b.ZIndex=7
 local menu=make('Frame',row,{Position=UDim2.new(.43,0,0,36),Size=UDim2.new(.57,0,0,#opts*29),BackgroundColor3=C.panel,Visible=false,ZIndex=20});round(menu)
 make('UIListLayout',menu,{Padding=UDim.new(0,2)})
 local function choose(i) b.Text=opts[i].name;fn(opts[i].value);menu.Visible=false;row.Size=UDim2.new(1,0,0,36) end
 for i,v in ipairs(opts) do local q=button(menu,v.name,UDim2.new(0,3,0,0),UDim2.new(1,-6,0,27));q.LayoutOrder=i;q.ZIndex=21;q.Activated:Connect(function() choose(i) end) end
 b.Activated:Connect(function() menu.Visible=not menu.Visible;row.Size=UDim2.new(1,0,0,menu.Visible and 36+#opts*29 or 36) end)
 choose(default);return b
end
-- Visuals
heading(visuals,'VISUAL SETTINGS');toggle(visuals,'TRAJECTORY',2,'lines');toggle(visuals,'PREDICTED POCKET',3,'pockets');toggle(visuals,'LOW PERFORMANCE MODE',4,'lowPerf')
local colors={{name='Green',value=Color3.fromRGB(40,255,110)},{name='Cyan',value=Color3.fromRGB(0,210,255)},{name='Purple',value=Color3.fromRGB(180,80,255)},{name='Yellow',value=Color3.fromRGB(255,220,40)},{name='Red',value=Color3.fromRGB(255,55,65)},{name='White',value=C.white}}
local sizes,widths={},{}
for _,v in ipairs({16,20,24,28,32,36,40,44}) do sizes[#sizes+1]={name=v..' px',value=v} end
for _,v in ipairs({1,2,3,4,5}) do widths[#widths+1]={name=v..' px',value=v} end
dropdown(visuals,'PREDICTED POCKET COLOR',colors,1,function(v) S.ringColor=v;setEngine('ringColor',v) end,5)
 dropdown(visuals,'RING SIZE',sizes,3,function(v) S.ringSize=v;setEngine('ringSize',v) end,6)
 dropdown(visuals,'LINE WIDTH',widths,2,function(v) S.lineThickness=v;setEngine('lineThickness',v) end,7)
 note(visuals,'FPS target: 60. The counter shows measured game FPS.',8)
note(visuals,'Mobile-friendly planner tuning is built in; the Low Performance toggle starts OFF.',9)
 note(visuals,'Pocket color changes the highlighted predicted pocket.',10)
 note(visuals,'Solids: solid | Stripes: dotted | 8-ball: black | Cue: white',11)
 note(visuals,'Paths use simulated collisions and cushion rebounds.',12)
-- Practice
heading(practice,'PRACTICE CENTER');note(practice,'Recent shot actions',2)
hist=label(practice,'No shot actions yet.',UDim2.new(),UDim2.new(1,0,0,120),C.muted);hist.LayoutOrder=3;hist.TextYAlignment=Enum.TextYAlignment.Top
action(practice,'CLEAR HISTORY',4,function() table.clear(history);hist.Text='No shot actions yet.' end)
-- Settings
heading(settings,'CUSTOMIZATION');toggle(settings,'DARK THEME',2,'dark')
local scale=1
action(settings,'CHANGE UI SCALE',3,function() scale=scale-.1;if scale<.7 then scale=1 end;for _,f in ipairs({main,access,load}) do local x=f:FindFirstChildOfClass('UIScale');if x then x.Scale=scale end end end)
action(settings,'HIDE HUB',4,function() main.Visible=false end)
local function unload() alive=false;if engine and engine.Unload then pcall(engine.Unload) end;gui:Destroy() end
action(settings,'UNLOAD HUB',5,unload);note(settings,'RightShift toggles the hub.',6)
-- Logs
heading(logs,'IMPORTANT UPDATES')
for i,v in ipairs({
 'v2.4.10: corrected version labels and clarified local-only key storage, owner credential visibility, and device-limit behavior',
  'v2.4.9: added connected-key status, expiration and device-limit details to the Key tab',
 'v2.4.8: prioritize visible PlayerGui parenting on mobile executors',
 'v2.4.7: improved mobile executor GUI parenting and startup visibility',
 'v2.4.6: stabilized autoplay planning and shot recovery; adjusted center-pocket markers',
 'v2.4.4: update log shortened to major milestones only',
 'v2.4.3: all gameplay, visual, and appearance toggles start OFF',
 'v2.4.2: added local saving for generated keys, revocations, and expiry data when executor file APIs are available',
 'v2.4.1: added 60-second local key-status refresh and a unified red expired/revoked-key message',
 'v2.4.0: reorganized Key and Owner tabs; trajectory and predicted-pocket previews clear during shots',
 'v2.3.0: added Owner Panel tools for creating, listing, copying, extending, and revoking demo keys',
 'v2.2.0: added the five-key demo access system',
 'v2.1.0: added the Key tab and refined pocket-marker placement',
 'v2.0.9: restored predicted-pocket detection and target highlighting',
 'v2.0.7: optimized the autoplay shot planner for lower mobile workload',
 'v2.0.6: redesigned the hub interface and improved 3D pocket overlays',
 'v2.0.4: added physics-based ball paths with collisions, cushion rebounds, and pocket prediction',
 'v2.0.0: major hub rebuild with gameplay, visual, practice, and settings sections',
 "v1.0.0: initial JUAN'S HUB release"
}) do note(logs,'✦  '..v,i+1) end
-- KEY TAB: grouped status cards with a clear account/license hierarchy.
heading(keyPage,'ACCESS & KEY DETAILS')
local deviceType=U.TouchEnabled and 'Touch / Mobile' or (U.GamepadEnabled and 'Gamepad' or 'Keyboard / Mouse')
local function keyInfoCard(title,order)
 local card=make('Frame',keyPage,{LayoutOrder=order,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=C.panel,BorderSizePixel=0})
 round(card,9);make('UIStroke',card,{Color=Color3.fromRGB(62,91,135),Transparency=.55})
 make('UIPadding',card,{PaddingTop=UDim.new(0,9),PaddingBottom=UDim.new(0,9),PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)})
 make('UIListLayout',card,{Padding=UDim.new(0,5)})
 local h=label(card,title,UDim2.new(),UDim2.new(1,0,0,18),C.blue,true);h.TextSize=10
 return card
end
local accountCard=keyInfoCard('ACCOUNT & DEVICE',2)
local userInfo=label(accountCard,'ROBLOX USERNAME   '..P.Name,UDim2.new(),UDim2.new(1,0,0,23),C.white,true);userInfo.TextSize=11
local deviceInfo=label(accountCard,'DEVICE CATEGORY   '..deviceType,UDim2.new(),UDim2.new(1,0,0,23),C.muted,true);deviceInfo.TextSize=10
local licenseCard=keyInfoCard('CONNECTED KEY DETAILS',3)
local keyStatusInfo=label(licenseCard,'STATUS   Not connected',UDim2.new(),UDim2.new(1,0,0,22),C.muted,true);keyStatusInfo.TextSize=11
local usedInfo=label(licenseCard,'KEY   Not unlocked',UDim2.new(),UDim2.new(1,0,0,24),C.white,true);usedInfo.TextSize=11
local deviceUsageInfo=label(licenseCard,'DEVICE USAGE   Not connected',UDim2.new(),UDim2.new(1,0,0,24),C.white,true);deviceUsageInfo.TextSize=11
local expiryInfo=label(licenseCard,'EXPIRATION   Not connected',UDim2.new(),UDim2.new(1,0,0,58),C.green,true);expiryInfo.TextSize=11;expiryInfo.TextYAlignment=Enum.TextYAlignment.Top
local keyNote=note(keyPage,'KEY POLICY  •  Key 1 is configured with a 10-device limit (display only in this client build). Key 5 has unlimited expiration and no configured device limit.',4)
keyNote.Size=UDim2.new(1,0,0,38);keyNote.TextSize=10
local securityNote=note(keyPage,'DEVICE COUNT NOTE  •  This build can show the configured limit and this installation. A true shared count across different devices requires an online key server; it is not connected in this build.',5)
securityNote.Size=UDim2.new(1,0,0,66);securityNote.TextSize=10

-- OWNER PANEL: separated into focused cards for creation, management and inventory.
heading(ownerPage,'OWNER CONSOLE • PRIVATE')
local ownerStatus=note(ownerPage,'STATUS  •  Locked — owner authentication required.',2)
ownerStatus.Size=UDim2.new(1,0,0,34)
local ownerPassword=make('TextBox',ownerPage,{LayoutOrder=3,Size=UDim2.new(1,0,0,36),BackgroundColor3=C.card,Text='',PlaceholderText='Enter owner access key',TextColor3=C.white,PlaceholderColor3=C.muted,Font=Enum.Font.GothamMedium,TextSize=12,ClearTextOnFocus=false})
round(ownerPassword,8);make('UIStroke',ownerPassword,{Color=Color3.fromRGB(65,100,155),Transparency=.25})
local ownerLogin=button(ownerPage,'UNLOCK OWNER CONSOLE',UDim2.new(),UDim2.new(1,0,0,36));ownerLogin.LayoutOrder=4;ownerLogin.BackgroundColor3=C.blue
local ownerTools=make('Frame',ownerPage,{LayoutOrder=5,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Visible=false})
make('UIListLayout',ownerTools,{Padding=UDim.new(0,8)})
local ownerParent=ownerTools
local function ownerSection(title)
 local card=make('Frame',ownerTools,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=C.panel,BorderSizePixel=0})
 round(card,9);make('UIStroke',card,{Color=Color3.fromRGB(62,91,135),Transparency=.55})
 make('UIPadding',card,{PaddingTop=UDim.new(0,9),PaddingBottom=UDim.new(0,9),PaddingLeft=UDim.new(0,9),PaddingRight=UDim.new(0,9)})
 make('UIListLayout',card,{Padding=UDim.new(0,6)})
 local h=label(card,title,UDim2.new(),UDim2.new(1,0,0,19),C.blue,true);h.TextSize=10
 return card
end
local function ownerLabel(text,height,color)
 local x=label(ownerParent,text,UDim2.new(),UDim2.new(1,0,0,height or 22),color or C.muted,true)
 x.TextSize=10;x.TextYAlignment=Enum.TextYAlignment.Center;return x
end
local function ownerBox(placeholder,default)
 local x=make('TextBox',ownerParent,{Size=UDim2.new(1,0,0,34),BackgroundColor3=C.card,Text=default or '',PlaceholderText=placeholder,TextColor3=C.white,PlaceholderColor3=C.muted,Font=Enum.Font.GothamMedium,TextSize=11,ClearTextOnFocus=false})
 round(x,7);make('UIStroke',x,{Color=Color3.fromRGB(65,100,155),Transparency=.45});return x
end
ownerParent=ownerSection('01  /  CREATE ACCESS KEY')
ownerLabel('Set the lifetime and allowed device count. Use 0 for unlimited.',30)
local durationBox=ownerBox('Expiration in hours','12')
local deviceBox=ownerBox('Maximum devices','1')
local createOwnerKey=button(ownerParent,'＋  GENERATE NEW KEY',UDim2.new(),UDim2.new(1,0,0,36));createOwnerKey.BackgroundColor3=C.blue
local generatedOutput=ownerLabel('Your new key will appear here.',42,C.green);generatedOutput.TextWrapped=true;generatedOutput.TextYAlignment=Enum.TextYAlignment.Top
local copyGenerated=button(ownerParent,'COPY GENERATED KEY',UDim2.new(),UDim2.new(1,0,0,32))
ownerParent=ownerSection('02  /  MANAGE EXISTING KEY')
ownerLabel('Enter a generated key, then choose an action.',24)
local manageKeyBox=ownerBox('Key to manage','')
local extendBox=ownerBox('Hours to add when extending','12')
local revokeButton=button(ownerParent,'REVOKE KEY',UDim2.new(),UDim2.new(1,0,0,32))
local extendButton=button(ownerParent,'EXTEND EXPIRATION',UDim2.new(),UDim2.new(1,0,0,32))
ownerParent=ownerSection('03  /  KEY INVENTORY')
local listButton=button(ownerParent,'REFRESH KEY INVENTORY',UDim2.new(),UDim2.new(1,0,0,32))
local keyList=ownerLabel('No generated keys yet.',110)
keyList.TextYAlignment=Enum.TextYAlignment.Top;keyList.TextWrapped=true
ownerParent=ownerSection('04  /  SECURITY NOTICE')
local ownerWarning=ownerLabel('LOCAL-ONLY DEMO  •  Keys and expiry may persist on this device if file APIs are supported. The owner password and keys are visible in this client script; this is not secure server authentication. Cross-device sync and device-limit enforcement require a server.',48,Color3.fromRGB(255,190,90))
ownerWarning.TextWrapped=true;ownerWarning.TextYAlignment=Enum.TextYAlignment.Top
local lastGenerated=''
local ownerUnlocked=false
ownerLogin.Activated:Connect(function()
 if ownerPassword.Text==OWNER_KEY then
  ownerUnlocked=true;ownerPassword.Visible=false;ownerLogin.Visible=false;ownerTools.Visible=true
  ownerStatus.Text='Owner access granted.';ownerStatus.TextColor3=C.green
 else
  ownerStatus.Text='Incorrect owner key.';ownerStatus.TextColor3=Color3.fromRGB(255,65,65)
 end
end)
local function makeGeneratedKey()
 local chars='ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
 local function part(n)
  local t={};for i=1,n do local k=math.random(1,#chars);t[i]=chars:sub(k,k) end;return table.concat(t)
 end
 return 'JUAN-CUSTOM-'..part(4)..'-'..part(4)
end
local function refreshOwnerList()
 local lines={}
 for k,v in pairs(generatedKeys) do
  local rec=keySessions[k]
  local state=v.revoked and 'REVOKED' or (rec and rec.expiry and os.time()>=rec.expiry and 'EXPIRED' or 'ACTIVE/UNUSED')
  local duration=v.duration and (tostring(v.duration/3600)..'h') or 'Unlimited'
  local devices=v.deviceLimit and tostring(v.deviceLimit) or 'Unlimited'
  table.insert(lines,k..' | '..state..' | '..duration..' | '..devices..' devices')
 end
 table.sort(lines)
 keyList.Text=#lines>0 and table.concat(lines,'\n') or 'No generated keys yet.'
end
createOwnerKey.Activated:Connect(function()
 if not ownerUnlocked then return end
 local hours=tonumber(durationBox.Text);local devices=tonumber(deviceBox.Text)
 if not hours or not devices or hours<0 or devices<0 or hours%1~=0 or devices%1~=0 then
  generatedOutput.Text='Use whole numbers 0 or greater.';generatedOutput.TextColor3=Color3.fromRGB(255,65,65);return
 end
 local k;repeat k=makeGeneratedKey() until not KEYS[k]
 local duration=nil;if hours>0 then duration=hours*3600 end
 local deviceLimit=nil;if devices>0 then deviceLimit=devices end
 KEYS[k]={duration=duration,deviceLimit=deviceLimit,generated=true}
 generatedKeys[k]={duration=duration,deviceLimit=deviceLimit,revoked=false}
 lastGenerated=k
 generatedOutput.Text='CREATED: '..k..'\nExpiration: '..(hours==0 and 'Unlimited' or (hours..' hours after first use'))..' | Devices: '..(devices==0 and 'Unlimited' or tostring(devices))
 generatedOutput.TextColor3=C.green;saveKeyStore();refreshOwnerList()
end)
copyGenerated.Activated:Connect(function()
 if lastGenerated~='' then
  local copied=false;pcall(function() if setclipboard then setclipboard(lastGenerated);copied=true end end)
  generatedOutput.Text=copied and ('Copied: '..lastGenerated) or ('Last key: '..lastGenerated..' (clipboard unavailable)')
 end
end)
revokeButton.Activated:Connect(function()
 local k=manageKeyBox.Text:gsub('%s','')
 if generatedKeys[k] then generatedKeys[k].revoked=true;KEYS[k]=nil;keySessions[k]=nil
  if activeKey==k then expireActiveKey(k) end
  saveKeyStore();generatedOutput.Text='Key revoked: '..k;generatedOutput.TextColor3=Color3.fromRGB(255,100,100);refreshOwnerList()
 else generatedOutput.Text='That is not a generated key.';generatedOutput.TextColor3=Color3.fromRGB(255,65,65) end
end)
extendButton.Activated:Connect(function()
 local k=manageKeyBox.Text:gsub('%s','');local hrs=tonumber(extendBox.Text)
 if not generatedKeys[k] or generatedKeys[k].revoked or not hrs or hrs<=0 or hrs%1~=0 then
  generatedOutput.Text='Enter an active generated key and positive whole hours.';generatedOutput.TextColor3=Color3.fromRGB(255,65,65);return
 end
 local rec=keySessions[k]
 if rec and rec.expiry then rec.expiry=math.max(os.time(),rec.expiry)+hrs*3600
 elseif not rec and generatedKeys[k].duration then generatedKeys[k].duration=generatedKeys[k].duration+hrs*3600;KEYS[k].duration=generatedKeys[k].duration
 elseif not rec then generatedOutput.Text='Unlimited keys do not need extending.';return end
 saveKeyStore();generatedOutput.Text='Extended '..k..' by '..hrs..' hours.';generatedOutput.TextColor3=C.green;refreshOwnerList()
end)
listButton.Activated:Connect(refreshOwnerList)
-- Navigation
local navButtons={}
local activeTab='Home'
local function selectTab(n)
 activeTab=n
 for name,b in pairs(navButtons) do
  local selected=name==n
  b.BackgroundColor3=selected and Color3.fromRGB(38,104,190) or C.card
  b.TextColor3=selected and C.white or C.muted
  local st=b:FindFirstChildOfClass('UIStroke');if st then st.Transparency=selected and .05 or .48;st.Color=selected and Color3.fromRGB(115,190,255) or Color3.fromRGB(74,105,160) end
  local g=b:FindFirstChildOfClass('UIGradient');if g then g.Enabled=not selected end
  pages[name].Visible=selected
 end
end
for i,n in ipairs({'Home','Gameplay','Visuals','Practice','Settings','Update Logs','Key','Owner'}) do
 local b=button(side,n,UDim2.fromOffset(6,6+(i-1)*34),UDim2.new(1,-12,0,30));b.TextSize=9
 navButtons[n]=b
 b.Activated:Connect(function() selectTab(n) end)
end
selectTab('Home')
-- Minimize / close
local minimized=false
mini.Activated:Connect(function() minimized=not minimized;side.Visible=not minimized;content.Visible=not minimized;main.Size=minimized and UDim2.fromOffset(440,48) or UDim2.fromOffset(440,350);mini.Text=minimized and '+' or '-' end)
close.Activated:Connect(unload)
-- Dragging
local dragging,dragStart,startPos=false
head.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true;dragStart=i.Position;startPos=main.Position end end)
U.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then local d=i.Position-dragStart;main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)
U.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
U.InputBegan:Connect(function(i,processed) if not processed and i.KeyCode==Enum.KeyCode.RightShift and not access.Visible and not load.Visible then main.Visible=not main.Visible end end)
-- Engine source patch helpers
local function replaceOnce(src,old,new)
 local a,b=src:find(old,1,true);assert(a,'Engine patch target missing: '..old:sub(1,90));return src:sub(1,a-1)..new..src:sub(b+1)
end
local function replaceBetween(src,startText,endText,replacement)
 local a=assert(src:find(startText,1,true),'Missing start marker: '..startText)
 local b=assert(src:find(endText,a+1,true),'Missing end marker: '..endText)
 return src:sub(1,a-1)..replacement..src:sub(b)
end
local function patch(src)
 -- Mobile-friendly planner tuning: fewer candidates, same full-physics evaluation.
 src=replaceOnce(src,'calcSpeed=0.03734','calcSpeed=0.006')
 src=replaceOnce(src,"key=nil,previewKey=nil,failedKey=nil,lastShot=nil,requestPlan=false,showBest=false,scan=0,drawAge=0,uiAge=0,","key=nil,previewKey=nil,failedKey=nil,failedAt=nil,lastShot=nil,lastShotAt=nil,requestPlan=false,showBest=false,scan=0,drawAge=0,uiAge=0,")
 src=replaceOnce(src,'for i=1, math.min(350,#proposals) do','for i=1, math.min(180,#proposals) do')
 src=replaceOnce(src,'if i <= 30 then','if i <= 16 then')
 src=replaceOnce(src,'-- Power Bracketing: For the top 30 direct shots, test at multiple fixed powers to avoid pocket rattle','-- Power bracketing is limited to the top 16 direct shots.')
 src=replaceOnce(src,'for _,power in ipairs({0.25, 0.5, 0.75, 1.0}) do add(p,power) end','for _,power in ipairs({0.35, 0.7, 1.0}) do add(p,power) end')
 src=replaceOnce(src,'for _,spin in ipairs({Vector2.new(0,.4),Vector2.new(0,-.4)}) do add(p,p.power,0,spin) end','-- Spin variations are skipped in the fast first-pass planner.')
 src=replaceOnce(src,'return candidates\n    end\n    function self:simulate','if #candidates>300 then for i=#candidates,301,-1 do candidates[i]=nil end end\n        return candidates\n    end\n    function self:simulate')
 -- Keep the engine's original aim/charge timings so cue animation and shot input have time to register.
 src=replaceOnce(src,'local connections={}',[[state.pockets=false;state.lowPerf=false;state.ringSize=28;state.ringColor=Color3.fromRGB(40,255,110);state.lineThickness=2;state.targetFPS=60
local connections={}]])
 src=replaceOnce(src,"(not best.result.Winner or best.result.Winner==c.Seat)","(not best.result.Winner or best.result.Winner==c.Seat) and (not best.shot.placement or (c.Input.CanPlaceCueBall and planner:validPlacement(c.Simulation,c.Rules,best.shot.placement)))")
 src=replaceOnce(src,'state.lastShot=best.key','state.lastShot=best.key;state.lastShotAt=os.clock()')
 local panel="local panel=make('Frame',gui,{Size=UDim2.fromOffset(300,130),Position=UDim2.new(0,18,.5,-65),BackgroundColor3=Color3.fromRGB(16,18,25),BorderSizePixel=0,Active=true,ZIndex=10})"
 src=replaceOnce(src,panel,panel..'\npanel.Visible=false')
 src=replaceOnce(src,'if state.lines and not state.job then','if (state.lines or state.pockets) and not state.job then')
 src=replaceOnce(src,'state.drawAge+=dt;if state.drawAge<1/30 then return end;state.drawAge=0',"state.drawAge+=dt;if state.drawAge<1/60 then return end;state.drawAge=state.drawAge%(1/60);state.hubFrameCount=(state.hubFrameCount or 0)+1")
 -- Keep the original cooperative yield cadence during physics simulation.
 src=replaceOnce(src,"job.sliceEnd=os.clock()+(job.kind=='search' and state.calcSpeed or 0.004)","job.sliceEnd=os.clock()+(job.kind=='search' and state.calcSpeed or 0.006)")
 src=replaceOnce(src,'if key~=state.key then clearWork();state.key=key;state.lastShot=nil;state.failedKey=nil end','if key~=state.key then clearWork();state.key=key;state.lastShot=nil;state.lastShotAt=nil;state.failedKey=nil;state.failedAt=nil end\n    if state.lastShot==key and state.lastShotAt and os.clock()-state.lastShotAt>10 then state.lastShot=nil;state.lastShotAt=nil;state.best=nil;state.failedKey=nil;state.requestPlan=true end\n    if state.failedKey==key and state.failedAt and os.clock()-state.failedAt>5 then state.failedKey=nil;state.failedAt=nil;state.requestPlan=true end')
 src=replaceOnce(src,"state.failedKey = key\n                    status.Text='No safe shot found. Waiting...'","state.failedKey = key;state.failedAt=os.clock()\n                    status.Text='No safe shot found. Retrying shortly...'")
 local renderer=[[
local lastPaths,lastPathResult,lastTargetId=nil,nil,nil
local function cachePaths(paths)
 if type(paths)~='table' then return nil end
 local copy={}
 for id,path in pairs(paths) do
  if type(path)=='table' then local points={} for i,point in ipairs(path) do points[i]=point end;copy[id]=points end
 end
 return copy
end
local function hidePocketRings()
 for _,marker in ipairs(pocketRings) do marker.ring.Visible=false;if marker.tag then marker.tag.Visible=false end end
end
local function pocketKey(pocket,index)
 return pocket.Id or pocket.Number or pocket.Index or index
end
local function getPredictedPocket(pockets)
 local preview=state.pathResult
 if not preview or preview.key~=state.key then return nil end
 local outcome=preview.result
 if type(outcome)~='table' or outcome.WrongPocket==true then return nil end
 local potted=outcome.Potted
 if type(potted)~='table' then return nil end
 local sim=preview.sim
 if not sim then return nil end
 local cueId=Physics.CueNumber(sim)
 local cue=sim.Balls[cueId]
 if cue and cue.Pocketed then return nil end
 local ballRadius=(C and C.BallRadius) or .2
 local bestId,bestDistance=nil,math.huge
 for _,ballId in pairs(potted) do
  if tostring(ballId)~=tostring(cueId) then
   local path=preview.paths and preview.paths[ballId]
   local ball=sim.Balls[ballId]
   local endpoint=(path and path[#path]) or (ball and ball.Position)
   if endpoint then
    for index,pocket in pairs(pockets) do
     local centre=pocket.BowlCentre or pocket.MouthCentre
     if centre then
      local distance=(endpoint-centre).Magnitude
      if distance<bestDistance then
       bestDistance=distance
       bestId=pocket.Id or pocket.Number or pocket.Index or index
      end
     end
    end
   end
  end
 end
 -- Only show a target when a simulated object-ball pot finishes close to a pocket.
 if bestId~=nil and bestDistance<=ballRadius*8 then return bestId end
 return nil
end
local function projectPocket(c,point)
 if c.View.Mode=='2D' then
  local origin,size=Renderer.GetScreenRect(c.View.Renderer2D)
  local scale=Renderer.TableToScale(point)
  if size.X<=0 or size.Y<=0 then return Vector2.zero,false end
  return origin+Vector2.new(scale.X.Scale*size.X,scale.Y.Scale*size.Y),true
 end
 local camera=workspace.CurrentCamera
 if not camera then return Vector2.zero,false end
 -- Pocket rings sit on the table surface; ball paths are projected at ball height.
 local projected,on=camera:WorldToViewportPoint(View.ToWorld(point,0))
 local pos=Vector2.new(projected.X,projected.Y)
 local viewport=camera.ViewportSize
 local inside=on and projected.Z>0 and pos.X>=0 and pos.Y>=0 and pos.X<=viewport.X and pos.Y<=viewport.Y
 return pos,inside
end
local function draw()
 local c=state.current
 if not c or type(c.Simulation)~='table' then hideLines();hidePocketRings();return end
 local isReady=ready(c)
 local result=state.pathResult
 local pathsReady=isReady and result and result.key==state.key
 if pathsReady then lastPaths=cachePaths(state.paths);lastPathResult=result end
 -- A live shot temporarily removes readiness. Clear the old preview and target so
 -- they cannot linger after the cue stick returns for the next aim.
 if not isReady then lastPaths=nil;lastPathResult=nil;lastTargetId=nil end
 local displayPaths=pathsReady and state.paths or (isReady and lastPaths or nil)
 local displayResult=pathsReady and result or (isReady and lastPathResult or nil)
 local n=0
 local maxSeg=state.lowPerf and 180 or 360
 if state.lines and displayPaths and displayResult then
  local cueId=Physics.CueNumber(c.Simulation)
  local palette={[1]=Color3.fromRGB(255,220,35),[2]=Color3.fromRGB(45,105,255),[3]=Color3.fromRGB(235,45,55),[4]=Color3.fromRGB(145,65,210),[5]=Color3.fromRGB(245,135,35),[6]=Color3.fromRGB(35,170,85),[7]=Color3.fromRGB(125,45,55)}
  local function ballColor(id)
   if id==cueId then return Color3.new(1,1,1),false end
   local ball=displayResult.sim and displayResult.sim.Balls and displayResult.sim.Balls[id]
   local number=ball and tonumber(ball.Number or id)
   if number==8 then return Color3.new(0,0,0),false end
   if number and number>=9 and number<=15 then return palette[number-8] or Color3.new(1,1,1),true end
   return palette[number] or Color3.new(1,1,1),false
  end
  local function segment(a,b,color)
   local delta=b-a;local length=delta.Magnitude
   if length<1 then return end
   local line=lineObjects[n+1]
   if not line then
    line=make('Frame',gui,{BorderSizePixel=0,AnchorPoint=Vector2.new(.5,.5),ZIndex=2,BackgroundTransparency=.08})
    lineObjects[n+1]=line
   end
   n+=1
   line.Size=UDim2.fromOffset(length,math.clamp(tonumber(state.lineThickness) or 2,1,5))
   line.Position=UDim2.fromOffset((a.X+b.X)*.5,(a.Y+b.Y)*.5)
   line.Rotation=math.deg(math.atan2(delta.Y,delta.X))
   line.BackgroundColor3=color;line.Visible=true
  end
  for id,path in pairs(displayPaths) do
   local color,dotted=ballColor(id)
   for i=2,#path do
    if n>=maxSeg then break end
    local a,visibleA=project(c,path[i-1])
    local b,visibleB=project(c,path[i])
    if visibleA and visibleB then
     if dotted then
      local delta=b-a;local length=delta.Magnitude
      local direction=length>0 and delta.Unit or Vector2.zero
      local at=0
      while at<length and n<maxSeg do
       local finish=math.min(at+8,length)
       if finish>at then segment(a+direction*at,a+direction*finish,color) end
       at+=13
      end
     else
      segment(a,b,color)
     end
    end
   end
   if n>=maxSeg then break end
  end
 else
  hideLines()
 end
 for i=n+1,#lineObjects do lineObjects[i].Visible=false end

 -- Draw all six pocket markers independently of trajectory readiness.
 -- The selected pocket gets a bright colored ring and a TARGET tag.
 if state.pockets then
  local ok,pockets=pcall(function() return Geometry.GetPockets(Physics.GetTable(c.Simulation)) end)
  if not ok or type(pockets)~='table' then hidePocketRings()
  else
   if pathsReady then lastTargetId=getPredictedPocket(pockets) end
   local targetId=lastTargetId
   local tableMid=projectPocket(c,Vector2.zero)
   local markerIndex=0
   for pocketIndex,pocket in pairs(pockets) do
    markerIndex+=1
    local i=markerIndex
    local centre=pocket.BowlCentre or pocket.MouthCentre
    local marker=pocketRings[i]
    if not marker then
     local ring=make('Frame',gui,{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),ZIndex=50,BorderSizePixel=0})
     make('UICorner',ring,{CornerRadius=UDim.new(1,0)})
     make('UIStroke',ring,{Thickness=1.5,Color=Color3.fromRGB(180,195,220),Transparency=.12})
     local tag=make('TextLabel',gui,{BackgroundColor3=Color3.fromRGB(15,20,32),BackgroundTransparency=.05,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,1),Size=UDim2.fromOffset(58,16),Text='TARGET',TextColor3=C.white,TextSize=9,Font=Enum.Font.GothamBold,ZIndex=51,Visible=false})
     make('UICorner',tag,{CornerRadius=UDim.new(0,5)})
     marker={ring=ring,tag=tag};pocketRings[i]=marker
    end
    if centre then
     local screen,visible=projectPocket(c,centre)
     -- Nudge only the two center pockets; side pockets stay untouched.
     if tableMid and math.abs(screen.X-tableMid.X)<=14 then
      -- Move the top-middle marker down 10 px and the bottom-middle marker up 10 px.
      screen=screen+Vector2.new(0,screen.Y<tableMid.Y and 10 or -10)
     end
     local id=pocketKey(pocket,pocketIndex)
     local selected=targetId~=nil and tostring(id)==tostring(targetId)
     local ring=marker.ring
     local stroke=ring:FindFirstChildOfClass('UIStroke')
     local diameter=math.clamp(tonumber(state.ringSize) or 24,16,44)
     ring.Size=UDim2.fromOffset(selected and diameter+8 or diameter,selected and diameter+8 or diameter)
     ring.Position=UDim2.fromOffset(screen.X,screen.Y)
     ring.BackgroundTransparency=selected and .82 or 1
     ring.BackgroundColor3=state.ringColor or C.green
     if stroke then
      stroke.Color=selected and (state.ringColor or C.green) or Color3.fromRGB(180,195,220)
      stroke.Thickness=selected and 3.5 or 1.5
      stroke.Transparency=selected and 0 or .12
     end
     ring.Visible=visible
     marker.tag.Position=UDim2.fromOffset(screen.X,screen.Y-diameter*.5-5)
     marker.tag.Visible=visible and selected
     marker.tag.BackgroundColor3=state.ringColor or C.green
     marker.tag.TextColor3=Color3.fromRGB(10,16,25)
    else
     marker.ring.Visible=false;marker.tag.Visible=false
    end
   end
   for i=markerIndex+1,#pocketRings do pocketRings[i].ring.Visible=false;if pocketRings[i].tag then pocketRings[i].tag.Visible=false end end
  end
 else
  hidePocketRings()
 end
end
]]
 src=replaceOnce(src,'local function draw()', 'local pocketRings={}\nlocal function draw()')
 src=replaceBetween(src,'local function draw()','local function tick(dt)',renderer)
 return src
end
-- Start engine
local function start()
 progress(10,'Downloading engine...')
 local ok,src=pcall(function() return game:HttpGet(URL) end)
 if not ok or type(src)~='string' then error('Engine download failed') end
 progress(35,'Applying upgraded renderer and new hub theme...');src=patch(src)
 local run,e=loadstring(src);if not run then error(e or 'Engine compile failed') end
 progress(70,'Starting physics engine...');local result=run()
 if type(result)~='table' or not result.State then error('Engine did not return state') end
 engine=result
 for k,v in pairs(S) do engine.State[k]=v end
 engine.State.targetFPS=60
 progress(100,'Hub ready!');task.wait(.4)
 if alive then load.Visible=false;main.Visible=true;status.Text='ENGINE: LOADED';status.TextColor3=C.green;perf.Text='PERFORMANCE: 60 FPS TARGET';perf.TextColor3=C.green end
end
expireActiveKey=function(which)
 if not alive or activeKey~=which then return end
 S.auto=false;S.lines=false;S.pockets=false
 setEngine('auto',false);setEngine('lines',false);setEngine('pockets',false)
 if engine and engine.Unload then pcall(engine.Unload) end;engine=nil
 main.Visible=false;load.Visible=false;access.Visible=true
 msg.Text=expiredMessage();msg.TextColor3=Color3.fromRGB(255,65,65)
 key.Text='';activeKey=nil;activeExpiry=nil
end
local function refreshKeyStatus()
 if not activeKey then
  keyStatusInfo.Text='STATUS   Not connected'
  keyStatusInfo.TextColor3=C.muted
  usedInfo.Text='KEY   Not unlocked'
  deviceUsageInfo.Text='DEVICE USAGE   Not connected'
  expiryInfo.Text='EXPIRATION   Not connected'
  return
 end
 local info=KEYS[activeKey] or generatedKeys[activeKey] or {}
 keyStatusInfo.Text='STATUS   CONNECTED'
 keyStatusInfo.TextColor3=C.green
 usedInfo.Text='KEY   '..activeKey
 local limit=info.deviceLimit
 if activeKey=='JUAN-UNLIMITED-X9Q2' then
  deviceUsageInfo.Text='DEVICE USAGE   Unlimited'
 elseif limit then
  deviceUsageInfo.Text='DEVICE LIMIT   1 / '..tostring(limit)..' (this installation only)'
 else
  deviceUsageInfo.Text='DEVICE LIMIT   Not configured'
 end
 if activeExpiry then
  local left=math.max(0,activeExpiry-os.time())
  expiryInfo.Text='EXPIRES   '..os.date('%m/%d/%Y %I:%M:%S %p',activeExpiry)..string.format('\nTIME LEFT   %02d:%02d:%02d',math.floor(left/3600),math.floor((left%3600)/60),left%60)
 else
  expiryInfo.Text='EXPIRES   No expiration (Unlimited)'
 end
end
unlock.Activated:Connect(function()
 local entered=key.Text:gsub('%s','')
 local info=KEYS[entered]
 if generatedKeys[entered] and generatedKeys[entered].revoked then msg.Text=expiredMessage();msg.TextColor3=Color3.fromRGB(255,65,65);return end
 if not info then msg.Text='Incorrect key.';msg.TextColor3=Color3.fromRGB(255,65,65);return end
 local session=keySessions[entered]
 if session and session.expiry and os.time()>=session.expiry then
  msg.Text=expiredMessage();msg.TextColor3=Color3.fromRGB(255,65,65);return
 end
 if not session then
  session={started=os.time()}
  if info.duration then session.expiry=session.started+info.duration end
  keySessions[entered]=session
  saveKeyStore()
 end
 activeKey=entered;activeExpiry=session.expiry
 refreshKeyStatus()
 msg.Text='Key accepted.';msg.TextColor3=C.green
 refreshKeyStatus()
 access.Visible=false;load.Visible=true
 task.spawn(function()
  if activeExpiry then
   while alive and activeKey==entered and os.time()<activeExpiry do refreshKeyStatus();task.wait(1) end
   if alive and activeKey==entered and os.time()>=activeExpiry then expireActiveKey(entered);return end
  end
 end)
 task.spawn(function() local ok,e=pcall(start);if not ok and alive then stage.Text='Error: '..tostring(e):sub(1,130);status.Text='ENGINE: FAILED';task.wait(1.5);if alive then load.Visible=false;access.Visible=true end end end)
end)
key.FocusLost:Connect(function(enter) if enter then unlock:Activate() end end)
-- Refresh local license display and owner inventory every 60 seconds. This does not
-- synchronize keys across script restarts/devices; that requires a shared server.
task.spawn(function()
 while alive do
  task.wait(60)
  if not alive then break end
  refreshKeyStatus()
  if ownerUnlocked then refreshOwnerList() end
 end
end)
-- Single measured FPS counter; renderer targets 60 FPS without changing Roblox's FPS cap.
local gameFrames,elapsed=0,0
R.RenderStepped:Connect(function(dt)
 if not alive then return end;gameFrames+=1;elapsed+=dt
 if elapsed>=.5 then
  local gameFPS=math.floor(gameFrames/elapsed)
  fpsCounter.Text='FPS: '..gameFPS..' / 60'
  gameFrames=0;elapsed=0
 end
  if S.curve and not S.auto and engine and engine.State then
   local current=engine.State.current
   if current and current.Hud then
    local spin=current.Hud.Spin
    if curveAppliedHud~=current.Hud or typeof(spin)~='Vector2' or (spin-curveSpin).Magnitude>.001 then applyCurveToCurrent(true) end
   end
  end
 featureText.Text='Autoplay '..(S.auto and 'ON' or 'OFF')..' | Trajectory '..(S.lines and 'ON' or 'OFF')..' | Pocket '..(S.pockets and 'ON' or 'OFF')
end)
