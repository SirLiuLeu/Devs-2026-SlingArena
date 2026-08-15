--!strict
local S={}; S.__index=S
local function dc(v:any):any if type(v)~="table" then return v end local c={} for k,x in pairs(v) do c[dc(k)]=dc(x) end return c end
function S.new() local self=setmetatable({},S); self._changed=Instance.new("BindableEvent"); self._snapshot={Rows={},Visible=false}; return self end
function S:Destroy() self._changed:Destroy() end
function S:GetSnapshot() return dc(self._snapshot) end
function S:BindChanged(cb) return self._changed.Event:Connect(cb) end
function S:_emitChanged() self._changed:Fire(self:GetSnapshot()) end
function S:SetFromState(payload:any) local rows=if type(payload)=="table" and type(payload.Rows)=="table" then payload.Rows else {}; self._snapshot={Rows=dc(rows),Visible=true}; self:_emitChanged() end
function S:Reset() self._snapshot={Rows={},Visible=false}; self:_emitChanged() end
local d=nil; function S.GetDefault() if not d then d=S.new() end return d end
return S
