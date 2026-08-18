--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DeepCopy = require(ReplicatedStorage.Shared.Utils.DeepCopy)
local S={}; S.__index=S
function S.new() local self=setmetatable({},S); self._changed=Instance.new("BindableEvent"); self._snapshot={Rows={},Visible=false}; return self end
function S:Destroy() self._changed:Destroy() end
function S:GetSnapshot() return DeepCopy.Copy(self._snapshot) end
function S:BindChanged(cb) return self._changed.Event:Connect(cb) end
function S:_emitChanged() self._changed:Fire(self:GetSnapshot()) end
function S:SetFromState(payload:any) local rows=if type(payload)=="table" and type(payload.Rows)=="table" then payload.Rows else {}; self._snapshot={Rows=DeepCopy.Copy(rows),Visible=true}; self:_emitChanged() end
function S:Reset() self._snapshot={Rows={},Visible=false}; self:_emitChanged() end
local d=nil; function S.GetDefault() if not d then d=S.new() end return d end
return S
