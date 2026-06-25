local TweenService = game:GetService("TweenService")

-- 1. Tham chiếu đến các thành phần UI
local toggleFrame = script.Parent
local background = toggleFrame:WaitForChild("Background")
local gradient = background:WaitForChild("Gradient")
local options = toggleFrame:WaitForChild("Options")

local btnOn = options:WaitForChild("On"):WaitForChild("Click")
local btnOff = options:WaitForChild("Off"):WaitForChild("Click")

-- 2. Cấu hình màu sắc Gradient cho từng trạng thái
local colors = {
	["Off"] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 75, 78)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(178, 54, 56))
	}),
	["On"] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(79, 255, 144)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 145, 82))
	})
}

-- 3. Cấu hình hiệu ứng chuyển động (TweenInfo)
-- Bạn có thể chỉnh sửa 0.3 (thời gian) và kiểu chuyển động (Back/Quad/Sine...)
local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local currentState = nil

-- Hàm xử lý logic khi chuyển đổi trạng thái
local function selectOption(optionName)
	if currentState == optionName then return end
	currentState = optionName

	local targetOption = options:FindFirstChild(optionName)
	if not targetOption then return end

	-- Tạo hiệu ứng di chuyển Background đến nút được chọn
	local moveTween = TweenService:Create(background, tweenInfo, {
		Position = targetOption.Position,
		AnchorPoint = targetOption.AnchorPoint
	})
	moveTween:Play()

	-- Cập nhật màu sắc của Gradient (TweenService không hỗ trợ tween ColorSequence nên ta đổi trực tiếp)
	gradient.Color = colors[optionName]

	-- ==========================================
	-- Thực hiện logic game của bạn ở bên dưới đây:
	-- ==========================================
	print("HumanLauncherToggle hiện đang:", currentState)

	if currentState == "On" then
		-- Logic khi BẬT
	else
		-- Logic khi TẮT
	end
end

-- 4. Lắng nghe sự kiện click từ người chơi
btnOn.Activated:Connect(function()
	selectOption("On")
end)

btnOff.Activated:Connect(function()
	selectOption("Off")
end)

-- 5. Khởi tạo trạng thái mặc định ban đầu
selectOption("Off") -- Đổi thành "On" nếu bạn muốn Bật làm mặc định