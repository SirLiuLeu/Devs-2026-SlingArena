--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage"); local MockData=require(ReplicatedStorage.Client.Services.MockData)
local S={}; S.__index=S
local function dc(v:any):any if type(v)~="table" then return v end local c={} for k,x in pairs(v) do c[dc(k)]=dc(x) end return c end
function S.new() local self=setmetatable({},S); self._changed=Instance.new("BindableEvent"); self._snapshot={Rows={}}; return self end
function S:Destroy() self._changed:Destroy() end
function S:GetSnapshot() return dc(self._snapshot) end
function S:BindChanged(cb) return self._changed.Event:Connect(cb) end
function S:_emitChanged() self._changed:Fire(self:GetSnapshot()) end
function S:SetFromState(payload:any) local rows=if type(payload)=="table" and type(payload.Rows)=="table" then payload.Rows elseif type(payload)=="table" then payload else {}; self._snapshot={Rows=dc(rows)}; self:_emitChanged() end
function S:LoadMockData() if type(MockData.GetMatchScoreboardState)=="function" then self:SetFromState(MockData.GetMatchScoreboardState()) end end
local d=nil; function S.GetDefault() if not d then d=S.new() end return d end
return S
